import 'dart:convert';

import '../../../core/utils/geo.dart';
import '../domain/route_option.dart';
import '../domain/routing_failure.dart';

/// Bilangan laluan alternatif tambahan yang diminta bersama laluan utama (Bahagian 8.2: 2-3 laluan).
const routeAlternatives = 2;

/// Kod ralat Valhalla yang bermaksud "tiada laluan boleh dikira untuk input ini" (bukan kegagalan sistem).
///
/// 154 (jarak melebihi had), 170 (wilayah tidak bersambung) dan 171 (tiada jalan berhampiran) disahkan
/// terhadap Valhalla 3.5.1 tempatan. 442 (tiada laluan) disahkan terhadap server awam FOSSGIS, yang
/// memulangkannya untuk destinasi di laut.
const _noRouteCodes = {154, 170, 171, 442};

/// Membina badan permintaan Valhalla `/route`. Sama untuk server awam dan enjin dalam peranti.
Map<String, Object?> buildRouteRequest(RouteQuery query) {
  return {
    'locations': [
      {
        'lat': query.origin.lat,
        'lon': query.origin.lng,
        // Heading hanya jika diketahui; membolehkan re-route Fasa 1 mengelak pusingan-U mustahil.
        'heading': ?query.headingDegrees,
      },
      {'lat': query.destination.lat, 'lon': query.destination.lng},
    ],
    'costing': 'auto',
    // use_tolls = 0 ialah keutamaan lembut untuk mengelak tol, bukan larangan mutlak.
    if (query.avoidTolls)
      'costing_options': {
        'auto': {'use_tolls': 0},
      },
    'alternates': routeAlternatives,
    // Teks arahan Valhalla tidak digunakan; ayat BM/EN dijana dalam app. `directions_type` mesti di
    // peringkat atas (di dalam directions_options ia diabaikan; disahkan terhadap Valhalla 3.5.1).
    'directions_type': 'maneuvers',
    'directions_options': {'units': 'kilometers', 'language': 'en-US'},
  };
}

/// Menghurai badan respons Valhalla `/route` yang berjaya.
///
/// Melempar [RoutingFailure] jika badan ialah ralat Valhalla atau bentuknya tidak dijangka.
List<RouteOption> parseRouteResponse(
  Object? body, {
  required RouteSource source,
}) {
  final Object? decoded;
  try {
    decoded = body is String ? jsonDecode(body) : body;
  } on FormatException catch (e) {
    throw RoutingFailure(
      RoutingFailureKind.generic,
      'respons bukan JSON: ${e.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const RoutingFailure(
      RoutingFailureKind.generic,
      'respons bukan objek JSON',
    );
  }

  final errorCode = decoded['error_code'];
  if (errorCode is int) {
    throw failureForValhallaError(errorCode, decoded['error']?.toString());
  }

  try {
    final trips = <Map<String, dynamic>>[
      decoded['trip'] as Map<String, dynamic>,
      for (final alt in (decoded['alternates'] as List<dynamic>? ?? const []))
        (alt as Map<String, dynamic>)['trip'] as Map<String, dynamic>,
    ];
    return [for (final trip in trips) _parseTrip(trip, source)];
  } on RoutingFailure {
    rethrow;
  } on Object catch (e) {
    // TypeError / FormatException / medan hilang: respons rosak daripada hulu, bukan salah pengguna.
    throw RoutingFailure(
      RoutingFailureKind.generic,
      'respons tidak dijangka: $e',
    );
  }
}

RouteOption _parseTrip(Map<String, dynamic> trip, RouteSource source) {
  final legs = trip['legs'] as List<dynamic>;
  // Kita hanya hantar dua lokasi (asal, destinasi), jadi satu leg.
  if (legs.length != 1) {
    throw RoutingFailure(
      RoutingFailureKind.generic,
      'dijangka 1 leg, dapat ${legs.length}',
    );
  }
  final leg = legs.single as Map<String, dynamic>;
  final summary = trip['summary'] as Map<String, dynamic>;
  final legSummary = leg['summary'] as Map<String, dynamic>?;

  return RouteOption(
    distanceM: _kmToMeters(summary['length'] as num),
    durationS: (summary['time'] as num).round(),
    hasTolls: summary['has_toll'] == true || legSummary?['has_toll'] == true,
    points: decodePolyline(leg['shape'] as String),
    source: source,
    maneuvers: [
      for (final m in (leg['maneuvers'] as List<dynamic>))
        Maneuver(
          type: (m as Map<String, dynamic>)['type'] as int,
          streetNames: [
            for (final n in (m['street_names'] as List<dynamic>? ?? const []))
              n as String,
          ],
          lengthM: _kmToMeters(m['length'] as num),
          timeS: (m['time'] as num).round(),
          beginShapeIndex: m['begin_shape_index'] as int,
          roundaboutExitCount: m['roundabout_exit_count'] as int?,
        ),
    ],
  );
}

int _kmToMeters(num km) => (km * 1000).round();

/// Memetakan kod ralat Valhalla kepada kegagalan yang difahami UI.
RoutingFailure failureForValhallaError(int code, [String? message]) {
  final kind = _noRouteCodes.contains(code)
      ? RoutingFailureKind.noRoute
      : RoutingFailureKind.invalidRequest;
  return RoutingFailure(kind, 'valhalla $code: ${message ?? ''}');
}

final _errorCodeInText = RegExp(r'"error_code"\s*:\s*(\d+)');

/// Mengeluarkan kod ralat Valhalla daripada teks (mesej pengecualian enjin dalam peranti membawa JSON
/// ralat Valhalla). Memulangkan null jika tiada.
int? valhallaErrorCodeFromText(String text) {
  final match = _errorCodeInText.firstMatch(text);
  return match == null ? null : int.parse(match.group(1)!);
}
