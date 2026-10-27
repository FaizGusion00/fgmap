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

  /// Gandaan fix terhadap ramalan (penapis alfa): 1 = percaya fix sepenuhnya (hingar GPS 3-5 m
  /// terus ke skrin), kecil = lebih licin tetapi lambat mengikut perubahan sebenar. Kelajuan Doppler
  /// jauh lebih tepat daripada kedudukan, jadi ramalan dipercayai separuh.
  static const _positionGain = 0.5;

  /// Inovasi (fix - ramalan) di bawah ini dianggap hingar dan ditapis; lebih besar diterima penuh.
  static const _noiseGateM = 25.0;

  /// Pecutan (m/s^2) dianggar daripada perubahan kelajuan Doppler antara fix; had fizikal kereta biasa.
  static const _maxDecel = -4.0;
  static const _maxAccel = 2.5;

  /// Ufuk pecutan: selepas ini kelajuan dianggap malar (pecutan tidak boleh diunjur tanpa had).
  static const _accelHorizonS = 2.0;

  bool _onRoute = true;
  double _accel = 0;
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
    var along = alongM;
    final previous = _anchorTime;
    if (_onRoute && previous != null && _display != null) {
      final dt = time.difference(previous).inMicroseconds / 1e6;
      if (dt > 0 && dt <= 5) {
        final predicted = _anchorAlong + _speed * dt;
        final innovation = alongM - predicted;
        if (innovation.abs() < _noiseGateM) {
          along = predicted + _positionGain * innovation;
        }
      }
    }
    _onRoute = true;
    _anchorAlong = along;
    _anchorTime = time;
    final s = speedMps < 0.5 ? 0.0 : speedMps;
    final previousSpeed = _speed;
    _speed = _display == null ? s : _speed * 0.4 + s * 0.6;
    if (previous != null && _display != null) {
      final dt = time.difference(previous).inMicroseconds / 1e6;
      if (dt >= 0.3 && dt <= 3) {
        // Pecutan daripada kelajuan mentah (bukan yang telah dilicinkan) berbanding yang dianggarkan
        // sebelum ini; ditapis supaya hingar kelajuan tidak menjadi brek palsu.
        final raw = ((s - previousSpeed) / dt).clamp(_maxDecel, _maxAccel);
        _accel = _accel * 0.5 + raw * 0.5;
      } else {
        _accel = 0;
      }
    } else {
      _accel = 0;
    }
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

  /// Kelajuan [t] saat selepas fix terakhir, dengan pecutan (membrek ke selekoh) sehingga ufuk.
  double _speedAfter(double t) {
    final te = math.min(t, _accelHorizonS);
    return math.max(0.0, _speed + _accel * te);
  }

  /// Jarak dilalui [t] saat selepas fix terakhir (pecutan sehingga ufuk, kemudian kelajuan malar).
  double _distanceAfter(double t) {
    if (_accel == 0) return _speed * t;
    var te = math.min(t, _accelHorizonS);
    // Berhenti sepenuhnya jika membrek melebihi kelajuan.
    if (_accel < 0) te = math.min(te, _speed / -_accel);
    final within = _speed * te + 0.5 * _accel * te * te;
    final vEnd = math.max(0.0, _speed + _accel * te);
    final rest = math.max(0.0, t - te);
    return within + (te < math.min(t, _accelHorizonS) ? 0 : vEnd * rest);
  }

  VehiclePose _routePose(DateTime now, Duration sinceFix) {
    final target = math.min(
      route.totalM,
      _anchorAlong + _distanceAfter(sinceFix.inMicroseconds / 1e6),
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
      final predicted = math.min(
        route.totalM,
        display + _speedAfter(sinceFix.inMicroseconds / 1e6) * dt,
      );
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

    // Paparan: selekoh dilengkungkan dan arah ialah tangen lengkung (bukan kord panjang yang mula
    // berputar berpuluh meter sebelum bucu dan kelihatan lewat/tersasar di selekoh).
    final lookAhead = (_speed * 0.6).clamp(5.0, 12.0);
    return VehiclePose(
      point: route.displayPointAt(display),
      bearing: route.displayBearingAt(display, lookAheadM: lookAhead),
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
