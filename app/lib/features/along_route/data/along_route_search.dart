import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../../search/domain/place.dart';
import '../domain/along_route_category.dart';
import '../domain/along_route_poi.dart';
import '../domain/along_route_projector.dart';

/// Carian POI dalam koridor sepanjang polyline laluan.
class AlongRouteSearch {
  AlongRouteSearch(this._dio, this._mirrors);

  final Dio _dio;
  final List<String> _mirrors;

  Future<List<AlongRoutePoi>> search({
    required List<GeoPoint> routePoints,
    required AlongRouteCategory category,
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    if (routePoints.length < 2 || _mirrors.isEmpty) return const [];
    final samples = samplePolyline(routePoints, everyM: category.sampleEveryM);
    // Had sampel supaya query Overpass tidak meletup (lebih padat = kurang POI terlepas).
    final capped = samples.length <= 60
        ? samples
        : [
            for (var i = 0; i < 60; i++)
              samples[(i * (samples.length - 1) / 59).round()],
          ];
    final query = category.overpassQuery(capped.map((p) => (p.lat, p.lng)));

    Object? lastError;
    for (final url in _mirrors) {
      if (cancel?.isCancelled ?? false) {
        throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.cancel,
        );
      }
      try {
        final res = await _dio.post<String>(
          url,
          data: query,
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
        return _parseAndProject(
          body,
          routePoints: routePoints,
          category: category,
          fallbackName: fallbackName,
        );
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      throw GeocodeFailure(
        GeocodeFailureKind.unavailable,
        lastError.toString(),
      );
    }
    return const [];
  }

  List<AlongRoutePoi> _parseAndProject(
    String? body, {
    required List<GeoPoint> routePoints,
    required AlongRouteCategory category,
    required String fallbackName,
  }) {
    if (body == null || body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final elements = decoded['elements'];
    if (elements is! List) return const [];

    final raw = <AlongRoutePoi>[];
    for (final e in elements) {
      if (e is! Map<String, dynamic>) continue;
      final tags = e['tags'];
      if (tags is! Map<String, dynamic>) continue;
      final lat = _num(e['lat']) ?? _num((e['center'] as Map?)?['lat']);
      final lng = _num(e['lon']) ?? _num((e['center'] as Map?)?['lon']);
      if (lat == null || lng == null) continue;
      String? t(String key) {
        final v = tags[key];
        return v is String && v.trim().isNotEmpty ? v.trim() : null;
      }

      final name =
          t('name') ??
          t('name:en') ??
          t('brand') ??
          t('operator') ??
          fallbackName;
      final point = GeoPoint(lat, lng);
      final proj = projectOntoPolyline(routePoints, point);
      if (proj == null) continue;
      if (proj.crossTrackM > category.corridorM) continue;
      final type = e['type'];
      final id = '${type ?? 'n'}:${e['id']}';
      raw.add(
        AlongRoutePoi(
          id: id,
          category: category,
          name: name,
          point: point,
          alongM: proj.alongM,
          crossTrackM: proj.crossTrackM,
          subtitle: t('brand') ?? t('operator') ?? '',
        ),
      );
    }

    final deduped = dedupeByProximity(
      items: raw,
      pointOf: (p) => p.point,
      crossTrackOf: (p) => p.crossTrackM,
    );
    deduped.sort((a, b) => a.alongM.compareTo(b.alongM));
    return deduped;
  }
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

final alongRouteSearchProvider = Provider<AlongRouteSearch>((ref) {
  return AlongRouteSearch(ref.watch(dioProvider), AppConfig.overpassUrls);
});
