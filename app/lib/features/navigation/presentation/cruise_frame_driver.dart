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

/// Kamera 3D memandu bebas. Menggunakan [CameraRig] yang sama seperti navigasi, tanpa manuver
/// (jadi tiada zum masuk ke selekoh) dan tanpa pemacu bingkai navigasi atau garisan laluan.
class CruiseFrameDriver {
  CruiseFrameDriver({
    required this.camera,
    required this.sample,
    required this.viewportHeight,
    required this.clock,
    this.screenOffset = _defaultScreenOffset,
    this.reduceMotion = false,
    this.autoRecenter = const Duration(seconds: 10),
    this.onPose,
  });

  final MapCameraController camera;
  final CruiseFix? Function() sample;
  final double Function() viewportHeight;
  final DateTime Function() clock;
  final double Function() screenOffset;
  final bool reduceMotion;
  final Duration autoRecenter;
  final void Function(CameraPose pose, {required bool following})? onPose;

  static double _defaultScreenOffset() => carScreenOffset;

  final ValueNotifier<NavFollow> follow = ValueNotifier(NavFollow.following);
  final ValueNotifier<CarPlacement?> car = ValueNotifier(null);

  final CruiseMotion _motion = CruiseMotion();
  CameraRig? _rig;
  Duration? _lastElapsed;
  DateTime? _lastInteraction;
  double _zoomBias = 0;
  double? _yaw;
  bool _disposed = false;

  void userInteracted() {
    _lastInteraction = clock();
    if (follow.value == NavFollow.following) follow.value = NavFollow.free;
  }

  void recenter() {
    _rig = null;
    _yaw = null;
    _lastInteraction = null;
    follow.value = NavFollow.following;
  }

  /// App / permukaan AA kembali: paksa overlay dan kamera dilukis semula.
  void reviveAfterForeground() {
    _yaw = null;
    final current = car.value;
    if (current != null) {
      car.value = null;
      car.value = current;
    }
  }

  void nudgeZoom(double amount) {
    _zoomBias = (_zoomBias + amount).clamp(-3.0, 2.0);
  }

  void step(Duration elapsed) {
    if (_disposed) return;
    final timing = frameStep(elapsed, _lastElapsed);
    _lastElapsed = elapsed;
    if (timing.rewound) _yaw = null;
    final dt = timing.seconds;
    final fix = sample();
    if (fix == null) return;
    _motion.onFix(
      point: fix.point,
      bearing: fix.bearing,
      speedMps: fix.speedMps,
      time: fix.time,
    );
    final now = clock();
    if (follow.value == NavFollow.free) {
      final last = _lastInteraction;
      if (last != null && now.difference(last) >= autoRecenter) recenter();
    }
    final shown = _motion.at(now);
    if (shown == null) return;
    final marker = VehicleMarker(point: shown.point, bearing: shown.bearing);
    if (follow.value != NavFollow.following) {
      camera.showVehicle(marker);
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

    final entry =
        camera.pose ??
        CameraPose(
          center: shown.point,
          zoom: 17,
          tilt: 55,
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
      zoomBias: _zoomBias,
      screenOffset: screenOffset(),
    );
    camera.moveTo(target);
    onPose?.call(target, following: true);
    camera.showVehicle(null);

    final opacity = ((rig.entryProgress - 0.8) / 0.2).clamp(0.0, 1.0);
    final yawGoal = angleDelta(
      target.bearing,
      shown.bearing,
    ).clamp(-80.0, 80.0);
    final yaw = smoothCarYaw(_yaw, yawGoal, dt);
    _yaw = yaw;
    final placement = CarPlacement(
      yawDeg: yaw,
      tiltDeg: target.tilt,
      anchorY: (0.5 + rig.screenOffset).clamp(0.3, 0.95),
      opacity: opacity,
    );
    if (!placement.isVisiblySameAs(car.value)) car.value = placement;
  }

  void dispose() {
    _disposed = true;
    follow.dispose();
    car.dispose();
  }
}
