import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

enum SpeedCameraSource { jpjAwas, osm }

/// Ketepatan pin: `high` = geokod dipercayai; `approx` = anggaran KM (koridor lebih luas).
enum SpeedCameraConfidence { high, approx }

@immutable
class SpeedCamera {
  const SpeedCamera({
    required this.id,
    required this.name,
    required this.point,
    required this.source,
    this.type = 'speed',
    this.bound,
    this.directionDegrees,
    this.maxSpeedKmh,
    this.confidence = SpeedCameraConfidence.high,
  });

  final String id;
  final String name;
  final GeoPoint point;
  final SpeedCameraSource source;

  /// `speed` atau `red_light`.
  final String type;

  /// `NB`/`SB`/`EB`/`WB` (AwAS atau nama OSM); null = semua arah.
  final String? bound;

  /// Arah perjalanan yang dikuatkuasa (darjah, 0 = utara), daripada `direction` OSM; null = semua arah.
  final double? directionDegrees;

  /// Had laju di kamera (km/j) jika diketahui.
  final int? maxSpeedKmh;
  final SpeedCameraConfidence confidence;
}

@immutable
class CameraAlert {
  const CameraAlert({
    required this.camera,
    required this.alongM,
    required this.distanceAheadM,
  });

  final SpeedCamera camera;
  final double alongM;
  final double distanceAheadM;
}
