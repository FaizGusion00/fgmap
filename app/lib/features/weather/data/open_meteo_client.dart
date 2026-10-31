import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/geo.dart';
import '../domain/weather_codes.dart';
import '../domain/weather_snapshot.dart';

/// Open-Meteo — percuma tanpa kunci; soft-fail jika offline.
///
/// Ketepatan: koordinat dibundarkan 3 perpuluhan (~100 m) untuk privasi; ramalan
/// diambil daripada titik GPS sebenar (asal) dan destinasi laluan, bukan pusat peta.
class OpenMeteoClient {
  OpenMeteoClient(this._dio);

  final Dio _dio;
  WeatherSnapshot? _cache;
  GeoPoint? _cachePoint;

  static const baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherSnapshot?> fetch({
    required GeoPoint destination,
    GeoPoint? origin,
    List<GeoPoint> alongSamples = const [],
    String? destinationLabel,
    CancelToken? cancel,
  }) async {
    try {
      final wantOrigin =
          origin != null && distanceMeters(origin, destination) > 800;
      final samples = alongSamples.take(4).toList();

      // Destinasi + asal + sampel koridor serentak (bukan berurutan).
      final destFuture = _forecast(destination, rich: true, cancel: cancel);
      // Asal ialah tambahan: ralatnya ditelan (versi "lembut"). Futures ini bermula serta-merta tetapi
      // hanya ditunggu selepas destinasi; jika destinasi gagal dahulu, ralat asal yang tiada penunggu
      // menjadi pengecualian async tidak ditangkap (tanpa internet, setiap kali laluan dipilih).
      final originFuture = wantOrigin
          ? _softForecast(origin, rich: true, cancel: cancel)
          : null;
      final sampleFutures = [
        for (final p in samples) _softForecast(p, rich: false, cancel: cancel),
      ];

      final destData = await destFuture;
      if (destData == null || destData['current'] is! Map) {
        return _cachedNear(destination);
      }

      WeatherPoint? originPoint;
      if (originFuture != null) {
        final o = await originFuture;
        if (o != null) originPoint = _pointFrom(o, origin!);
      }

      var rainAlong = false;
      var severe = WeatherCodes.isSevere(
        (destData['current'] is Map
                    ? (destData['current'] as Map)['weather_code'] as num?
                    : null)
                ?.toInt() ??
            0,
      );

      final destPrecip = _precipFrom(destData);
      if (destPrecip >= 50) rainAlong = true;

      final sampleResults = await Future.wait(sampleFutures);
      for (final sample in sampleResults) {
        if (sample == null) continue;
        final pc = _precipFrom(sample);
        final wc =
            ((sample['current'] as Map?)?['weather_code'] as num?)?.toInt() ??
            0;
        if (pc >= 55) rainAlong = true;
        if (WeatherCodes.isSevere(wc)) severe = true;
      }

      final destPoint = _pointFrom(destData, destination);
      final hours = _hoursFrom(destData);
      // Guna kebarangkalian sejam akan datang jika "current" tiada medan hujan.
      final precip = destPoint.precipProb > 0
          ? destPoint.precipProb
          : (hours.isNotEmpty ? hours.first.precipProb : 0);

      final snap = WeatherSnapshot(
        destination: WeatherPoint(
          tempC: destPoint.tempC,
          weatherCode: destPoint.weatherCode,
          precipProb: precip,
          feelsLikeC: destPoint.feelsLikeC,
          humidityPct: destPoint.humidityPct,
          windKmh: destPoint.windKmh,
          point: destination,
        ),
        origin: originPoint,
        hours: hours,
        fetchedAt: DateTime.now(),
        rainAlongRoute: rainAlong || precip >= 50,
        severe:
            severe || hours.any((h) => WeatherCodes.isSevere(h.weatherCode)),
        destinationLabel: destinationLabel,
      );
      _cache = snap;
      _cachePoint = destination;
      return snap;
    } catch (_) {
      return _cachedNear(destination);
    }
  }

  Future<Map<String, dynamic>?> _softForecast(
    GeoPoint point, {
    required bool rich,
    CancelToken? cancel,
  }) async {
    try {
      return await _forecast(point, rich: rich, cancel: cancel);
    } catch (_) {
      return null;
    }
  }

  WeatherSnapshot? _cachedNear(GeoPoint destination) {
    if (_cache != null &&
        _cachePoint != null &&
        distanceMeters(_cachePoint!, destination) < 50000) {
      return WeatherSnapshot(
        destination: _cache!.destination,
        origin: _cache!.origin,
        hours: _cache!.hours,
        fetchedAt: _cache!.fetchedAt,
        rainAlongRoute: _cache!.rainAlongRoute,
        severe: _cache!.severe,
        fromCache: true,
        destinationLabel: _cache!.destinationLabel,
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> _forecast(
    GeoPoint point, {
    required bool rich,
    CancelToken? cancel,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      baseUrl,
      queryParameters: {
        'latitude': point.lat.toStringAsFixed(3),
        'longitude': point.lng.toStringAsFixed(3),
        'current': rich
            ? 'temperature_2m,relative_humidity_2m,apparent_temperature,'
                  'weather_code,wind_speed_10m,precipitation,'
                  'precipitation_probability'
            : 'temperature_2m,weather_code,precipitation,'
                  'precipitation_probability',
        if (rich)
          'hourly':
              'temperature_2m,precipitation_probability,weather_code,precipitation',
        if (rich) 'forecast_days': 1,
        'timezone': 'auto',
      },
      options: Options(
        headers: {'User-Agent': AppConfig.userAgent},
        receiveTimeout: Duration(seconds: rich ? 12 : 8),
      ),
      cancelToken: cancel,
    );
    return res.data;
  }

  WeatherPoint _pointFrom(Map<String, dynamic> data, GeoPoint point) {
    final current = data['current'];
    if (current is! Map) {
      return WeatherPoint(
        tempC: 0,
        weatherCode: 0,
        precipProb: 0,
        point: point,
      );
    }
    final precipMm = (current['precipitation'] as num?)?.toDouble() ?? 0;
    final precipProb = _precipFrom(data);
    return WeatherPoint(
      tempC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      precipProb: precipProb > 0
          ? precipProb
          : (precipMm > 0.2 ? 60 : (precipMm > 0 ? 30 : 0)),
      feelsLikeC: (current['apparent_temperature'] as num?)?.toDouble(),
      humidityPct: (current['relative_humidity_2m'] as num?)?.toInt(),
      windKmh: (current['wind_speed_10m'] as num?)?.toDouble(),
      point: point,
    );
  }

  int _precipFrom(Map<String, dynamic> data) {
    final current = data['current'];
    if (current is Map) {
      final p = (current['precipitation_probability'] as num?)?.toInt();
      if (p != null) return p;
    }
    final hourly = data['hourly'];
    if (hourly is! Map) return 0;
    final probs = hourly['precipitation_probability'];
    if (probs is! List || probs.isEmpty) return 0;
    return (probs.first as num?)?.toInt() ?? 0;
  }

  List<WeatherHour> _hoursFrom(Map<String, dynamic> data) {
    final hourly = data['hourly'];
    if (hourly is! Map) return const [];
    final times = hourly['time'];
    final temps = hourly['temperature_2m'];
    final codes = hourly['weather_code'];
    final probs = hourly['precipitation_probability'];
    if (times is! List || temps is! List || codes is! List) return const [];
    final now = DateTime.now();
    final out = <WeatherHour>[];
    for (var i = 0; i < times.length && out.length < 6; i++) {
      final t = DateTime.tryParse('${times[i]}');
      if (t == null) continue;
      // Ambil jam semasa dan 5 seterusnya (bukan masa lalu).
      if (t.isBefore(now.subtract(const Duration(minutes: 50)))) continue;
      out.add(
        WeatherHour(
          time: t,
          tempC: (temps[i] as num?)?.toDouble() ?? 0,
          weatherCode: (codes[i] as num?)?.toInt() ?? 0,
          precipProb: probs is List && i < probs.length
              ? (probs[i] as num?)?.toInt() ?? 0
              : 0,
        ),
      );
    }
    return out;
  }
}

final openMeteoClientProvider = Provider(
  (ref) => OpenMeteoClient(ref.watch(dioProvider)),
);
