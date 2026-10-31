import 'dart:convert';
import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import '../domain/route_option.dart';
import '../domain/routing_failure.dart';

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
        if (query.headingDegrees != null)
          'heading_tolerance': ?query.headingToleranceDegrees,
      },
      // `through`: laluan melalui titik ini tanpa memecahkan leg (jawapan kekal satu leg).
      for (final v in query.via)
        {'lat': v.lat, 'lon': v.lng, 'type': 'through'},
      {
        'lat': query.destination.lat,
        'lon': query.destination.lng,
        // Bangunan/kawasan: titik tengah mungkin paling dekat dengan jalan yang salah. Dengan `radius`,
        // Valhalla menilai calon jalan dalam jarak ini dan memilih yang berkos paling rendah.
        'radius': ?query.destinationRadiusM?.round(),
      },
    ],
    'costing': query.vehicle.costing,
    // use_tolls / use_highways = 0 ialah keutamaan lembut untuk mengelak, bukan larangan mutlak (disahkan:
    // elak lebuh raya KLCC-KLIA = 74 km/123 min tanpa tol, dan masih mungkin ada segmen lebuh raya).
    // Lalai lebih selamat: kurangkan trek/cut-through; motosikal `use_trails: 0`. Bukan trafik langsung.
    'costing_options': {
      query.vehicle.costing: {
        if (query.avoidTolls) 'use_tolls': 0,
        if (query.avoidHighways)
          'use_highways': 0
        else
          // Keutamaan lembut ke arteri (0.5 = neutral Valhalla).
          'use_highways': 0.65,
        'use_tracks': 0,
        'use_living_streets': 0.15,
        if (query.shortest) 'shortest': true,
        if (query.vehicle == RouteVehicle.motorcycle) 'use_trails': 0,
      },
    },
    // Lencongan paksa: semua jalan yang bersilang dengan bulatan dielakkan. Had pelayan awam ialah
    // jumlah perimeter 10 km, jadi jejari dihadkan oleh pembina (lihat RouteCandidateGenerator).
    if (query.exclusions.isNotEmpty)
      'exclude_polygons': [
        for (final e in query.exclusions) _circlePolygon(e.center, e.radiusM),
      ],
    'alternates': query.alternates,
    // Teks arahan Valhalla tidak digunakan; ayat BM/EN dijana dalam app. `directions_type` mesti di
    // peringkat atas (di dalam directions_options ia diabaikan; disahkan terhadap Valhalla 3.5.1).
    'directions_type': 'maneuvers',
    'directions_options': {'units': 'kilometers', 'language': 'en-US'},
  };
}

/// Poligon 16 sisi (cincin tertutup `[lon, lat]`) menghampiri bulatan.
List<List<double>> _circlePolygon(GeoPoint center, double radiusM) {
  const sides = 16;
  final dLat = radiusM / 111320;
  final dLng = radiusM / (111320 * math.cos(center.lat * math.pi / 180));
  final ring = <List<double>>[
    for (var i = 0; i < sides; i++)
      [
        center.lng + dLng * math.cos(2 * math.pi * i / sides),
        center.lat + dLat * math.sin(2 * math.pi * i / sides),
      ],
  ];
  return [...ring, ring.first];
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
    hasHighway:
        summary['has_highway'] == true || legSummary?['has_highway'] == true,
    hasFerry: summary['has_ferry'] == true || legSummary?['has_ferry'] == true,
    hasTimeRestrictions:
        summary['has_time_restrictions'] == true ||
        legSummary?['has_time_restrictions'] == true,
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
          toll: m['toll'] == true,
          lanes: [
            for (final l in (m['lanes'] as List<dynamic>? ?? const []))
              ?Lane.fromJson(l),
          ],
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
