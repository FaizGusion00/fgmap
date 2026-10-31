import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap_valhalla/fgmap_valhalla.dart'
    show ValhallaEngineException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../../offline_maps/data/offline_engine_host.dart';
import '../../route_preview/domain/route_option.dart';
import '../domain/speed_limits.dart';
import '../../../core/utils/log.dart';

/// Mengekod titik sebagai polyline berketepatan 6 digit (format Valhalla `encoded_polyline`). Songsangan [decodePolyline].
String encodePolyline6(List<GeoPoint> points) {
  final out = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;
  void write(int delta) {
    var v = delta < 0 ? ~(delta << 1) : delta << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  for (final p in points) {
    final lat = (p.lat * 1e6).round();
    final lng = (p.lng * 1e6).round();
    write(lat - prevLat);
    write(lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return out.toString();
}

/// Permintaan Valhalla `trace_attributes` untuk jejak laluan, meminta hanya medan yang diperlukan.
Map<String, Object?> buildTraceAttributesRequest(
  List<GeoPoint> points,
  RouteVehicle vehicle,
) => {
  'encoded_polyline': encodePolyline6(points),
  'costing': vehicle.costing,
  // Laluan sudah dikira atas graf yang sama, jadi map_snap mengikutnya tanpa mencari laluan lain.
  'shape_match': 'map_snap',
  'filters': {
    'attributes': [
      'edge.speed_limit',
      'edge.length',
      'edge.begin_shape_index',
      'edge.end_shape_index',
    ],
    'action': 'include',
  },
};

/// Titik terakhir daripada jejak yang disnap (matched_points atau shape). Null jika tiada.
GeoPoint? parseMatchedEnd(Object? body) {
  final decoded = body is String ? jsonDecode(body) : body;
  if (decoded is! Map) return null;
  final matched = decoded['matched_points'];
  if (matched is List && matched.isNotEmpty) {
    for (var i = matched.length - 1; i >= 0; i--) {
      final row = matched[i];
      if (row is! Map) continue;
      final lat = row['lat'];
      final lon = row['lon'] ?? row['lng'];
      if (lat is num && lon is num) {
        return GeoPoint(lat.toDouble(), lon.toDouble());
      }
    }
  }
  final shape = decoded['shape'];
  if (shape is String && shape.isNotEmpty) {
    final pts = decodePolyline(shape);
    if (pts.isNotEmpty) return pts.last;
  }
  return null;
}

/// Menghurai respons `trace_attributes`. Melempar [FormatException] jika bentuk tidak dijangka.
SpeedLimits parseSpeedLimits(Object? body) {
  final decoded = body is String ? jsonDecode(body) : body;
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('respons bukan objek');
  }
  final edges = decoded['edges'];
  if (edges is! List) throw const FormatException('tiada senarai edges');

  final segments = <SpeedLimitSegment>[];
  for (final e in edges) {
    if (e is! Map<String, dynamic>) continue;
    final begin = e['begin_shape_index'];
    final end = e['end_shape_index'];
    final length = e['length'];
    if (begin is! int || end is! int || length is! num) continue;
    // `speed_limit` ialah int (km/j); "unlimited" (autobahn Jerman) dan nilai lain dianggap tidak diketahui.
    final limit = e['speed_limit'];
    segments.add(
      SpeedLimitSegment(
        beginShapeIndex: begin,
        endShapeIndex: end,
        lengthM: length * 1000.0,
        limitKmh: limit is int && limit > 0 ? limit : null,
      ),
    );
  }
  return SpeedLimits(segments);
}

/// Mendapatkan had laju untuk satu laluan. Had laju ialah maklumat sokongan: kegagalan memulangkan
/// [SpeedLimits.empty], tidak pernah melempar, supaya navigasi tidak terjejas.
class SpeedLimitService {
  SpeedLimitService(this._dio, this._traceUrl, this._host);

  final Dio _dio;
  final String _traceUrl;
  final OfflineEngineHost _host;

  /// Sumber utama mengikut asal laluan (laluan offline -> enjin offline dahulu, supaya tiada internet
  /// tidak perlu menunggu masa tamat); yang lain dicuba jika yang pertama gagal.
  Future<SpeedLimits> forRoute(RouteOption route, RouteVehicle vehicle) async {
    if (route.points.length < 2) return SpeedLimits.empty;
    final request = jsonEncode(
      buildTraceAttributesRequest(route.points, vehicle),
    );

    final order = route.source == RouteSource.offline
        ? [_offline, _online]
        : [_online, _offline];
    for (final source in order) {
      try {
        final limits = parseSpeedLimits(await source(request));
        if (!limits.isEmpty) return limits;
      } on Object catch (e) {
        logDiag('Had laju: sumber gagal ($e)');
      }
    }
    return SpeedLimits.empty;
  }

  /// Had laju di hujung jejak GPS pendek (memandu bebas, tiada laluan). Awam dahulu, kemudian enjin
  /// dalam peranti jika pek dipasang. Null jika jejak terlalu pendek atau semua sumber gagal: pemanggil
  /// tetap menunjukkan kelajuan dan menyembunyikan papan had.
  Future<int?> limitForTrace(
    List<GeoPoint> points,
    RouteVehicle vehicle,
  ) async {
    if (points.length < 2) return null;
    final request = jsonEncode(buildTraceAttributesRequest(points, vehicle));
    for (final source in [_online, _offline]) {
      try {
        final limits = parseSpeedLimits(await source(request));
        if (limits.isEmpty) continue;
        // Tepi terakhir sering tanpa tag OSM. Had yang diketahui paling hampir dengan kereta
        // (dari hujung jejak) ialah papan yang dipaparkan. Tiada langsung: sembunyikan papan.
        for (final segment in limits.segments.reversed) {
          final limit = segment.limitKmh;
          if (limit != null && limit > 0) return limit;
        }
        return null;
      } on Object catch (e) {
        logDiag('Had laju jejak: sumber gagal ($e)');
      }
    }
    return null;
  }

  /// Titik paparan yang disnap ke jalan untuk memandu bebas (bukan laluan navigasi).
  /// Null jika jejak pendek atau semua sumber gagal — pemanggil kekal pada GPS mentah.
  Future<GeoPoint?> snapTraceEnd(
    List<GeoPoint> points,
    RouteVehicle vehicle,
  ) async {
    if (points.length < 2) return null;
    final request = jsonEncode(buildTraceAttributesRequest(points, vehicle));
    for (final source in [_online, _offline]) {
      try {
        final snapped = parseMatchedEnd(await source(request));
        if (snapped != null) return snapped;
      } on Object catch (e) {
        logDiag('Snap jejak: sumber gagal ($e)');
      }
    }
    return null;
  }

  Future<String> _online(String request) async {
    final response = await _dio.post<Object>(
      _traceUrl,
      data: request,
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    return responseText(response.data) ?? '';
  }

  Future<String> _offline(String request) async {
    try {
      return await _host.traceAttributes(request);
    } on OfflineEngineUnavailable {
      throw StateError('pek offline tidak dipasang');
    } on ValhallaEngineException catch (e) {
      throw StateError('enjin offline: ${e.code}');
    }
  }
}

final speedLimitServiceProvider = Provider<SpeedLimitService>(
  (ref) => SpeedLimitService(
    ref.watch(dioProvider),
    AppConfig.traceAttributesUrl,
    ref.watch(offlineEngineHostProvider),
  ),
);
