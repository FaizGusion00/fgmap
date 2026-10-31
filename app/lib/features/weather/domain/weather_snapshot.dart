import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

@immutable
class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.tempC,
    required this.weatherCode,
    required this.precipProb,
  });

  final DateTime time;
  final double tempC;
  final int weatherCode;
  final int precipProb;
}

@immutable
class WeatherPoint {
  const WeatherPoint({
    required this.tempC,
    required this.weatherCode,
    required this.precipProb,
    this.feelsLikeC,
    this.humidityPct,
    this.windKmh,
    this.point,
  });

  final double tempC;
  final int weatherCode;
  final int precipProb;
  final double? feelsLikeC;
  final int? humidityPct;
  final double? windKmh;
  final GeoPoint? point;
}

@immutable
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.destination,
    required this.fetchedAt,
    this.origin,
    this.hours = const [],
    this.rainAlongRoute = false,
    this.severe = false,
    this.fromCache = false,
    this.destinationLabel,
  });

  /// Cuaca di destinasi (titik utama pratonton).
  final WeatherPoint destination;

  /// Cuaca di lokasi GPS semasa (asal), jika diketahui.
  final WeatherPoint? origin;

  final List<WeatherHour> hours;
  final DateTime fetchedAt;
  final bool rainAlongRoute;
  final bool severe;
  final bool fromCache;
  final String? destinationLabel;

  double get tempC => destination.tempC;
  int get weatherCode => destination.weatherCode;
  int get precipProb => destination.precipProb;

  bool get isStale {
    final age = DateTime.now().difference(fetchedAt);
    return age > const Duration(hours: 2);
  }
}

/// Keadaan UI cuaca (loading / ready / empty).
@immutable
sealed class WeatherUiState {
  const WeatherUiState();
}

class WeatherUiIdle extends WeatherUiState {
  const WeatherUiIdle();
}

class WeatherUiLoading extends WeatherUiState {
  const WeatherUiLoading();
}

class WeatherUiReady extends WeatherUiState {
  const WeatherUiReady(this.weather);
  final WeatherSnapshot weather;
}

class WeatherUiUnavailable extends WeatherUiState {
  const WeatherUiUnavailable();
}
