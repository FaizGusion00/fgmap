import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'camera_planner.dart';
import 'lane_plan.dart';
import 'nav_route.dart';
import 'speed_bubble_data.dart';
import 'vehicle_model.dart';

/// Mod yang dikongsi telefon dan Android Auto. Hanya satu yang memiliki kamera.
enum CarDriveMode { browse, cruise, navigating }

/// Satu lorong untuk skrin kereta: nama [LaneArrow] yang dibenarkan (kiri ke kanan) dan sama ada ia
/// disyorkan. Hanya daripada data lorong sebenar (lihat [carLanesFor]).
@immutable
class CarLane {
  const CarLane(this.arrows, this.recommended, [this.highlighted = const []]);

  final List<String> arrows;
  final bool recommended;

  /// Arah dalam lorong ini yang sebenarnya disyorkan (subset [arrows]); kosong jika tidak disyorkan.
  final List<String> highlighted;

  Map<String, Object?> toMap() => {
    'arrows': arrows,
    'recommended': recommended,
    'highlighted': highlighted,
  };

  @override
  bool operator ==(Object other) =>
      other is CarLane &&
      other.recommended == recommended &&
      listEquals(other.arrows, arrows) &&
      listEquals(other.highlighted, highlighted);

  @override
  int get hashCode => Object.hash(
    recommended,
    Object.hashAll(arrows),
    Object.hashAll(highlighted),
  );
}

/// Lorong untuk dihantar ke hos kereta. Hanya data lorong SEBENAR: UI lorong asli Android Auto dan
/// CarPlay tiada label "anggaran", jadi lorong yang diterbitkan daripada jenis manuver (anggaran)
/// tidak pernah dihantar; kereta hanya menerima ayat sisi ([CarSessionSnapshot.laneHint]).
List<CarLane> carLanesFor(LanePlan? plan) => plan == null || plan.estimated
    ? const []
    : [
        for (final l in plan.lanes)
          CarLane(
            [for (final a in l.arrows) a.name],
            l.recommended,
            [for (final a in l.highlighted) a.name],
          ),
      ];

/// Kedudukan kenderaan (atau pengguna dalam browse) untuk penanda di peta kereta. [bearing] null =
/// arah tidak diketahui (titik, bukan anak panah).
@immutable
class CarVehicle {
  const CarVehicle(this.point, [this.bearing]);

  final GeoPoint point;
  final double? bearing;
}

/// Gambar sesi untuk hos kereta. Laluan hanya ada semasa navigasi.
@immutable
class CarSessionSnapshot {
  const CarSessionSnapshot({
    required this.mode,
    this.pose,
    this.vehicle,
    this.speed = const SpeedBubbleData(speedMps: 0),
    this.route = const [],
    this.routeVersion = 0,
    this.maneuver,
    this.maneuverKind,
    this.roundaboutExit,
    this.distanceToManeuverM,
    this.remainingM,
    this.remainingS,
    this.etaEpochMs,
    this.following = true,
    this.dark = false,
    this.style,
    this.styleKey,
    this.cameraAlert,
    this.weatherAlert,
    this.alongCue,
    this.airAqi,
    this.prayerLine,
    this.lanes = const [],
    this.laneHint,
    this.rerouting = false,
    this.arrived = false,
    this.destination,
  });

  final CarDriveMode mode;

  /// Kamera skrin kereta. Semasa memandu pusatnya ialah kenderaan ([CarCamera]); hos kereta
  /// meletakkan kenderaan di kawasan stabil skrinnya dengan padding.
  final CameraPose? pose;

  /// Penanda kenderaan / pengguna di peta kereta; null sebelum fix GPS pertama.
  final CarVehicle? vehicle;
  final SpeedBubbleData speed;

  /// Kosong dalam browse dan cruise. Geometri laluan hanya semasa navigasi.
  final List<GeoPoint> route;
  final int routeVersion;
  final String? maneuver;

  /// Nama [ManeuverKind] (cth. `roundabout`) supaya hos kereta boleh memilih ikon manuver
  /// piawainya; teks [maneuver] kekal sebagai sandaran.
  final String? maneuverKind;

  /// Nombor simpang keluar bulatan, jika manuver ialah bulatan.
  final int? roundaboutExit;
  final double? distanceToManeuverM;
  final double? remainingM;
  final int? remainingS;
  final int? etaEpochMs;
  final bool following;
  final bool dark;
  final String? style;
  final String? styleKey;

  /// Amaran kamera AwAS/OSM (satu baris), cth. "Kamera AwAS · 600 m".
  final String? cameraAlert;

  /// Cuaca buruk semasa navigasi (jika dihidupkan), cth. "Cuaca buruk".
  final String? weatherAlert;

  /// R&R / minyak di hadapan (≤5 km). Hos menyembunyikan jika [cameraAlert] ada.
  final String? alongCue;

  /// IPU ringkas dalam mod browse sahaja, cth. "IPU 42 · Baik".
  final String? airAqi;

  /// Waktu solat seterusnya, cth. "Asar 16:28" (browse dan cruise; hilang semasa navigasi supaya
  /// tidak bersaing dengan manuver). Hanya bila Waktu Azan dihidupkan.
  final String? prayerLine;

  /// Lorong sebenar manuver seterusnya (kosong jika tiada data atau terlalu jauh).
  final List<CarLane> lanes;

  /// Ayat sisi ("Guna lorong paling kanan") untuk kereta tanpa data lorong; boleh berasal daripada
  /// anggaran kerana ia hanya menyebut sisi.
  final String? laneHint;

  /// Laluan sedang dikira semula: hos kereta menunjukkan "memuatkan", bukan manuver lapuk.
  final bool rerouting;

  /// Sudah tiba (telefon menunjukkan kad ketibaan): hos kereta menunjukkan mesej ketibaan.
  final bool arrived;

  /// Nama destinasi (untuk mesej ketibaan); null untuk titik pada peta.
  final String? destination;

  bool get hasRoute => mode == CarDriveMode.navigating && route.length >= 2;

  /// Satu isyarat pemanduan: kamera > cuaca > R&R.
  String? get driveAlert => cameraAlert ?? weatherAlert ?? alongCue;

  Map<String, Object?> toMap({
    bool includeRoute = true,
    bool includeStyle = true,
  }) {
    final pose = this.pose;
    final vehicle = this.vehicle;
    final limit = speed.showLimit ? speed.limitKmh : null;
    return {
      'mode': mode.name,
      'following': following,
      'lat': pose?.center.lat,
      'lng': pose?.center.lng,
      'bearing': pose?.bearing,
      'zoom': pose?.zoom,
      'tilt': pose?.tilt,
      'vehicleLat': vehicle?.point.lat,
      'vehicleLng': vehicle?.point.lng,
      'vehicleBearing': vehicle?.bearing,
      'speedMps': speed.speedMps,
      'speedKmh': speed.kmh,
      'limitKmh': limit,
      'overspeed': speed.overspeed,
      'routeVersion': routeVersion,
      if (includeRoute)
        'route': [
          for (final p in route) [p.lat, p.lng],
        ],
      'maneuver': maneuver,
      'maneuverKind': maneuverKind,
      'roundaboutExit': roundaboutExit,
      'distanceToManeuverM': distanceToManeuverM,
      'remainingM': remainingM,
      'remainingS': remainingS,
      'etaEpochMs': etaEpochMs,
      'dark': dark,
      if (includeStyle) 'style': style,
      if (includeStyle) 'styleKey': styleKey,
      'cameraAlert': cameraAlert,
      'weatherAlert': weatherAlert,
      'alongCue': alongCue,
      'driveAlert': driveAlert,
      'airAqi': airAqi,
      'prayerLine': prayerLine,
      'lanes': [for (final l in lanes) l.toMap()],
      'laneHint': laneHint,
      'rerouting': rerouting,
      'arrived': arrived,
      'destination': destination,
    };
  }
}

/// Peta keadaan telefon kepada satu gambar sesi. Cruise tidak pernah membawa garisan laluan.
CarSessionSnapshot mapCarSession({
  required bool navigating,
  required bool cruising,
  CameraPose? pose,
  CarVehicle? vehicle,
  double speedMps = 0,
  int? limitKmh,
  bool overspeed = false,
  List<GeoPoint> navigationRoute = const [],
  int routeVersion = 0,
  String? maneuver,
  String? maneuverKind,
  int? roundaboutExit,
  double? distanceToManeuverM,
  double? remainingM,
  int? remainingS,
  int? etaEpochMs,
  bool following = true,
  bool dark = false,
  String? style,
  String? styleKey,
  String? cameraAlert,
  String? weatherAlert,
  String? alongCue,
  String? airAqi,
  String? prayerLine,
  List<CarLane> lanes = const [],
  String? laneHint,
  bool rerouting = false,
  bool arrived = false,
  String? destination,
}) {
  final mode = navigating
      ? CarDriveMode.navigating
      : cruising
      ? CarDriveMode.cruise
      : CarDriveMode.browse;
  final speed = SpeedBubbleData(
    speedMps: speedMps,
    limitKmh: limitKmh,
    overspeed: overspeed,
  );
  // R&R disembunyikan apabila kamera aktif (keutamaan isyarat pemanduan).
  final along = cameraAlert == null ? alongCue : null;
  if (mode == CarDriveMode.navigating) {
    return CarSessionSnapshot(
      mode: mode,
      pose: pose,
      vehicle: vehicle,
      speed: speed,
      route: navigationRoute,
      routeVersion: routeVersion,
      maneuver: maneuver,
      maneuverKind: maneuverKind,
      roundaboutExit: roundaboutExit,
      distanceToManeuverM: distanceToManeuverM,
      remainingM: remainingM,
      remainingS: remainingS,
      etaEpochMs: etaEpochMs,
      following: following,
      dark: dark,
      style: style,
      styleKey: styleKey,
      cameraAlert: cameraAlert,
      weatherAlert: weatherAlert,
      alongCue: along,
      // Selepas tiba tiada manuver/lorong lagi untuk diikut.
      lanes: arrived ? const [] : lanes,
      laneHint: arrived ? null : laneHint,
      rerouting: rerouting && !arrived,
      arrived: arrived,
      destination: destination,
    );
  }
  if (mode == CarDriveMode.cruise) {
    return CarSessionSnapshot(
      mode: mode,
      pose: pose,
      vehicle: vehicle,
      speed: speed,
      following: following,
      dark: dark,
      style: style,
      styleKey: styleKey,
      // Cruise: cuaca sahaja (tiada laluan → tiada kamera/R&R).
      weatherAlert: weatherAlert,
      prayerLine: prayerLine,
    );
  }
  // Browse: peta kereta di lokasi pengguna (tanpa ini MapLibre kekal pada 0,0 di Teluk Guinea
  // sehingga kereta mula bergerak).
  return CarSessionSnapshot(
    mode: CarDriveMode.browse,
    pose: pose,
    vehicle: vehicle,
    following: true,
    dark: dark,
    style: style,
    styleKey: styleKey,
    airAqi: airAqi,
    prayerLine: prayerLine,
  );
}

/// Pandangan browse di skrin kereta: atas ke bawah menghadap utara, zum kejiranan.
CameraPose carBrowsePose(GeoPoint point) =>
    CameraPose(center: point, zoom: 15.5, tilt: 0, bearing: 0);

/// Kamera skrin kereta (Android Auto), berasingan daripada kamera telefon.
///
/// Dahulu skrin kereta menyalin pose kamera telefon. Pose itu (1) dikira untuk paparan telefon (pusat
/// di hadapan kenderaan mengikut tinggi skrin telefon, bukan skrin kereta), (2) berhenti sebaik
/// telefon dikunci kerana ticker bingkai tidak berjalan di latar, dan (3) membeku apabila peta
/// telefon digerakkan. Kamera ini memakai [CameraRig]/[planCamera] yang sama (zum pintar: belokan
/// berangkai, pegang zum sejurus selepas belok) tetapi berpusat TEPAT pada kenderaan; hos kereta
/// meletakkan kenderaan di kawasan stabil skrinnya dengan padding kamera.
class CarCamera {
  CameraRig? _rig;
  DateTime? _last;
  bool? _navigating;
  NavCameraMode? _mode;
  double? _prevBearing;
  double _yawRate = 0;
  NavManeuver? _lastNext;
  NavManeuver? _passed;

  /// Tinggi rujukan [viewportZoomAdjust] (tiada pelarasan): Dart tidak tahu tinggi skrin kereta.
  static const viewportHeightPx = 640.0;

  /// Jurang lebih lama daripada ini (kereta terputus, app dibunuh) = mula semula tanpa pelicinan.
  static const _gap = Duration(seconds: 3);

  void reset() {
    _rig = null;
    _last = null;
    _navigating = null;
    _mode = null;
    _prevBearing = null;
    _yawRate = 0;
    _lastNext = null;
    _passed = null;
  }

  /// Satu sampel kamera pada [now]. [next]/[following] ialah manuver seterusnya dan selepasnya
  /// (navigasi sahaja); free-ride sentiasa 2D seperti telefon.
  CameraPose step({
    required DateTime now,
    required VehiclePose vehicle,
    required bool navigating,
    NavManeuver? next,
    NavManeuver? following,
    NavCameraMode mode = NavCameraMode.auto,
  }) {
    final camMode = navigating ? mode : NavCameraMode.flat;
    final last = _last;
    if (last == null ||
        _navigating != navigating ||
        _mode != camMode ||
        now.isBefore(last) ||
        now.difference(last) > _gap) {
      reset();
    }
    final dt = last == null || _rig == null
        ? 0.0
        : (now.difference(last).inMicroseconds / 1e6).clamp(0.0, 0.25);
    _last = now;
    _navigating = navigating;
    _mode = camMode;

    final onRoute = navigating && vehicle.onRoute;
    // Manuver yang baru dilepasi (untuk "pegang zum selepas belok"), sama seperti pemacu telefon.
    final lastNext = _lastNext;
    if (next != null && lastNext != null && next.index != lastNext.index) {
      // Indeks berundur = laluan baharu (kira semula): manuver lama tiada kaitan lagi.
      _passed = next.index > lastNext.index ? lastNext : null;
    }
    if (next != null) _lastNext = next;
    final passed = _passed;
    final distanceToNext = next != null && onRoute
        ? (next.startM - vehicle.alongM).clamp(0.0, double.infinity)
        : null;
    final followingGap = next != null && following != null && onRoute
        ? following.startM - next.startM
        : null;
    final sinceTurn = passed != null && onRoute
        ? vehicle.alongM - passed.startM
        : null;

    final previousBearing = _prevBearing;
    if (previousBearing != null && dt > 0) {
      final rate = (angleDelta(previousBearing, vehicle.bearing) / dt).clamp(
        -120.0,
        120.0,
      );
      _yawRate += (rate - _yawRate) * (1 - math.exp(-dt / 0.15));
    }
    _prevBearing = vehicle.bearing;

    final rig = _rig ??= () {
      final start = planCamera(
        CameraSituation(
          speedMps: vehicle.speedMps,
          distanceToNextM: distanceToNext,
          nextKind: onRoute ? next?.kind : null,
          mode: camMode,
          followingGapM: followingGap,
        ),
      );
      return CameraRig(
        entry: CameraPose(
          center: vehicle.point,
          zoom: start.zoom,
          tilt: start.tilt,
          bearing: vehicle.bearing,
        ),
        // Tiada peralihan masuk: skrin kereta tidak pernah menunjukkan pandangan lain dahulu.
        entryDuration: Duration.zero,
      );
    }();
    return rig.step(
      dt: dt,
      vehicle: vehicle.point,
      vehicleBearing: vehicle.bearing,
      speedMps: vehicle.speedMps,
      distanceToNextM: distanceToNext,
      nextKind: onRoute ? next?.kind : null,
      viewportHeightPx: viewportHeightPx,
      mode: camMode,
      // Pusat = kenderaan; ofset skrin dibuat oleh padding di hos kereta.
      screenOffset: 0,
      yawRateDeg: _yawRate.abs(),
      followingGapM: followingGap,
      sinceTurnM: sinceTurn,
      lastKind: onRoute ? passed?.kind : null,
    );
  }
}

/// Jarak ringkas untuk skrin kereta (tanpa l10n penuh).
String carFormatDistance(double meters) {
  if (meters < 995) {
    final m = ((meters / 10).round() * 10).clamp(10, 990);
    return '$m m';
  }
  final km = meters / 1000;
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
