import 'dart:async';
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
///
/// Kelajuan: (1) satu pertanyaan polyline, bukan ratusan penyata bulat; (2) cermin Overpass
/// dilumbakan, bukan dicuba berurutan: cermin kedua dimulakan jika yang pertama belum menjawab dalam
/// [hedgeDelay], dan yang pertama berjaya menang. Dahulu satu cermin yang lembap menahan pengguna
/// sehingga tamat masa (25 s) sebelum cermin seterusnya dicuba.
class AlongRouteSearch {
  AlongRouteSearch(
    this._dio,
    this._mirrors, {
    this.hedgeDelay = const Duration(seconds: 3),
  });

  final Dio _dio;
  final List<String> _mirrors;

  /// Berapa lama menunggu satu cermin sebelum memulakan yang seterusnya serentak.
  final Duration hedgeDelay;

  /// Garis yang dihantar kepada Overpass paling banyak ~250 titik dan sekurang-kurangnya 500 m
  /// antara titik; padanan tepat dibuat kemudian pada laluan penuh.
  static const _maxQueryPoints = 250;
  static const _minQuerySpacingM = 500.0;

  Future<List<AlongRoutePoi>> search({
    required List<GeoPoint> routePoints,
    required AlongRouteCategory category,
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    if (routePoints.length < 2 || _mirrors.isEmpty) return const [];
    final along = cumulativeMeters(routePoints);
    final spacing = along.last / _maxQueryPoints < _minQuerySpacingM
        ? _minQuerySpacingM
        : along.last / _maxQueryPoints;
    final line = samplePolyline(routePoints, everyM: spacing);
    final query = category.overpassQuery(line.map((p) => (p.lat, p.lng)));

    final String? body;
    try {
      body = await _raceMirrors(query, cancel);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw GeocodeFailure(GeocodeFailureKind.unavailable, e.toString());
    }
    return _parseAndProject(
      body,
      routePoints: routePoints,
      along: along,
      category: category,
      fallbackName: fallbackName,
    );
  }

  Future<String?> _post(String url, String query, CancelToken token) async {
    final res = await _dio.post<String>(
      url,
      data: query,
      options: Options(
        responseType: ResponseType.plain,
        contentType: 'application/x-www-form-urlencoded',
        headers: {'User-Agent': AppConfig.userAgent},
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
      ),
      cancelToken: token,
    );
    return responseText(res.data);
  }

  /// Mulakan cermin pertama; mulakan yang seterusnya selepas [hedgeDelay] atau serta-merta apabila
  /// yang sebelumnya gagal. Jawapan berjaya pertama menang dan permintaan lain dibatalkan.
  Future<String?> _raceMirrors(String query, CancelToken? outer) {
    final done = Completer<String?>();
    final tokens = <CancelToken>[];
    Timer? hedge;
    var started = 0;
    var failed = 0;
    Object? lastError;

    void finish() {
      hedge?.cancel();
      for (final t in tokens) {
        if (!t.isCancelled) t.cancel();
      }
    }

    late void Function() startNext;

    void armHedge() {
      hedge?.cancel();
      if (started < _mirrors.length) hedge = Timer(hedgeDelay, startNext);
    }

    startNext = () {
      if (done.isCompleted || started >= _mirrors.length) return;
      final url = _mirrors[started++];
      final token = CancelToken();
      tokens.add(token);
      armHedge();
      _post(url, query, token).then(
        (body) {
          if (!done.isCompleted) done.complete(body);
        },
        onError: (Object e) {
          if (done.isCompleted) return;
          lastError = e;
          failed++;
          if (started < _mirrors.length) {
            startNext(); // gagal: cermin seterusnya serta-merta, tanpa menunggu hedge
          } else if (failed >= started) {
            done.completeError(lastError!);
          }
        },
      );
    };

    if (outer != null) {
      unawaited(
        outer.whenCancel.then((e) {
          if (!done.isCompleted) done.completeError(e);
        }),
      );
    }
    startNext();
    return done.future.whenComplete(finish);
  }

  List<AlongRoutePoi> _parseAndProject(
    String? body, {
    required List<GeoPoint> routePoints,
    required List<double> along,
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
      final proj = projectOntoPolyline(routePoints, point, along: along);
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
