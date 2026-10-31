import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap_valhalla/fgmap_valhalla.dart'
    show ValhallaEngineException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/log.dart';
import '../../offline_maps/data/offline_engine_host.dart';
import '../../speed_limits/data/speed_limit_service.dart' show encodePolyline6;
import '../domain/road_quality.dart';
import '../domain/route_option.dart';

/// Mengira penalti kualiti jalan satu laluan daripada kelas jalan sebenar (Valhalla `trace_attributes`,
/// `edge.road_class`). Tidak pernah melempar: kegagalan, tamat masa atau tiada data memulangkan null
/// dan laluan dinilai seperti sebelumnya (hanya masa, belokan dan kelajuan).
abstract interface class RoadQualityService {
  Future<double?> penaltyFor(RouteOption route);
}

/// Permintaan `trace_attributes` yang hanya meminta kelas jalan, kegunaan dan panjang.
Map<String, Object?> buildRoadClassRequest(
  RouteOption route,
  RouteVehicle vehicle,
) => {
  'encoded_polyline': encodePolyline6(route.points),
  'costing': vehicle.costing,
  // Laluan sudah dikira atas graf yang sama, jadi map_snap mengikutnya tanpa mencari laluan lain.
  'shape_match': 'map_snap',
  'filters': {
    'attributes': ['edge.road_class', 'edge.use', 'edge.length'],
    'action': 'include',
  },
};

/// Jarak (meter) setiap kelas jalan daripada respons `trace_attributes`. Susur dan saluran belok
/// ('ramp', 'turn_channel') dianggap jalan utama: ia dilabel mengikut jalan yang disambungnya.
Map<String, double> parseRoadClassMeters(Object? body) {
  final decoded = body is String ? jsonDecode(body) : body;
  if (decoded is! Map) return const {};
  final edges = decoded['edges'];
  if (edges is! List) return const {};
  final out = <String, double>{};
  for (final e in edges) {
    if (e is! Map) continue;
    final length = e['length'];
    if (length is! num) continue;
    final use = e['use'];
    final cls = (use == 'ramp' || use == 'turn_channel')
        ? 'ramp'
        : (e['road_class'] as String? ?? '');
    if (cls.isEmpty) continue;
    out[cls] = (out[cls] ?? 0) + length * 1000.0;
  }
  return out;
}

class ValhallaRoadQualityService implements RoadQualityService {
  ValhallaRoadQualityService(
    this._dio,
    this._traceUrl,
    this._host, {
    this.timeout = const Duration(seconds: 6),
  });

  final Dio _dio;
  final String _traceUrl;
  final OfflineEngineHost _host;
  final Duration timeout;

  @override
  Future<double?> penaltyFor(RouteOption route) async {
    if (route.points.length < 2) return null;
    final request = jsonEncode(
      buildRoadClassRequest(
        route,
        // Kenderaan sebenar tidak mempengaruhi kelas jalan; auto mencukupi untuk kedua-dua jenis.
        RouteVehicle.car,
      ),
    );
    final order = route.source == RouteSource.offline
        ? [_offline, _online]
        : [_online, _offline];
    for (final source in order) {
      try {
        final classes = parseRoadClassMeters(await source(request));
        if (classes.isNotEmpty) return roadPenaltyFromClasses(classes);
      } on Object catch (e) {
        logDiag('Kualiti jalan: sumber gagal ($e)');
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
        receiveTimeout: timeout,
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

final roadQualityServiceProvider = Provider<RoadQualityService>(
  (ref) => ValhallaRoadQualityService(
    ref.watch(dioProvider),
    AppConfig.traceAttributesUrl,
    ref.watch(offlineEngineHostProvider),
  ),
);
