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

  /// Kedudukan sepanjang laluan (m) pada bingkai semasa, dibundar ke 5 m; null jika di luar laluan.
  /// Fix GPS tiba ~1 Hz tetapi kenderaan dilukis 60 fps, jadi kad manuver membaca ini supaya kiraan
  /// jarak turun lancar. Dibundar supaya pendengar tidak dibina semula setiap bingkai.
  final ValueNotifier<double?> alongM = ValueNotifier(null);

  CameraRig? _rig;
  Duration? _lastElapsed;
  DateTime? _lastInteraction;

  // Nilai terakhir yang dihantar ke peta. Setiap bingkai = dua panggilan platform (marker + kamera);
  // apabila kenderaan berhenti (lampu isyarat, jam) nilainya sama 60 kali sesaat, jadi bingkai yang
  // tidak mengubah apa-apa tidak dihantar. Peranti lemah dan bateri menanggung kos setiap panggilan itu.
  VehicleMarker? _sentMarker;
  CameraPose? _sentCamera;
  int _markerSkipped = 0;
  int _cameraSkipped = 0;

  /// Pose yang tidak berubah dihantar semula selepas sekian bingkai (~0.5 saat pada 60 fps). Peta
  /// menggabungkan hantaran (nilai terkini tidak digugurkan), jadi ini hanya jaring keselamatan
  /// apabila peta digerakkan di luar kawalan kita (cth. isyarat pengguna).
  static const _heartbeatFrames = 30;

  /// Tambahan zum pilihan pengguna (butang +/-) di atas zum automatik. Kekal sepanjang perjalanan.
  double _zoomBias = 0;
  double get zoomBias => _zoomBias;

  static const _minZoomBias = -3.0;
  static const _maxZoomBias = 2.0;

  /// Laraskan zum SAMBIL terus mengikut kenderaan. Menekan +/- tidak boleh melepaskan kamera:
  /// dahulu ia dikira sebagai pengguna menggerakkan peta, jadi kamera berhenti mengikut selama 10 s
  /// dan kenderaan hanyut dari kedudukannya.
  void nudgeZoom(double amount) {
    _zoomBias = (_zoomBias + amount).clamp(_minZoomBias, _maxZoomBias);
  }

  /// Pengguna menggerakkan peta.
  void userInteracted() {
    _lastInteraction = clock();
    if (follow.value == NavFollow.following) follow.value = NavFollow.free;
  }

  /// Kembali mengikut kenderaan dengan peralihan lembut dari pandangan semasa.
  void recenter() {
    _rig = null; // dibina semula daripada pose peta semasa => terbang masuk
    _lastInteraction = null;
    // Peta mungkin telah digerakkan pengguna: pose "terakhir dihantar" tidak lagi menggambarkannya.
    _sentCamera = null;
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

    final liveAlong = pose.onRoute ? (pose.alongM / 5).floor() * 5.0 : null;
    if (alongM.value != liveAlong) alongM.value = liveAlong;

    final marker = VehicleMarker(point: pose.point, bearing: pose.bearing);
    if (!_sameMarker(_sentMarker, marker) ||
        ++_markerSkipped >= _heartbeatFrames) {
      camera.showVehicle(marker);
      _sentMarker = marker;
      _markerSkipped = 0;
    }

    if (follow.value == NavFollow.free) {
      final last = _lastInteraction;
      if (last != null && now.difference(last) >= autoRecenter) recenter();
    }
    if (follow.value != NavFollow.following) {
      // Kamera dilepaskan (pengguna/ikhtisar): ia tidak lagi di tempat yang terakhir kita hantar.
      _sentCamera = null;
      return;
    }

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

    // rig.step mesti dipanggil setiap bingkai (ia memajukan keadaan dalamannya); hanya penghantaran
    // ke peta yang digugurkan apabila hasilnya sama.
    final target = rig.step(
      dt: dt,
      vehicle: pose.point,
      vehicleBearing: pose.bearing,
      speedMps: pose.speedMps,
      distanceToNextM: distanceToNext,
      nextKind: pose.onRoute ? next?.kind : null,
      viewportHeightPx: viewportHeight(),
      mode: cameraMode(),
      zoomBias: _zoomBias,
    );
    if (!_sameCamera(_sentCamera, target) ||
        ++_cameraSkipped >= _heartbeatFrames) {
      camera.moveTo(target);
      _sentCamera = target;
      _cameraSkipped = 0;
    }
  }

  // Ambang jauh di bawah apa-apa yang boleh dilihat: 1e-8 darjah ~ 1 mm; 1e-3 darjah/zum.
  static bool _sameMarker(VehicleMarker? a, VehicleMarker b) =>
      a != null &&
      (a.point.lat - b.point.lat).abs() < 1e-8 &&
      (a.point.lng - b.point.lng).abs() < 1e-8 &&
      (a.bearing - b.bearing).abs() < 1e-3;

  static bool _sameCamera(CameraPose? a, CameraPose b) =>
      a != null &&
      (a.center.lat - b.center.lat).abs() < 1e-8 &&
      (a.center.lng - b.center.lng).abs() < 1e-8 &&
      (a.zoom - b.zoom).abs() < 1e-3 &&
      (a.tilt - b.tilt).abs() < 1e-3 &&
      (a.bearing - b.bearing).abs() < 1e-3;

  void dispose() {
    follow.dispose();
    alongM.dispose();
  }
}
