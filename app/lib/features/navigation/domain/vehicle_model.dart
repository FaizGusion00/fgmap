import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'nav_route.dart';

/// Kedudukan dan arah kenderaan untuk dilukis pada satu bingkai.
@immutable
class VehiclePose {
  const VehiclePose({
    required this.point,
    required this.bearing,
    required this.speedMps,
    required this.onRoute,
    required this.alongM,
  });

  final GeoPoint point;
  final double bearing;
  final double speedMps;
  final bool onRoute;

  /// Jarak sepanjang laluan (hanya bermakna jika [onRoute]).
  final double alongM;
}

/// Model gerakan kenderaan antara fix GPS (Bahagian 8.5B dan 14.3 pelan): fix tiba kira-kira sekali
/// seminit-saat, tetapi bingkai dilukis 60 kali sesaat. Kenderaan "dipandu" sepanjang laluan
/// mengikut kelajuan terakhir, dan dibetulkan secara beransur-ansur apabila fix baharu tiba, jadi:
///  - marker tidak melompat mengikut fix;
///  - ia tidak pernah berundur kerana hingar GPS;
///  - ia terus bergerak ketika isyarat hilang (terowong; dead reckoning).
class VehicleModel {
  VehicleModel(this.route);

  final NavRoute route;

  /// Berapa lama selepas fix terakhir kenderaan terus diunjur mengikut kelajuan terakhir.
  static const maxExtrapolation = Duration(seconds: 90);

  /// Pemalar masa pembetulan; lebih kecil = lebih cepat mengikut GPS.
  static const _correctionTau = 0.35;

  /// Beza lebih daripada ini dianggap lompatan sebenar (bukan hingar), lalu terus melompat.
  static const _snapDistanceM = 40.0;

  bool _onRoute = true;
  double _anchorAlong = 0;
  DateTime? _anchorTime;
  double _speed = 0;

  double? _display;
  DateTime? _lastFrame;

  // Mod luar laluan.
  GeoPoint _freePoint = const GeoPoint(0, 0);
  double _freeBearing = 0;
  bool _hasFree = false;
  GeoPoint? _freeDisplay;

  bool get hasPosition => _anchorTime != null || _hasFree;

  /// Fix yang dipadankan dengan laluan.
  void onRouteFix({
    required double alongM,
    required double speedMps,
    required DateTime time,
  }) {
    _onRoute = true;
    _anchorAlong = alongM;
    _anchorTime = time;
    final s = speedMps < 0.5 ? 0.0 : speedMps;
    _speed = _display == null ? s : _speed * 0.4 + s * 0.6;
  }

  /// Fix di luar laluan (menyimpang / menunggu re-route).
  void onFreeFix({
    required GeoPoint point,
    required double? bearing,
    required double speedMps,
    required DateTime time,
  }) {
    _onRoute = false;
    _anchorTime = time;
    _freePoint = point;
    if (bearing != null) _freeBearing = bearing;
    _speed = speedMps < 0.5 ? 0 : speedMps;
    _hasFree = true;
  }

  VehiclePose poseAt(DateTime now) {
    final anchor = _anchorTime;
    if (anchor == null) {
      return const VehiclePose(
        point: GeoPoint(0, 0),
        bearing: 0,
        speedMps: 0,
        onRoute: false,
        alongM: 0,
      );
    }
    final sinceFix = _clampDuration(now.difference(anchor));
    return _onRoute ? _routePose(now, sinceFix) : _freePose(now, sinceFix);
  }

  VehiclePose _routePose(DateTime now, Duration sinceFix) {
    final target = math.min(
      route.totalM,
      _anchorAlong + _speed * sinceFix.inMicroseconds / 1e6,
    );
    final previous = _display;
    var display = previous ?? target;
    final lastFrame = _lastFrame;
    if (previous != null && lastFrame != null) {
      final dt = (now.difference(lastFrame).inMicroseconds / 1e6).clamp(
        0.0,
        2.0,
      );
      // Suapan ke hadapan: kenderaan terus bergerak pada kelajuannya; hanya SELISIH daripada
      // sasaran (ralat GPS) dibetulkan beransur-ansur. Tanpa ini, pelicinan eksponen meninggalkan
      // kenderaan ketinggalan tetap sebanyak kelajuan x pemalar masa.
      final predicted = math.min(route.totalM, display + _speed * dt);
      final error = target - predicted;
      if (error.abs() > _snapDistanceM) {
        display = target;
      } else {
        display = predicted + error * (1 - math.exp(-dt / _correctionTau));
        // Tidak pernah berundur kerana hingar; hanya menunggu sasaran mengejar.
        display = math.max(display, previous);
      }
    }
    _display = display;
    _lastFrame = now;

    final lookAhead = (_speed * 1.2).clamp(12.0, 45.0);
    return VehiclePose(
      point: route.pointAt(display),
      bearing: route.bearingAt(display, lookAheadM: lookAhead),
      speedMps: _speed,
      onRoute: true,
      alongM: display,
    );
  }

  VehiclePose _freePose(DateTime now, Duration sinceFix) {
    // Unjuran jangka pendek sahaja di luar laluan: tiada geometri untuk dipercayai.
    final secs = math.min(3.0, sinceFix.inMicroseconds / 1e6);
    final target = _speed > 0
        ? destinationPoint(_freePoint, _freeBearing, _speed * secs)
        : _freePoint;
    final previous = _freeDisplay;
    GeoPoint display = target;
    final lastFrame = _lastFrame;
    if (previous != null && lastFrame != null) {
      final dt = (now.difference(lastFrame).inMicroseconds / 1e6).clamp(
        0.0,
        2.0,
      );
      final k = 1 - math.exp(-dt / _correctionTau);
      final predicted = _speed > 0
          ? destinationPoint(previous, _freeBearing, _speed * dt)
          : previous;
      if (distanceMeters(predicted, target) > _snapDistanceM) {
        display = target;
      } else {
        display = GeoPoint(
          predicted.lat + (target.lat - predicted.lat) * k,
          predicted.lng + (target.lng - predicted.lng) * k,
        );
      }
    }
    _freeDisplay = display;
    _lastFrame = now;
    return VehiclePose(
      point: display,
      bearing: _freeBearing,
      speedMps: _speed,
      onRoute: false,
      alongM: 0,
    );
  }

  Duration _clampDuration(Duration d) {
    if (d.isNegative) return Duration.zero;
    return d > maxExtrapolation ? maxExtrapolation : d;
  }
}
