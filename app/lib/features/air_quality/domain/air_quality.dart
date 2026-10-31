import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Jalur AQI AS (Open-Meteo). Bukan IPU rasmi Jabatan Alam Sekitar.
enum AirBand { good, moderate, sensitive, unhealthy, veryUnhealthy, hazardous }

AirBand airBandFor(int aqi) {
  if (aqi <= 50) return AirBand.good;
  if (aqi <= 100) return AirBand.moderate;
  if (aqi <= 150) return AirBand.sensitive;
  if (aqi <= 200) return AirBand.unhealthy;
  if (aqi <= 300) return AirBand.veryUnhealthy;
  return AirBand.hazardous;
}

@immutable
class AirReading {
  const AirReading({
    required this.usAqi,
    required this.point,
    required this.fetchedAt,
    this.placeLabel,
    this.here = false,
    this.pm25,
    this.pm10,
    this.no2,
    this.ozone,
    this.fromCache = false,
  });

  final int usAqi;
  final GeoPoint point;
  final DateTime fetchedAt;
  final String? placeLabel;

  /// True jika titik ialah GPS pengguna, bukan carian.
  final bool here;
  final double? pm25;
  final double? pm10;
  final double? no2;
  final double? ozone;
  final bool fromCache;

  AirBand get band => airBandFor(usAqi);

  /// 0–1 untuk lengkok tolok (AQI 300+ penuh).
  double get gauge => (usAqi / 300).clamp(0.0, 1.0);
}

sealed class AirUiState {
  const AirUiState();
}

class AirUiIdle extends AirUiState {
  const AirUiIdle();
}

class AirUiLoading extends AirUiState {
  const AirUiLoading();
}

class AirUiUnavailable extends AirUiState {
  const AirUiUnavailable();
}

class AirUiReady extends AirUiState {
  const AirUiReady(this.reading);
  final AirReading reading;
}
