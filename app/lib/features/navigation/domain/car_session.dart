import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'camera_planner.dart';
import 'lane_plan.dart';
import 'speed_bubble_data.dart';

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

/// Gambar sesi untuk hos kereta. Laluan hanya ada semasa navigasi.
@immutable
class CarSessionSnapshot {
  const CarSessionSnapshot({
    required this.mode,
    this.pose,
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
  });

  final CarDriveMode mode;
  final CameraPose? pose;
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

  bool get hasRoute => mode == CarDriveMode.navigating && route.length >= 2;

  /// Satu isyarat pemanduan: kamera > cuaca > R&R.
  String? get driveAlert => cameraAlert ?? weatherAlert ?? alongCue;

  Map<String, Object?> toMap({
    bool includeRoute = true,
    bool includeStyle = true,
  }) {
    final pose = this.pose;
    final limit = speed.showLimit ? speed.limitKmh : null;
    return {
      'mode': mode.name,
      'following': following,
      'lat': pose?.center.lat,
      'lng': pose?.center.lng,
      'bearing': pose?.bearing,
      'zoom': pose?.zoom,
      'tilt': pose?.tilt,
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
    };
  }
}

/// Peta keadaan telefon kepada satu gambar sesi. Cruise tidak pernah membawa garisan laluan.
CarSessionSnapshot mapCarSession({
  required bool navigating,
  required bool cruising,
  CameraPose? pose,
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
      lanes: lanes,
      laneHint: laneHint,
    );
  }
  if (mode == CarDriveMode.cruise) {
    return CarSessionSnapshot(
      mode: mode,
      pose: pose,
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
  return CarSessionSnapshot(
    mode: CarDriveMode.browse,
    following: true,
    dark: dark,
    style: style,
    styleKey: styleKey,
    airAqi: airAqi,
    prayerLine: prayerLine,
  );
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
