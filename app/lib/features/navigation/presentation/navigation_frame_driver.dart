import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../../core/utils/geo.dart';
import '../../map/presentation/map_view.dart';
import '../domain/camera_planner.dart';
import '../domain/navigation_session.dart';
import '../domain/vehicle_model.dart';

/// Bagaimana kamera berkaitan dengan kenderaan.
enum NavFollow {
  /// Kamera mengikut kenderaan.
  following,

  /// Pengguna menggerakkan peta; kamera berhenti mengikut sehingga "Pusatkan" atau tamat masa.
  free,

  /// Pandangan keseluruhan laluan baki.
  overview,
}

/// Memacu kamera dan marker kenderaan setiap bingkai (dipanggil daripada `Ticker`).
///
/// Tidak bergantung pada Flutter widget supaya boleh diuji dengan kamera palsu dan jam sendiri.
class NavigationFrameDriver {
  NavigationFrameDriver({
    required this.camera,
    required this.poseAt,
    required this.progress,
    required this.viewportHeight,
    required this.cameraMode,
    required this.clock,
    this.reduceMotion = false,
    this.autoRecenter = const Duration(seconds: 10),
  });

  final MapCameraController camera;
  final VehiclePose? Function(DateTime now) poseAt;
  final NavProgress? Function() progress;
  final double Function() viewportHeight;
  final NavCameraMode Function() cameraMode;
  final DateTime Function() clock;
  final bool reduceMotion;

  /// Selepas tempoh ini tanpa sentuhan, kamera kembali mengikut kenderaan.
  final Duration autoRecenter;

  /// Keadaan semasa untuk UI (butang "Pusatkan").
  final ValueNotifier<NavFollow> follow = ValueNotifier(NavFollow.following);

  CameraRig? _rig;
  Duration? _lastElapsed;
  DateTime? _lastInteraction;

  /// Pengguna menggerakkan peta.
  void userInteracted() {
    _lastInteraction = clock();
    if (follow.value == NavFollow.following) follow.value = NavFollow.free;
  }

  /// Kembali mengikut kenderaan dengan peralihan lembut dari pandangan semasa.
  void recenter() {
    _rig = null; // dibina semula daripada pose peta semasa => terbang masuk
    _lastInteraction = null;
    follow.value = NavFollow.following;
  }

  /// Tunjukkan keseluruhan laluan baki.
  void showOverview(List<GeoPoint> shape, {required EdgeInsets padding}) {
    follow.value = NavFollow.overview;
    _lastInteraction = null;
    camera.fitTo(shape, padding: padding);
  }

  /// Satu bingkai. [elapsed] ialah masa yang berlalu daripada `Ticker`.
  void step(Duration elapsed) {
    final dt = _lastElapsed == null
        ? 1 / 60
        : (elapsed - _lastElapsed!).inMicroseconds / 1e6;
    _lastElapsed = elapsed;

    final now = clock();
    final pose = poseAt(now);
    if (pose == null) return;

    camera.showVehicle(VehicleMarker(point: pose.point, bearing: pose.bearing));

    if (follow.value == NavFollow.free) {
      final last = _lastInteraction;
      if (last != null && now.difference(last) >= autoRecenter) recenter();
    }
    if (follow.value != NavFollow.following) return;

    final entry =
        camera.pose ??
        CameraPose(center: pose.point, zoom: 14, tilt: 0, bearing: 0);
    final rig = _rig ??= CameraRig(
      entry: entry,
      responsiveness: reduceMotion ? 2 : 1,
      entryDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1400),
    );

    final p = progress();
    final next = p?.next;
    final distanceToNext = (next != null && pose.onRoute)
        ? (next.startM - pose.alongM).clamp(0.0, double.infinity)
        : null;

    camera.moveTo(
      rig.step(
        dt: dt,
        vehicle: pose.point,
        vehicleBearing: pose.bearing,
        speedMps: pose.speedMps,
        distanceToNextM: distanceToNext,
        nextKind: pose.onRoute ? next?.kind : null,
        viewportHeightPx: viewportHeight(),
        mode: cameraMode(),
      ),
    );
  }

  void dispose() => follow.dispose();
}
