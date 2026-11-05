import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../domain/satellite_coverage.dart';

/// Memeriksa sama ada imej satelit z19 wujud di sekitar satu titik, dengan cache.
///
/// Satu permintaan JSON kecil (`tilemap`) bagi setiap sel ~300 m yang belum diketahui. Kegagalan
/// rangkaian TIDAK disimpan dalam cache: ia mengembalikan null dan dicuba lagi kemudian; pemanggil
/// mengekalkan keadaan terakhir (lalai z18, yang sentiasa selamat).
class SatelliteCoverageService {
  SatelliteCoverageService({
    required this.tilesUrl,
    Dio? dio,
    this.timeout = const Duration(seconds: 6),
    this.maxEntries = 96,
  }) : _dio = dio ?? Dio();

  final String tilesUrl;
  final Duration timeout;
  final int maxEntries;
  final Dio _dio;

  /// Susunan sisipan: entri tertua dibuang dahulu apabila penuh.
  final Map<String, bool> _cache = {};
  final Map<String, Future<bool?>> _inFlight = {};

  /// Ada z19 di [p]? null jika tidak dapat dipastikan (tiada rangkaian, jawapan tidak sah, atau URL
  /// bukan Esri); pemanggil menganggapnya "tidak" tetapi mencuba lagi kemudian.
  Future<bool?> hiAvailableAt(GeoPoint p) {
    final key = SatelliteCoverage.cellKey(p);
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    // Badan blok (bukan `=> remove`): `remove` mengembalikan Future itu sendiri, dan `whenComplete`
    // akan menunggunya selama-lamanya.
    return _inFlight[key] ??= _fetch(key, p).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Keputusan yang sudah diketahui untuk [p] tanpa rangkaian, atau null.
  bool? cachedAt(GeoPoint p) => _cache[SatelliteCoverage.cellKey(p)];

  Future<bool?> _fetch(String key, GeoPoint p) async {
    final uri = SatelliteCoverage.tilemapUri(tilesUrl, p);
    if (uri == null) return null;
    try {
      final res = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      final body = res.data;
      if (body == null) return null;
      final fraction = SatelliteCoverage.availableFraction(body);
      if (fraction == null) return null;
      final ok = SatelliteCoverage.hiAvailable(fraction);
      if (_cache.length >= maxEntries) _cache.remove(_cache.keys.first);
      _cache[key] = ok;
      return ok;
    } on DioException catch (e) {
      logDiag('Semakan liputan satelit gagal: ${e.type.name}');
      return null;
    }
  }

  void dispose() => _dio.close();
}
