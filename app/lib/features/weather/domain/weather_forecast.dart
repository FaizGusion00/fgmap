import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Ramalan penuh satu tempat untuk halaman Cuaca: semasa, 48 jam, 10 hari. Masa dalam waktu tempatan
/// tempat itu (Open-Meteo `timezone=auto`), bukan waktu telefon.
@immutable
class WeatherForecast {
  const WeatherForecast({
    required this.point,
    required this.current,
    required this.hours,
    required this.days,
    required this.fetchedAt,
    this.timezone,
  });

  final GeoPoint point;
  final CurrentWeather current;
  final List<HourForecast> hours;
  final List<DayForecast> days;
  final DateTime fetchedAt;
  final String? timezone;

  /// Ramalan lebih lama daripada [maxAge] dimuat semula (tetapi masih dipaparkan semasa offline).
  bool isStale({Duration maxAge = const Duration(minutes: 30)}) =>
      DateTime.now().difference(fetchedAt) > maxAge;

  DayForecast? get today => days.isEmpty ? null : days.first;

  /// Mana-mana jam dalam 24 jam akan datang dengan ribut/hujan lebat.
  int? get severeSoonCode {
    for (final h in hours.take(24)) {
      if (const {65, 66, 67, 82, 95, 96, 99}.contains(h.weatherCode)) {
        return h.weatherCode;
      }
    }
    return null;
  }

  /// Huraikan respons Open-Meteo. Null jika bahagian penting tiada.
  static WeatherForecast? parse(
    Map<String, dynamic> json,
    GeoPoint point, {
    DateTime? fetchedAt,
  }) {
    final c = json['current'];
    if (c is! Map) return null;
    num? n(Map m, String k) => m[k] is num ? m[k] as num : null;
    final current = CurrentWeather(
      tempC: (n(c, 'temperature_2m') ?? 0).toDouble(),
      feelsLikeC: n(c, 'apparent_temperature')?.toDouble(),
      humidityPct: n(c, 'relative_humidity_2m')?.round(),
      windKmh: n(c, 'wind_speed_10m')?.toDouble(),
      windDirDeg: n(c, 'wind_direction_10m')?.toDouble(),
      pressureHpa: n(c, 'surface_pressure')?.toDouble(),
      uvIndex: n(c, 'uv_index')?.toDouble(),
      visibilityM: n(c, 'visibility')?.toDouble(),
      precipMm: n(c, 'precipitation')?.toDouble(),
      weatherCode: n(c, 'weather_code')?.round() ?? 0,
      isDay: n(c, 'is_day') != 0,
      time: DateTime.tryParse('${c['time']}'),
    );

    final hours = <HourForecast>[];
    final h = json['hourly'];
    if (h is Map && h['time'] is List) {
      final times = h['time'] as List;
      List? col(String k) => h[k] is List ? h[k] as List : null;
      final temp = col('temperature_2m');
      final code = col('weather_code');
      final prob = col('precipitation_probability');
      final day = col('is_day');
      for (var i = 0; i < times.length; i++) {
        final t = DateTime.tryParse('${times[i]}');
        if (t == null) continue;
        hours.add(
          HourForecast(
            time: t,
            tempC: (_at(temp, i) ?? 0).toDouble(),
            weatherCode: _at(code, i)?.round() ?? 0,
            precipProb: _at(prob, i)?.round() ?? 0,
            isDay: _at(day, i) != 0,
          ),
        );
      }
    }

    final days = <DayForecast>[];
    final d = json['daily'];
    if (d is Map && d['time'] is List) {
      final times = d['time'] as List;
      List? col(String k) => d[k] is List ? d[k] as List : null;
      final code = col('weather_code');
      final max = col('temperature_2m_max');
      final min = col('temperature_2m_min');
      final prob = col('precipitation_probability_max');
      final sum = col('precipitation_sum');
      final uv = col('uv_index_max');
      final rise = col('sunrise');
      final set = col('sunset');
      for (var i = 0; i < times.length; i++) {
        final t = DateTime.tryParse('${times[i]}');
        if (t == null) continue;
        days.add(
          DayForecast(
            date: t,
            weatherCode: _at(code, i)?.round() ?? 0,
            maxC: (_at(max, i) ?? 0).toDouble(),
            minC: (_at(min, i) ?? 0).toDouble(),
            precipProb: _at(prob, i)?.round() ?? 0,
            precipMm: _at(sum, i)?.toDouble() ?? 0,
            uvMax: _at(uv, i)?.toDouble(),
            sunrise: rise != null && i < rise.length
                ? DateTime.tryParse('${rise[i]}')
                : null,
            sunset: set != null && i < set.length
                ? DateTime.tryParse('${set[i]}')
                : null,
          ),
        );
      }
    }

    return WeatherForecast(
      point: point,
      current: current,
      hours: hours,
      days: days,
      fetchedAt: fetchedAt ?? DateTime.now(),
      timezone: json['timezone']?.toString(),
    );
  }

  static num? _at(List? list, int i) =>
      list != null && i < list.length && list[i] is num ? list[i] as num : null;

  /// Bentuk storan (sama dengan respons Open-Meteo + metadata) supaya [parse] digunakan semula.
  static Map<String, Object?> rawForStorage(
    Map<String, dynamic> response,
    GeoPoint point,
    DateTime fetchedAt,
  ) => {
    ...response,
    '_lat': point.lat,
    '_lng': point.lng,
    '_at': fetchedAt.toIso8601String(),
  };

  static WeatherForecast? fromStorage(Map<String, dynamic> raw) {
    final lat = raw['_lat'];
    final lng = raw['_lng'];
    final at = DateTime.tryParse('${raw['_at']}');
    if (lat is! num || lng is! num || at == null) return null;
    return parse(raw, GeoPoint(lat.toDouble(), lng.toDouble()), fetchedAt: at);
  }
}

@immutable
class CurrentWeather {
  const CurrentWeather({
    required this.tempC,
    required this.weatherCode,
    required this.isDay,
    this.feelsLikeC,
    this.humidityPct,
    this.windKmh,
    this.windDirDeg,
    this.pressureHpa,
    this.uvIndex,
    this.visibilityM,
    this.precipMm,
    this.time,
  });

  final double tempC;
  final int weatherCode;
  final bool isDay;
  final double? feelsLikeC;
  final int? humidityPct;
  final double? windKmh;

  /// Arah angin DATANG (meteorologi), darjah dari utara.
  final double? windDirDeg;
  final double? pressureHpa;
  final double? uvIndex;
  final double? visibilityM;
  final double? precipMm;

  /// Masa tempatan tempat itu.
  final DateTime? time;
}

@immutable
class HourForecast {
  const HourForecast({
    required this.time,
    required this.tempC,
    required this.weatherCode,
    required this.precipProb,
    required this.isDay,
  });

  final DateTime time;
  final double tempC;
  final int weatherCode;
  final int precipProb;
  final bool isDay;
}

@immutable
class DayForecast {
  const DayForecast({
    required this.date,
    required this.weatherCode,
    required this.maxC,
    required this.minC,
    required this.precipProb,
    required this.precipMm,
    this.uvMax,
    this.sunrise,
    this.sunset,
  });

  final DateTime date;
  final int weatherCode;
  final double maxC;
  final double minC;
  final int precipProb;
  final double precipMm;
  final double? uvMax;
  final DateTime? sunrise;
  final DateTime? sunset;
}

/// Tempat dalam halaman Cuaca: lokasi semasa (GPS) atau tempat yang disimpan pengguna.
@immutable
class WeatherPlace {
  const WeatherPlace({
    required this.id,
    required this.name,
    required this.point,
    this.subtitle,
    this.isCurrent = false,
  });

  final String id;
  final String name;
  final String? subtitle;
  final GeoPoint point;
  final bool isCurrent;

  WeatherPlace copyWith({String? name, String? subtitle, GeoPoint? point}) =>
      WeatherPlace(
        id: id,
        name: name ?? this.name,
        subtitle: subtitle ?? this.subtitle,
        point: point ?? this.point,
        isCurrent: isCurrent,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (subtitle != null) 'subtitle': subtitle,
    'lat': point.lat,
    'lng': point.lng,
  };

  static WeatherPlace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lng = raw['lng'];
    final name = raw['name']?.toString();
    if (lat is! num || lng is! num || name == null || name.isEmpty) {
      return null;
    }
    return WeatherPlace(
      id:
          raw['id']?.toString() ??
          '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}',
      name: name,
      subtitle: raw['subtitle']?.toString(),
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
    );
  }
}
