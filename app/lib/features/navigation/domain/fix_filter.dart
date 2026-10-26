import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';

/// Fix GPS yang telah ditapis dan dilicinkan, sedia untuk dipadankan dengan laluan.
@immutable
class FilteredFix {
  const FilteredFix({
    required this.point,
    required this.time,
    required this.accuracyM,
    required this.speedMps,
    required this.headingDegrees,
    this.degraded = false,
  });

  final GeoPoint point;
  final DateTime time;
  final double accuracyM;
  final double speedMps;

  /// Arah gerakan; null jika hampir pegun (arah tidak bermakna).
  final double? headingDegrees;

  /// Benar jika fix diterima walaupun ketepatan rendah kerana tiada yang lebih baik sejak lama.
  final bool degraded;
}

/// Menapis dan melicinkan aliran fix GPS (Bahagian 8.3 dan 8.5A pelan):
///  - buang fix ketepatan rendah, fix berulang/tidak tertib, dan lompatan mustahil;
///  - penapis Kalman ringkas pada satah tempatan (meter) dengan ramalan menggunakan kelajuan;
///  - kelajuan dan arah gerakan diperoleh daripada peranti atau perpindahan.
class FixFilter {
  FixFilter({
    this.maxAccuracyM = 60,
    this.maxSpeedMps = 85,
    this.maxStaleness = const Duration(seconds: 8),
  });

  /// Fix yang lebih tidak tepat daripada ini ditolak...
  final double maxAccuracyM;

  /// ...begitu juga lompatan yang membayangkan kelajuan melebihi ini (~300 km/j).
  final double maxSpeedMps;

  /// ...kecuali tiada fix baik diterima selama ini; ketika itu fix lemah lebih baik daripada tiada.
  final Duration maxStaleness;

  GeoPoint? _origin;
  double _x = 0, _y = 0; // meter ke timur / utara dari _origin
  double _variance = 0;
  DateTime? _lastTime;
  GeoPoint? _lastOutput;
  double _derivedSpeed = 0;
  double? _lastHeading;
  int _consecutiveJumps = 0;

  /// Memulangkan fix tertapis, atau null jika [raw] ditolak.
  FilteredFix? accept(LocationFix raw, {required DateTime now}) {
    final time = raw.timestamp ?? now;
    final last = _lastTime;
    if (last != null && !time.isAfter(last)) return null;

    final accuracy = (raw.accuracyMeters ?? 10).clamp(1.0, 500.0);
    var degraded = false;
    if (accuracy > maxAccuracyM) {
      final stale = last == null || time.difference(last) > maxStaleness;
      if (!stale) return null;
      degraded = true;
    }

    final origin = _origin;
    if (origin == null) return _initialise(raw, time, accuracy, degraded);

    final dt = math.max(0.05, time.difference(last!).inMilliseconds / 1000);
    final (mx, my) = _toLocal(raw.point, origin);

    // Lompatan mustahil: tolak, tetapi jika berterusan, lokasi itulah yang benar (cth. selepas
    // terowong atau penerbangan mod pesawat) dan penapis dimulakan semula.
    final jump = math.sqrt(math.pow(mx - _x, 2) + math.pow(my - _y, 2));
    if (jump / dt > maxSpeedMps && jump > 150) {
      _consecutiveJumps++;
      if (_consecutiveJumps < 3) return null;
      return _initialise(raw, time, accuracy, degraded);
    }
    _consecutiveJumps = 0;

    final reportedSpeed = raw.speedMps;
    final speedGuess = reportedSpeed ?? _derivedSpeed;

    // Ramal: gerak ke hadapan mengikut kelajuan dan arah yang diketahui.
    final heading = raw.headingDegrees?.toDouble() ?? _lastHeading;
    var px = _x, py = _y;
    if (heading != null && speedGuess > 1) {
      final rad = heading * math.pi / 180;
      px += math.sin(rad) * speedGuess * dt;
      py += math.cos(rad) * speedGuess * dt;
    }
    // Ketidakpastian membesar dengan masa dan kelajuan: pada kelajuan tinggi, percayai pengukuran.
    final q = math.max(3.0, speedGuess);
    final predictedVariance = _variance + dt * q * q;
    final r = accuracy * accuracy;
    final gain = predictedVariance / (predictedVariance + r);
    _x = px + gain * (mx - px);
    _y = py + gain * (my - py);
    _variance = (1 - gain) * predictedVariance;
    _lastTime = time;

    final point = _fromLocal(_x, _y, origin);
    final moved = _lastOutput == null
        ? 0.0
        : distanceMeters(_lastOutput!, point);
    final measured = moved / dt;
    _derivedSpeed = _derivedSpeed * 0.6 + measured * 0.4;
    final speed = reportedSpeed ?? _derivedSpeed;

    double? outHeading = raw.headingDegrees?.toDouble();
    if (outHeading == null && _lastOutput != null && moved > 4 && speed > 1.5) {
      outHeading = bearingDegrees(_lastOutput!, point);
    }
    if (outHeading != null) _lastHeading = outHeading;
    if (speed <= 1.5 && raw.headingDegrees == null) outHeading = null;
    _lastOutput = point;

    return FilteredFix(
      point: point,
      time: time,
      accuracyM: math.sqrt(_variance),
      speedMps: speed,
      headingDegrees: outHeading,
      degraded: degraded,
    );
  }

  FilteredFix _initialise(
    LocationFix raw,
    DateTime time,
    double accuracy,
    bool degraded,
  ) {
    _origin = raw.point;
    _x = 0;
    _y = 0;
    _variance = accuracy * accuracy;
    _lastTime = time;
    _lastOutput = raw.point;
    _derivedSpeed = raw.speedMps ?? 0;
    _consecutiveJumps = 0;
    final heading = raw.headingDegrees?.toDouble();
    if (heading != null) _lastHeading = heading;
    return FilteredFix(
      point: raw.point,
      time: time,
      accuracyM: accuracy,
      speedMps: raw.speedMps ?? 0,
      headingDegrees: heading,
      degraded: degraded,
    );
  }

  static (double, double) _toLocal(GeoPoint p, GeoPoint origin) {
    const mPerDeg = 111194.9266;
    final x =
        (p.lng - origin.lng) * math.cos(origin.lat * math.pi / 180) * mPerDeg;
    final y = (p.lat - origin.lat) * mPerDeg;
    return (x, y);
  }

  static GeoPoint _fromLocal(double x, double y, GeoPoint origin) {
    const mPerDeg = 111194.9266;
    return GeoPoint(
      origin.lat + y / mPerDeg,
      origin.lng + x / (mPerDeg * math.cos(origin.lat * math.pi / 180)),
    );
  }
}
