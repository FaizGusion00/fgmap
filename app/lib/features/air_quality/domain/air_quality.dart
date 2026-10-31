import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Jalur IPU rasmi JAS (APIMS).
/// Baik 0–50, Sederhana 51–100, Tidak sihat 101–200, Sangat tidak sihat 201–300, Berbahaya >300.
enum AirBand { good, moderate, unhealthy, veryUnhealthy, hazardous }

/// Ambang jerebu / udara buruk untuk amaran sepanjang laluan.
const ipuAlertThreshold = 101;

/// Simbol pencemar dominan pada jadual APIMS.
/// `**` PM2.5, `*` PM10, `a` SO₂, `b` NO₂, `c` O₃, `d` CO, `&` lebih daripada satu.
enum DominantPollutant { pm25, pm10, so2, no2, o3, co, several }

DominantPollutant? pollutantFromSymbol(String? raw) {
  switch (raw?.trim()) {
    case '**':
      return DominantPollutant.pm25;
    case '*':
      return DominantPollutant.pm10;
    case 'a':
    case 'A':
      return DominantPollutant.so2;
    case 'b':
    case 'B':
      return DominantPollutant.no2;
    case 'c':
    case 'C':
      return DominantPollutant.o3;
    case 'd':
    case 'D':
      return DominantPollutant.co;
    case '&':
      return DominantPollutant.several;
    default:
      return null;
  }
}

/// Had bawah dan atas jalur (atas null = tiada siling, Berbahaya).
(int min, int? max) airBandRange(AirBand band) => switch (band) {
  AirBand.good => (0, 50),
  AirBand.moderate => (51, 100),
  AirBand.unhealthy => (101, 200),
  AirBand.veryUnhealthy => (201, 300),
  AirBand.hazardous => (301, null),
};

AirBand airBandFor(int ipu) {
  if (ipu <= 50) return AirBand.good;
  if (ipu <= 100) return AirBand.moderate;
  if (ipu <= 200) return AirBand.unhealthy;
  if (ipu <= 300) return AirBand.veryUnhealthy;
  return AirBand.hazardous;
}

@immutable
class AirStation {
  const AirStation({
    required this.id,
    required this.name,
    required this.point,
    required this.ipu,
    required this.observedAt,
    this.pollutant,
  });

  final String id;
  final String name;
  final GeoPoint point;
  final int ipu;
  final DateTime observedAt;
  final DominantPollutant? pollutant;

  AirBand get band => airBandFor(ipu);
}

@immutable
class AirReading {
  const AirReading({
    required this.ipu,
    required this.point,
    required this.fetchedAt,
    required this.stationName,
    required this.stationDistanceM,
    this.placeLabel,
    this.here = false,
    this.fromCache = false,
    this.observedAt,
    this.pollutant,
  });

  final int ipu;
  final GeoPoint point;
  final DateTime fetchedAt;
  final String stationName;
  final double stationDistanceM;
  final String? placeLabel;

  /// True jika titik carian ialah GPS pengguna.
  final bool here;
  final bool fromCache;
  final DateTime? observedAt;
  final DominantPollutant? pollutant;

  AirBand get band => airBandFor(ipu);

  /// 0–1 untuk lengkok tolok (IPU 300+ penuh).
  double get gauge => (ipu / 300).clamp(0.0, 1.0);

  /// Alias untuk kod AA/lama yang menyebut AQI.
  int get usAqi => ipu;
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
  const AirUiReady(this.reading, {this.routeAlert});
  final AirReading reading;

  /// Stesen IPU tinggi (≥101) paling hampir kepada koridor laluan, jika ada.
  final AirStation? routeAlert;
}
