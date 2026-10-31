import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'camera_planner.dart';
import 'speed_bubble_data.dart';

/// Mod yang dikongsi telefon dan Android Auto. Hanya satu yang memiliki kamera.
enum CarDriveMode { browse, cruise, navigating }

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
    );
  }
  return CarSessionSnapshot(
    mode: CarDriveMode.browse,
    following: true,
    dark: dark,
    style: style,
    styleKey: styleKey,
    airAqi: airAqi,
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
