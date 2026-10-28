import 'dart:math' as math;

import '../../../core/utils/geo.dart';

/// Pelicin kedudukan bebas (tiada laluan) dengan pemalar masa yang sama seperti [VehicleModel]
/// di luar laluan, supaya kereta 3D tidak melompat antara fix GPS.
class CruiseMotion {
  static const correctionTau = 0.35;
  static const snapDistanceM = 40.0;

  GeoPoint? _anchor;
  double _bearing = 0;
  bool _bearingKnown = false;
  DateTime? _bearingAt;
  double _speed = 0;
  DateTime? _anchorTime;
  GeoPoint? _display;
  DateTime? _lastFrame;

  bool get hasPosition => _anchor != null;

  double get bearing => _bearing;
  double get speedMps => _speed;

  void reset() {
    _anchor = null;
    _display = null;
    _anchorTime = null;
    _lastFrame = null;
    _speed = 0;
    _bearing = 0;
    _bearingKnown = false;
    _bearingAt = null;
  }

  void onFix({
    required GeoPoint point,
    required double? bearing,
    required double speedMps,
    required DateTime time,
  }) {
    _anchor = point;
    _anchorTime = time;
    // Pemacu bingkai memanggil ini setiap bingkai dengan fix yang sama. Arah hanya
    // diterima sekali setiap ukuran GPS, jalan pendek, dan diabaikan bila perlahan.
    if (bearing != null && time != _bearingAt) {
      _bearing = followHeading(
        _bearing,
        bearing,
        speedMps: speedMps,
        known: _bearingKnown,
      );
      _bearingKnown = true;
      _bearingAt = time;
    }
    _speed = speedMps < 0.5 ? 0 : speedMps;
  }

  /// Kedudukan dipaparkan pada [now]. Null sebelum fix pertama.
  ({GeoPoint point, double bearing, double speedMps})? at(DateTime now) {
    final anchor = _anchor;
    final anchorTime = _anchorTime;
    if (anchor == null || anchorTime == null) return null;
    final since = now.difference(anchorTime).inMicroseconds / 1e6;
    final secs = math.min(3.0, math.max(0.0, since));
    final target = _speed > 0
        ? destinationPoint(anchor, _bearing, _speed * secs)
        : anchor;
    final previous = _display;
    final lastFrame = _lastFrame;
    var display = target;
    if (previous != null && lastFrame != null) {
      final dt = (now.difference(lastFrame).inMicroseconds / 1e6).clamp(
        0.0,
        2.0,
      );
      final k = 1 - math.exp(-dt / correctionTau);
      final predicted = _speed > 0
          ? destinationPoint(previous, _bearing, _speed * dt)
          : previous;
      if (distanceMeters(predicted, target) > snapDistanceM) {
        display = target;
      } else {
        display = GeoPoint(
          predicted.lat + (target.lat - predicted.lat) * k,
          predicted.lng + (target.lng - predicted.lng) * k,
        );
      }
    }
    _display = display;
    _lastFrame = now;
    return (point: display, bearing: _bearing, speedMps: _speed);
  }
}
