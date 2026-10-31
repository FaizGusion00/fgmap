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
    this.confidence = SpeedCameraConfidence.high,
  });

  final String id;
  final String name;
  final GeoPoint point;
  final SpeedCameraSource source;
  final String type;
  final String? bound;
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
