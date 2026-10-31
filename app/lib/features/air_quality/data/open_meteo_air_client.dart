import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/geo.dart';
import '../domain/air_quality.dart';

/// Open-Meteo Air Quality — percuma, tanpa kunci.
///
/// Koordinat dibundarkan 3 perpuluhan (~100 m). Nilai ialah US AQI, bukan IPU rasmi JAS.
class OpenMeteoAirClient {
  OpenMeteoAirClient(this._dio);

  final Dio _dio;
  AirReading? _cache;

  static const baseUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';

  Future<AirReading?> fetch({
    required GeoPoint point,
    String? placeLabel,
    bool here = false,
    CancelToken? cancel,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        baseUrl,
        queryParameters: {
          'latitude': point.lat.toStringAsFixed(3),
          'longitude': point.lng.toStringAsFixed(3),
          'current': 'us_aqi,pm2_5,pm10,nitrogen_dioxide,ozone',
          'timezone': 'auto',
        },
        options: Options(
          headers: {'User-Agent': AppConfig.userAgent},
          receiveTimeout: const Duration(seconds: 12),
        ),
        cancelToken: cancel,
      );
      final current = res.data?['current'];
      if (current is! Map) return _cachedNear(point, placeLabel, here);
      final aqi = (current['us_aqi'] as num?)?.round();
      if (aqi == null) return _cachedNear(point, placeLabel, here);
      final reading = AirReading(
        usAqi: aqi,
        point: point,
        fetchedAt: DateTime.now(),
        placeLabel: placeLabel,
        here: here,
        pm25: (current['pm2_5'] as num?)?.toDouble(),
        pm10: (current['pm10'] as num?)?.toDouble(),
        no2: (current['nitrogen_dioxide'] as num?)?.toDouble(),
        ozone: (current['ozone'] as num?)?.toDouble(),
      );
      _cache = reading;
      return reading;
    } catch (_) {
      return _cachedNear(point, placeLabel, here);
    }
  }

  AirReading? _cachedNear(GeoPoint point, String? label, bool here) {
    final cached = _cache;
    if (cached == null) return null;
    if (distanceMeters(cached.point, point) > 25000) return null;
    return AirReading(
      usAqi: cached.usAqi,
      point: point,
      fetchedAt: cached.fetchedAt,
      placeLabel: label ?? cached.placeLabel,
      here: here,
      pm25: cached.pm25,
      pm10: cached.pm10,
      no2: cached.no2,
      ozone: cached.ozone,
      fromCache: true,
    );
  }
}

final openMeteoAirClientProvider = Provider(
  (ref) => OpenMeteoAirClient(ref.watch(dioProvider)),
);
