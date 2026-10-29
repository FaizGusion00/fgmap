import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import '../../map/presentation/map_view.dart';
import '../domain/camera_planner.dart';
import '../domain/cruise_motion.dart';
import 'car/vehicle_overlay.dart';
import 'navigation_frame_driver.dart';

/// Satu sampel GPS untuk pemacu kamera memandu bebas.
@immutable
class CruiseFix {
  const CruiseFix({
    required this.point,
    required this.bearing,
    required this.speedMps,
    required this.time,
  });

  final GeoPoint point;
  final double bearing;
  final double speedMps;
  final DateTime time;
}

/// Kamera memandu bebas gaya Waze: **sentiasa 2D** (tilt 0), heading-up, penanda peta rata
/// sahaja (tiada overlay 3D). Mod kamera navigasi diabaikan supaya free-ride tidak "lepek" 3D.
class CruiseFrameDriver {
  CruiseFrameDriver({
    required this.camera,
    required this.sample,
    required this.viewportHeight,
    required this.cameraMode,
    required this.clock,
    this.screenOffset = _defaultCruiseOffset,
    this.viewportWidth,
    this.reduceMotion = false,
    this.autoRecenter = const Duration(seconds: 10),
    this.onPose,
  });

  final MapCameraController camera;
  final CruiseFix? Function() sample;
  final double Function() viewportHeight;

  /// Dikekalkan untuk API sedia ada; free-ride sentiasa [NavCameraMode.flat].
  final NavCameraMode Function() cameraMode;
  final DateTime Function() clock;
  final double Function() screenOffset;
  final double Function()? viewportWidth;
  final bool reduceMotion;
  final Duration autoRecenter;
  final void Function(CameraPose pose, {required bool following})? onPose;

  static double _defaultCruiseOffset() => cruiseScreenOffset;

  final ValueNotifier<NavFollow> follow = ValueNotifier(NavFollow.following);

  /// Sentiasa null dalam free-ride (tiada overlay 3D). Notifier dikekalkan supaya
  /// [map_screen] / ujian lama yang mendengarnya tidak rosak.
  final ValueNotifier<CarPlacement?> car = ValueNotifier(null);

  final CruiseMotion _motion = CruiseMotion();
  CameraRig? _rig;
  Duration? _lastElapsed;
  DateTime? _lastInteraction;
  double _zoomBias = 0;
  double? _prevBearing;
  double _yawRate = 0;
  static const _maxYawRate = 120.0;

  static const _measureEveryFrames = 15;
  int _sinceMeasure = 0;
  bool _measuring = false;
  double _groundScale = 1;
  bool _hasResidual = false;
  double _resY = 0;

  VehicleMarker? _sentMarker;
  bool _disposed = false;

  /// Pengali ofset tanah yang dipelajari (1 = model tepat). Untuk ujian.
  double get groundScale => _groundScale;

  void userInteracted() {
    _lastInteraction = clock();
    if (follow.value == NavFollow.following) follow.value = NavFollow.free;
  }

  void recenter() {
    _rig = null;
    _prevBearing = null;
    _yawRate = 0;
    _hasResidual = false;
    _resY = 0;
    _groundScale = 1;
    _lastInteraction = null;
    follow.value = NavFollow.following;
  }

  /// App / permukaan AA kembali: paksa penanda dan kamera dilukis semula.
  void reviveAfterForeground() {
    if (car.value != null) car.value = null;
    final marker = _sentMarker;
    if (marker != null) {
      camera.showVehicle(null);
      camera.showVehicle(marker);
    }
  }

  void nudgeZoom(double amount) {
    _zoomBias = (_zoomBias + amount).clamp(-3.0, 2.0);
  }

  void step(Duration elapsed) {
    if (_disposed) return;
    final timing = frameStep(elapsed, _lastElapsed);
    _lastElapsed = elapsed;
    if (timing.rewound) {
      _prevBearing = null;
      _yawRate = 0;
    }
    final dt = timing.seconds;
    final now = clock();
    // Auto-recenter walaupun tiada fix supaya pan bebas tidak tersekat selama-lamanya.
    if (follow.value == NavFollow.free) {
      final last = _lastInteraction;
      if (last != null && now.difference(last) >= autoRecenter) recenter();
    }
    final fix = sample();
    if (fix == null) return;
    _motion.onFix(
      point: fix.point,
      bearing: fix.bearing,
      speedMps: fix.speedMps,
      time: fix.time,
    );
    final shown = _motion.at(now);
    if (shown == null) return;
    final marker = VehicleMarker(point: shown.point, bearing: shown.bearing);
    if (follow.value != NavFollow.following) {
      _showMapMarker(marker);
      if (car.value != null) car.value = null;
      onPose?.call(
        camera.pose ??
            CameraPose(
              center: shown.point,
              zoom: 16,
              tilt: 0,
              bearing: shown.bearing,
            ),
        following: false,
      );
      return;
    }

    final previousBearing = _prevBearing;
    if (previousBearing != null && dt > 0) {
      final rate = (angleDelta(previousBearing, shown.bearing) / dt).clamp(
        -_maxYawRate,
        _maxYawRate,
      );
      _yawRate += (rate - _yawRate) * (1 - math.exp(-dt / 0.15));
    }
    _prevBearing = shown.bearing;

    // Free-ride: selalu flat (abaikan mod kamera navigasi).
    const mode = NavCameraMode.flat;
    final pose = camera.pose;
    final entry =
        pose ??
        CameraPose(
          center: shown.point,
          zoom: 17,
          tilt: 0,
          bearing: shown.bearing,
        );
    final rig = _rig ??= CameraRig(
      entry: entry,
      responsiveness: reduceMotion ? 2 : 1,
      entryDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1400),
    );
    final target = rig.step(
      dt: dt.clamp(0.0, 0.25),
      vehicle: shown.point,
      vehicleBearing: shown.bearing,
      speedMps: shown.speedMps,
      distanceToNextM: null,
      nextKind: null,
      viewportHeightPx: viewportHeight(),
      mode: mode,
      zoomBias: _zoomBias,
      screenOffset: screenOffset(),
      groundScale: _groundScale,
      yawRateDeg: _yawRate.abs(),
    );
    camera.moveTo(target);
    onPose?.call(target, following: true);

    // Waze 2D: penanda peta sahaja; pastikan overlay 3D tidak pernah aktif.
    if (car.value != null) car.value = null;
    _showMapMarker(marker);

    if (!_measuring && ++_sinceMeasure >= _measureEveryFrames) {
      _sinceMeasure = 0;
      _measure(shown.point);
    }
  }

  void _measure(GeoPoint point) {
    _measuring = true;
    final width = viewportWidth?.call();
    final height = viewportHeight();
    camera
        .screenPointOf(point)
        .then(
          (p) {
            _measuring = false;
            if (p == null || _disposed || follow.value != NavFollow.following) {
              return;
            }
            _onMeasured(p, width, height);
          },
          onError: (Object _) {
            _measuring = false;
          },
        );
  }

  void _onMeasured(Offset p, double? width, double height) {
    final rig = _rig;
    if (rig == null || height <= 0) return;
    final fy = p.dy / height;
    final fx = (width == null || width <= 0) ? 0.5 : p.dx / width;
    if (!fy.isFinite || !fx.isFinite || fy < 0.3 || fy > 0.98) return;
    if ((fx - 0.5).abs() > 0.4) return;

    final wantedY = 0.5 + rig.screenOffset;
    final resY = fy - wantedY;
    _resY = _hasResidual ? _resY + (resY - _resY) * 0.4 : resY;
    _hasResidual = true;

    if (resY.abs() > 0.03) {
      final actual = fy - 0.5;
      final ratio = actual > 0.02
          ? (rig.screenOffset / actual).clamp(0.6, 1.8)
          : 1.8;
      _groundScale = (_groundScale * (1 + 0.15 * (ratio - 1))).clamp(0.5, 3.0);
    }
  }

  void _showMapMarker(VehicleMarker marker) {
    camera.showVehicle(marker);
    _sentMarker = marker;
  }

  void dispose() {
    _disposed = true;
    follow.dispose();
    car.dispose();
  }
}
