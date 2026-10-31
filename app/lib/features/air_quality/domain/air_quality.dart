import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Jalur IPU rasmi JAS (APIMS).
/// Baik 0–50, Sederhana 51–100, Tidak sihat 101–200, Sangat tidak sihat 201–300, Berbahaya >300.
enum AirBand { good, moderate, unhealthy, veryUnhealthy, hazardous }

/// Ambang jerebu / udara buruk untuk amaran sepanjang laluan.
const ipuAlertThreshold = 101;

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
  });

  final String id;
  final String name;
  final GeoPoint point;
  final int ipu;
  final DateTime observedAt;

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
