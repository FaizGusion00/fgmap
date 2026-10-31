import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../../along_route/domain/along_route_projector.dart';
import '../domain/speed_camera.dart';

/// Kamera `highway=speed_camera` komuniti OSM (pilihan; mungkin tak lengkap).
class OsmCameraSearch {
  OsmCameraSearch(this._dio, this._mirrors);

  final Dio _dio;
  final List<String> _mirrors;

  Future<List<SpeedCamera>> searchAlong(
    List<GeoPoint> routePoints, {
    CancelToken? cancel,
  }) async {
    if (routePoints.length < 2 || _mirrors.isEmpty) return const [];
    // around 900 m + sampel ~1.2 km supaya koridor hampir berterusan.
    final samples = samplePolyline(routePoints, everyM: 1200);
    final capped = samples.length <= 60
        ? samples
        : [
            for (var i = 0; i < 60; i++)
              samples[(i * (samples.length - 1) / 59).round()],
          ];
    final buf = StringBuffer('[out:json][timeout:25];(');
    for (final p in capped) {
      buf.write(
        'node["highway"="speed_camera"](around:900,${p.lat},${p.lng});',
      );
    }
    buf.write(');out body;');

    for (final url in _mirrors) {
      if (cancel?.isCancelled ?? false) break;
      try {
        final res = await _dio.post<String>(
          url,
          data: buf.toString(),
          options: Options(
            responseType: ResponseType.plain,
            contentType: 'application/x-www-form-urlencoded',
            headers: {'User-Agent': AppConfig.userAgent},
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 25),
          ),
          cancelToken: cancel,
        );
        final body = responseText(res);
        if (body == null || body.isEmpty) continue;
        return _parse(body);
      } catch (_) {}
    }
    return const [];
  }

  List<SpeedCamera> _parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final elements = decoded['elements'];
    if (elements is! List) return const [];
    final out = <SpeedCamera>[];
    for (final e in elements) {
      if (e is! Map) continue;
      final lat = (e['lat'] as num?)?.toDouble();
      final lng = (e['lon'] as num?)?.toDouble();
      final id = e['id'];
      if (lat == null || lng == null || id == null) continue;
      final tags = e['tags'];
      final name = tags is Map
          ? (tags['name'] as String?) ?? 'Kamera OSM'
          : 'Kamera OSM';
      out.add(
        SpeedCamera(
          id: 'osm-$id',
          name: name,
          point: GeoPoint(lat, lng),
          source: SpeedCameraSource.osm,
        ),
      );
    }
    return out;
  }
}

final osmCameraSearchProvider = Provider(
  (ref) => OsmCameraSearch(ref.watch(dioProvider), AppConfig.overpassUrls),
);
