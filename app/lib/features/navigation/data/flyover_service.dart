import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../domain/nav_route.dart';

/// Jambatan jalan OSM (jejambat) di sekitar cabang laluan, untuk petunjuk "ikut jalan bawah".
///
/// Satu pertanyaan Overpass bagi setiap laluan (POST, gabungan `around` di titik cabang sahaja, had
/// [maxPoints]). Gagal atau luar talian -> senarai kosong: petunjuk "naik jejambat" daripada laluan sendiri
/// kekal berfungsi; hanya "jalan bawah" yang hilang.
class FlyoverService {
  FlyoverService(this._dio, this._mirrors);

  final Dio _dio;
  final List<String> _mirrors;
  final Map<String, List<List<GeoPoint>>> _cache = {};

  static const maxPoints = 40;
  static const radiusM = 300;

  /// Titik cabang yang patut disemak: cabang/susur/keluar/gabung dan lurus (bukan belok 90 darjah).
  static List<GeoPoint> forkPoints(NavRoute route) {
    final out = <GeoPoint>[];
    for (final m in route.maneuvers) {
      if (out.length >= maxPoints) break;
      switch (m.kind) {
        case ManeuverKind.keepLeft ||
            ManeuverKind.keepRight ||
            ManeuverKind.keepStraight ||
            ManeuverKind.rampStraight ||
            ManeuverKind.rampLeft ||
            ManeuverKind.rampRight ||
            ManeuverKind.exitLeft ||
            ManeuverKind.exitRight ||
            ManeuverKind.slightLeft ||
            ManeuverKind.slightRight ||
            ManeuverKind.straight ||
            ManeuverKind.merge ||
            ManeuverKind.mergeLeft ||
            ManeuverKind.mergeRight:
          out.add(route.pointAt(m.startM));
        default:
          break;
      }
    }
    return out;
  }

  static String queryFor(List<GeoPoint> points) {
    String c(double v) => v.toStringAsFixed(5);
    final parts = [
      for (final p in points)
        'way(around:$radiusM,${c(p.lat)},${c(p.lng)})["bridge"]["bridge"!="no"]'
            '["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential)(_link)?\$"];',
    ];
    return '[out:json][timeout:15];(${parts.join()});out geom 400;';
  }

  /// Null = pertanyaan gagal (luar talian / Overpass sibuk); senarai kosong = tiada jambatan.
  Future<List<List<GeoPoint>>?> bridgesFor(NavRoute route) async {
    final points = forkPoints(route);
    // Tiada cermin = carian dimatikan (bukan kegagalan yang patut dicuba semula).
    if (points.isEmpty || _mirrors.isEmpty) return const [];
    final key =
        '${route.option.durationS}:${route.option.distanceM}:${route.points.length}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final query = queryFor(points);
    for (final mirror in _mirrors) {
      try {
        final response = await _dio.post<Object>(
          mirror,
          data: 'data=${Uri.encodeQueryComponent(query)}',
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        return _cache[key] = parseBridgeWays(responseText(response.data));
      } on DioException catch (e) {
        logDiag('Jejambat: ${e.type}');
      } on FormatException catch (e) {
        logDiag('Jejambat: $e');
      }
    }
    return null;
  }
}

/// Geometri jalan daripada respons Overpass `out geom`. Badan rosak -> [FormatException].
List<List<GeoPoint>> parseBridgeWays(String? body) {
  if (body == null || body.isEmpty) throw const FormatException('kosong');
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('bukan objek');
  }
  final elements = decoded['elements'];
  if (elements is! List) return const [];
  final out = <List<GeoPoint>>[];
  for (final e in elements) {
    if (e is! Map<String, dynamic> || e['type'] != 'way') continue;
    final geom = e['geometry'];
    if (geom is! List) continue;
    final line = <GeoPoint>[
      for (final g in geom)
        if (g is Map<String, dynamic> && g['lat'] is num && g['lon'] is num)
          GeoPoint((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
    ];
    if (line.length >= 2) out.add(line);
  }
  return out;
}

final flyoverServiceProvider = Provider<FlyoverService>(
  (ref) => FlyoverService(ref.watch(dioProvider), AppConfig.overpassUrls),
);
