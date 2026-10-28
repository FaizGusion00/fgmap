import 'dart:math' as math;

import 'package:flutter/widgets.dart' show EdgeInsets, Offset;
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../../core/utils/geo.dart';
import '../../map/presentation/map_view.dart';
import '../domain/camera_planner.dart';
import '../domain/nav_route.dart';
import '../domain/navigation_session.dart';
import '../domain/vehicle_model.dart';
import 'car/vehicle_overlay.dart';

/// Satu langkah masa untuk pemacu bingkai.
class FrameStep {
  const FrameStep(this.seconds, {required this.rewound});

  final double seconds;

  /// Benar apabila jam ticker berundur (app kembali dari latar dan ticker dimulakan semula).
  final bool rewound;
}

/// dt sesaat yang selamat. Elapsed yang berundur atau tidak sah ialah satu bingkai,
/// bukan selang negatif yang memutar kereta.
FrameStep frameStep(Duration elapsed, Duration? previous) {
  if (previous == null) return const FrameStep(1 / 60, rewound: false);
  final dt = (elapsed - previous).inMicroseconds / 1e6;
  if (!dt.isFinite || dt <= 0) return const FrameStep(1 / 60, rewound: true);
  return FrameStep(dt > 0.25 ? 0.25 : dt, rewound: false);
}

/// Yaw kereta 3D menuju [goal] (sudah dalam -80..80). Masa tidak sah atau yaw yang
/// sudah terlepas diikat semula pada sasaran, supaya kereta tidak berpusing jauh.
double smoothCarYaw(double? current, double goal, double dt) {
  final g = goal.clamp(-80.0, 80.0);
  if (current == null || !current.isFinite || !dt.isFinite || dt <= 0) return g;
  if (current.abs() > 80) return g;
  const tau = 0.08;
  final k = 1 - math.exp(-dt / tau);
  return (current + (g - current) * k).clamp(-80.0, 80.0);
}

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
    this.route,
    this.screenOffset = _defaultScreenOffset,
    this.viewportWidth,
    this.reduceMotion = false,
    this.autoRecenter = const Duration(seconds: 10),
    this.onPose,
  });

  /// Pose kamera yang dihantar ke peta, untuk hos Android Auto. Null jika tidak diperlukan.
  final void Function(CameraPose pose, {required bool following})? onPose;

  final MapCameraController camera;
  final VehiclePose? Function(DateTime now) poseAt;
  final NavProgress? Function() progress;

  /// Laluan semasa untuk unjuran latensi sepanjang lengkung (bukan kord lurus).
  final NavRoute? Function()? route;
  final double Function() viewportHeight;
  final NavCameraMode Function() cameraMode;
  final DateTime Function() clock;

  /// Kedudukan menegak kenderaan di bawah tengah skrin (pecahan tinggi) untuk orientasi semasa.
  final double Function() screenOffset;

  /// Lebar paparan peta (piksel logikal); tanpanya kedudukan mendatar kereta tidak diselaraskan.
  final double Function()? viewportWidth;
  final bool reduceMotion;

  static double _defaultScreenOffset() => carScreenOffset;

  /// Selepas tempoh ini tanpa sentuhan, kamera kembali mengikut kenderaan.
  final Duration autoRecenter;

  /// Keadaan semasa untuk UI (butang "Pusatkan").
  final ValueNotifier<NavFollow> follow = ValueNotifier(NavFollow.following);

  /// Kedudukan sepanjang laluan (m) pada bingkai semasa, dibundar ke 5 m; null jika di luar laluan.
  /// Fix GPS tiba ~1 Hz tetapi kenderaan dilukis 60 fps, jadi kad manuver membaca ini supaya kiraan
  /// jarak turun lancar. Dibundar supaya pendengar tidak dibina semula setiap bingkai.
  final ValueNotifier<double?> alongM = ValueNotifier(null);

  /// Di mana kereta 3D dilukis di skrin; null apabila kamera tidak mengikut kenderaan (kereta lapisan
  /// peta digunakan, kerana ketika itu kereta mesti terletak pada koordinat geografi) atau semasa
  /// peralihan masuk kamera.
  final ValueNotifier<CarPlacement?> car = ValueNotifier(null);

  /// Jarak (m) yang dilalui sepanjang laluan (kedudukan langsung kenderaan, tidak dibundar), untuk
  /// memangkas garisan laluan di peta supaya bermula tepat di bawah kereta. Dikemas kini ~8 kali
  /// sesaat dan hanya apabila berubah >= 0.5 m: setiap kemas kini ialah satu panggilan ke peta.
  late final ValueNotifier<double?> routeAlong = ValueNotifier(
    progress()?.alongM,
  );
  DateTime? _lastRouteAlongPush;
  static const _routeAlongEvery = Duration(milliseconds: 120);

  CameraRig? _rig;
  Duration? _lastElapsed;
  DateTime? _lastInteraction;

  // Nilai terakhir yang dihantar ke peta. Setiap bingkai = dua panggilan platform (marker + kamera);
  // apabila kenderaan berhenti (lampu isyarat, jam) nilainya sama 60 kali sesaat, jadi bingkai yang
  // tidak mengubah apa-apa tidak dihantar. Peranti lemah dan bateri menanggung kos setiap panggilan itu.
  VehicleMarker? _sentMarker;
  bool _markerSent = false;

  /// Arah kereta relatif kepada kamera yang dilicinkan untuk lukisan. Arah kenderaan diukur sebagai
  /// kord ke hadapan di sepanjang laluan, dan di selekoh/ramp tajam ia boleh berubah belasan darjah
  /// dalam satu bingkai; kamera sudah melicinkannya, tetapi kereta mesti juga.
  double? _yaw;

  // Kompensasi latensi kamera native: peta menunjukkan kamera yang dihantar [cameraLatency] lalu, jadi
  // (a) kamera dihantar pada pose yang diunjur sejauh itu ke hadapan (kedudukan dan arah), dan (b) yaw
  // kereta dikira berbanding arah kamera yang SEBENARNYA sedang dipaparkan. Tanpa ini jalan lewat di bawah
  // kereta (dilukis serta-merta oleh Flutter) dan kereta kelihatan hanyut di selekoh.
  double? _prevBearing;
  double _yawRate = 0;
  final List<(double, double)> _sentBearings = [];
  static const _maxYawRate = 120.0;

  // Penentukuran daripada kedudukan skrin kenderaan yang SEBENAR. Kamera dikira daripada model unjuran
  // MapLibre supaya kenderaan berada ~69% dari atas skrin, tetapi pada peranti sebenar (cth. iOS) kenderaan
  // boleh jatuh jauh lebih dekat tengah, dan kereta yang dilukis pada titik yang dikira itu terpisah
  // daripada laluan. Setiap ~0.25 s kedudukan sebenar diukur; kereta mengikutnya (baki ralat dilicinkan)
  // dan kamera dilaras perlahan sehingga kenderaan benar-benar berada di tempat yang dirancang.
  static const _measureEveryFrames = 15;
  int _sinceMeasure = 0;
  bool _measuring = false;
  bool _disposed = false;
  double _groundScale = 1;
  bool _hasResidual = false;
  double _resX = 0, _resY = 0;

  /// Pengali ofset tanah yang dipelajari daripada ukuran (1 = model tepat). Untuk diagnostik dan ujian.
  double get groundScale => _groundScale;
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
    _yaw = null;
    _prevBearing = null;
    _yawRate = 0;
    _sentBearings.clear();
    _hasResidual = false;
    _resX = _resY = 0;
    _lastInteraction = null;
    // Peta mungkin telah digerakkan pengguna: pose "terakhir dihantar" tidak lagi menggambarkannya.
    _sentCamera = null;
    follow.value = NavFollow.following;
  }

  /// App kembali dari latar / permukaan AA sedia: paksa kamera dan overlay dilukis semula
  /// tanpa animasi masuk penuh (itu tugas [recenter]).
  void reviveAfterForeground() {
    _sentCamera = null;
    _sentBearings.clear();
    _yawRate = 0;
    _prevBearing = null;
    _markerSent = false;
    _markerSkipped = 0;
    _cameraSkipped = _heartbeatFrames;
    // Paksa [VehicleOverlay] mengecat semula walaupun pose kelihatan sama.
    final current = car.value;
    if (current != null) {
      car.value = null;
      car.value = current;
    }
  }

  /// Tunjukkan keseluruhan laluan baki.
  void showOverview(List<GeoPoint> shape, {required EdgeInsets padding}) {
    follow.value = NavFollow.overview;
    _lastInteraction = null;
    camera.fitTo(shape, padding: padding);
  }

  /// Satu bingkai. [elapsed] ialah masa yang berlalu daripada `Ticker`.
  void step(Duration elapsed) {
    final timing = frameStep(elapsed, _lastElapsed);
    _lastElapsed = elapsed;
    if (timing.rewound) {
      // Ticker dimulakan semula selepas app kembali: jamnya bermula dari sifar.
      // Jangan anggap itu sebagai masa negatif (kereta berpusing) dan jangan
      // pegang arah kamera lama yang kini "pada masa hadapan".
      _sentBearings.clear();
      _yawRate = 0;
      _prevBearing = null;
      _yaw = null;
    }
    final dt = timing.seconds;

    final now = clock();
    final pose = poseAt(now);
    if (pose == null) return;

    final liveAlong = pose.onRoute ? (pose.alongM / 5).floor() * 5.0 : null;
    if (alongM.value != liveAlong) alongM.value = liveAlong;
    if (pose.onRoute) _pushRouteAlong(pose.alongM, now);

    final marker = VehicleMarker(point: pose.point, bearing: pose.bearing);

    if (follow.value == NavFollow.free) {
      final last = _lastInteraction;
      if (last != null && now.difference(last) >= autoRecenter) recenter();
    }
    if (follow.value != NavFollow.following) {
      // Kamera dilepaskan (pengguna/ikhtisar): ia tidak lagi di tempat yang terakhir kita hantar, dan
      // kereta mesti dilukis pada koordinatnya di peta.
      _sentCamera = null;
      _showMapMarker(marker);
      if (car.value != null) car.value = null;
      final held = camera.pose;
      if (held != null) onPose?.call(held, following: false);
      return;
    }

    final entry =
        camera.pose ??
        CameraPose(
          center: pose.point,
          zoom: 17,
          tilt: 55,
          bearing: pose.bearing,
        );
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

    // Unjuran ke hadapan sepanjang latensi kamera native (lihat medan _yawRate).
    final latency = camera.cameraLatency.inMicroseconds / 1e6;
    final previousBearing = _prevBearing;
    if (previousBearing != null && dt > 0) {
      final rate = (angleDelta(previousBearing, pose.bearing) / dt).clamp(
        -_maxYawRate,
        _maxYawRate,
      );
      _yawRate += (rate - _yawRate) * (1 - math.exp(-dt / 0.15));
    }
    _prevBearing = pose.bearing;
    final leadMeters = latency > 0 && pose.speedMps > 0
        ? pose.speedMps * latency
        : 0.0;
    final navRoute = route?.call();
    final GeoPoint leadPoint;
    final double leadBearing;
    if (leadMeters > 0 && pose.onRoute && navRoute != null) {
      // Unjuran sepanjang lengkung paparan — kord lurus menolak kereta ke luar selekoh.
      final leadAlong = math.min(navRoute.totalM, pose.alongM + leadMeters);
      leadPoint = navRoute.displayPointAt(leadAlong);
      leadBearing = navRoute.displayBearingAt(
        leadAlong,
        lookAheadM: (pose.speedMps * 0.6).clamp(5.0, 12.0),
      );
    } else if (leadMeters > 0) {
      leadPoint = destinationPoint(pose.point, pose.bearing, leadMeters);
      leadBearing = normalizeBearing(pose.bearing + _yawRate * latency);
    } else {
      leadPoint = pose.point;
      leadBearing = pose.bearing;
    }

    // rig.step mesti dipanggil setiap bingkai (ia memajukan keadaan dalamannya); hanya penghantaran
    // ke peta yang digugurkan apabila hasilnya sama.
    final target = rig.step(
      dt: dt,
      vehicle: leadPoint,
      vehicleBearing: leadBearing,
      speedMps: pose.speedMps,
      distanceToNextM: distanceToNext,
      nextKind: pose.onRoute ? next?.kind : null,
      viewportHeightPx: viewportHeight(),
      mode: cameraMode(),
      zoomBias: _zoomBias,
      screenOffset: screenOffset(),
      groundScale: _groundScale,
      yawRateDeg: _yawRate.abs(),
    );
    if (!_sameCamera(_sentCamera, target) ||
        ++_cameraSkipped >= _heartbeatFrames) {
      camera.moveTo(target);
      _sentCamera = target;
      _cameraSkipped = 0;
    }
    onPose?.call(target, following: true);

    // Kereta 3D di atas peta hanya apabila kamera sudah tiba di kenderaan: semasa peralihan masuk peta
    // masih meluncur, jadi kereta lapisan peta (terikat koordinat) yang kelihatan dahulu, dan kereta 3D
    // muncul perlahan menjelang akhir. Selepas itu lapisan peta disembunyikan; kedua-duanya terletak di
    // titik skrin yang sama.
    final progressIn = rig.entryProgress;
    final opacity = ((progressIn - 0.8) / 0.2).clamp(0.0, 1.0);
    // Arah kamera yang sedang dipaparkan = yang dihantar [latency] saat lalu.
    final nowS = elapsed.inMicroseconds / 1e6;
    _sentBearings.add((nowS, target.bearing));
    while (_sentBearings.length > 1 && _sentBearings.first.$1 < nowS - 1) {
      _sentBearings.removeAt(0);
    }
    var displayedBearing = target.bearing;
    if (latency > 0) {
      displayedBearing = _sentBearings.first.$2;
      for (final (t, b) in _sentBearings) {
        if (t <= nowS - latency) displayedBearing = b;
      }
    }
    final yawGoal = angleDelta(
      displayedBearing,
      pose.bearing,
    ).clamp(-80.0, 80.0);
    final yaw = smoothCarYaw(_yaw, yawGoal, dt);
    _yaw = yaw;
    final placement = CarPlacement(
      yawDeg: yaw,
      tiltDeg: target.tilt,
      anchorY: (0.5 + rig.screenOffset + _resY).clamp(0.3, 0.95),
      anchorX: (0.5 + _resX).clamp(0.2, 0.8),
      opacity: opacity,
    );
    if (!placement.isVisiblySameAs(car.value)) car.value = placement;
    if (progressIn >= 1) {
      _hideMapMarker();
      if (!_measuring && ++_sinceMeasure >= _measureEveryFrames) {
        _sinceMeasure = 0;
        _measure(pose.point);
      }
    } else {
      _showMapMarker(marker);
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
    // Di luar paparan atau mustahil: abaikan.
    if (!fy.isFinite || !fx.isFinite || fy < 0.3 || fy > 0.98) return;
    if ((fx - 0.5).abs() > 0.4) return;

    final wantedY = 0.5 + rig.screenOffset;
    final resY = fy - wantedY;
    final resX = fx - 0.5;
    _resY = _hasResidual ? _resY + (resY - _resY) * 0.4 : resY;
    _resX = _hasResidual ? _resX + (resX - _resX) * 0.4 : resX;
    _hasResidual = true;

    // Laras kamera perlahan-lahan supaya kenderaan sampai ke kedudukan yang dirancang. Zon mati kecil
    // dan had per langkah mengelakkan kamera bergoyang akibat hingar ukuran.
    if (resY.abs() > 0.03) {
      final actual = fy - 0.5;
      final ratio = actual > 0.02
          ? (rig.screenOffset / actual).clamp(0.6, 1.8)
          : 1.8;
      _groundScale = (_groundScale * (1 + 0.15 * (ratio - 1))).clamp(0.5, 3.0);
    }
  }

  void _pushRouteAlong(double along, DateTime now) {
    final last = _lastRouteAlongPush;
    if (last != null && now.difference(last) < _routeAlongEvery) return;
    final current = routeAlong.value;
    if (current != null && (along - current).abs() < 0.5) return;
    routeAlong.value = along;
    _lastRouteAlongPush = now;
  }

  void _showMapMarker(VehicleMarker marker) {
    if (!_sameMarker(_sentMarker, marker) ||
        ++_markerSkipped >= _heartbeatFrames) {
      camera.showVehicle(marker);
      _sentMarker = marker;
      _markerSent = true;
      _markerSkipped = 0;
    }
  }

  void _hideMapMarker() {
    if (_markerSent && _sentMarker == null) return;
    camera.showVehicle(null);
    _sentMarker = null;
    _markerSent = true;
    _markerSkipped = 0;
  }

  // Ambang jauh di bawah apa-apa yang boleh dilihat: 1e-8 darjah ~ 1 mm; 1e-3 darjah/zum.
  static bool _sameMarker(VehicleMarker? a, VehicleMarker b) =>
      a != null &&
      (a.point.lat - b.point.lat).abs() < 1e-8 &&
      (a.point.lng - b.point.lng).abs() < 1e-8 &&
      angleDelta(a.bearing, b.bearing).abs() < 1e-3;

  static bool _sameCamera(CameraPose? a, CameraPose b) =>
      a != null &&
      (a.center.lat - b.center.lat).abs() < 1e-8 &&
      (a.center.lng - b.center.lng).abs() < 1e-8 &&
      (a.zoom - b.zoom).abs() < 1e-3 &&
      (a.tilt - b.tilt).abs() < 1e-3 &&
      angleDelta(a.bearing, b.bearing).abs() < 1e-3;

  void dispose() {
    _disposed = true;
    follow.dispose();
    alongM.dispose();
    routeAlong.dispose();
    car.dispose();
  }
}
