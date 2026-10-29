import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../domain/nav_route.dart';

/// Sumber fix lokasi untuk satu sesi navigasi: GPS sebenar, simulasi laluan, atau main semula GPX.
abstract interface class NavLocationSource {
  Stream<LocationFix> fixes();

  /// Benar jika kedudukan dipalsukan (paparan "Simulasi" dan tiada pembaziran bateri GPS).
  bool get isSimulated;
}

/// GPS sebenar peranti.
class DeviceLocationSource implements NavLocationSource {
  DeviceLocationSource(this._service);

  final LocationService _service;

  @override
  Stream<LocationFix> fixes() => _service.navigationFixes();

  @override
  bool get isSimulated => false;
}

typedef Sleep = Future<void> Function(Duration duration);

/// Memainkan semula senarai fix mengikut jarak masanya (Bahagian 8.4 pelan: GPX replayer).
///
/// Cap masa fix ditulis semula kepada masa dinding supaya enjin navigasi melihatnya seperti GPS
/// langsung. [speedMultiplier] > 1 memampatkan masa; kelajuan yang dilaporkan dikalikan sama.
/// Boleh diubah semasa main (cth. 1x → 4x) melalui [speedMultiplier].
class ReplayLocationSource implements NavLocationSource {
  ReplayLocationSource(
    this.recorded, {
    double speedMultiplier = 1,
    Sleep? sleep,
    DateTime Function()? clock,
  }) : speedMultiplier = ValueNotifier(speedMultiplier.clamp(0.25, 8.0)),
       _sleep = sleep ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  final List<LocationFix> recorded;
  final ValueNotifier<double> speedMultiplier;
  final Sleep _sleep;
  final DateTime Function() _clock;

  @override
  bool get isSimulated => true;

  void dispose() => speedMultiplier.dispose();

  @override
  Stream<LocationFix> fixes() async* {
    if (recorded.isEmpty) return;
    DateTime? previous;
    for (final fix in recorded) {
      final t = fix.timestamp;
      if (previous != null && t != null) {
        final gap = t.difference(previous);
        if (gap > Duration.zero) {
          final mult = speedMultiplier.value.clamp(0.25, 8.0);
          await _sleep(
            Duration(microseconds: (gap.inMicroseconds / mult).round()),
          );
        }
      }
      previous = t ?? previous;
      final mult = speedMultiplier.value.clamp(0.25, 8.0);
      yield LocationFix(
        point: fix.point,
        headingDegrees: fix.headingDegrees,
        accuracyMeters: fix.accuracyMeters,
        speedMps: fix.speedMps == null ? null : fix.speedMps! * mult,
        timestamp: _clock(),
      );
    }
  }
}

/// Menjana pemanduan sintetik sepanjang [route] untuk simulasi dalam app dan ujian.
///
/// Kelajuan mengikut kelajuan anggaran setiap segmen (jalan raya perlahan, lebuh raya laju),
/// memperlahan menghampiri manuver bertindakan, dan melahu pada destinasi.
///
/// Jika [cruiseSpeedMps] diberi, guna itu sebagai kelajuan jelajah (masih memperlahan di
/// selekoh/destinasi) — untuk UI "Simulasi" yang boleh dikawal (bukan terperangkap ~18 km/j).
List<LocationFix> simulateDrive(
  NavRoute route, {
  double startM = 0,
  DateTime? from,
  double accuracyM = 5,
  double maxSpeedMps = 33,
  double? cruiseSpeedMps,
}) {
  final t0 = from ?? DateTime.utc(2026);
  final fixes = <LocationFix>[];
  var along = startM;
  var speed = 0.0;
  var i = 0;
  final customCruise = cruiseSpeedMps?.clamp(2.0, maxSpeedMps);
  while (along < route.totalM) {
    final segment = route.maneuverAt(along);
    final cruise =
        customCruise ??
        (segment == null || segment.timeS <= 0 || segment.lengthM <= 0
            ? 13.0
            : (segment.lengthM / segment.timeS).clamp(5.0, maxSpeedMps));
    final next = route.nextActionable(along);
    final toTurn = next == null ? double.infinity : next.startM - along;
    // Perlahan untuk selekoh: had kelajuan berkadar dengan jarak ke manuver.
    var target = math.min(cruise, math.max(cruise * 0.35, 5) + toTurn * 0.25);
    final toEnd = route.totalM - along;
    target = math.min(target, math.max(cruise * 0.25, 3) + toEnd * 0.25);
    // Pecutan/nyahpecutan realistik (~2.5 m/s setiap saat).
    final accel = customCruise == null ? 2.5 : math.max(2.5, customCruise / 6);
    final brake = customCruise == null ? 4.0 : math.max(4.0, customCruise / 4);
    speed = speed < target
        ? math.min(target, speed + accel)
        : math.max(target, speed - brake);
    final bearing = route.bearingAt(along, lookAheadM: 15);
    fixes.add(
      LocationFix(
        point: route.pointAt(along),
        headingDegrees: speed > 1 ? bearing.round() % 360 : null,
        accuracyMeters: accuracyM,
        speedMps: speed,
        timestamp: t0.add(Duration(seconds: i)),
      ),
    );
    along += math.max(speed, 0.5);
    i++;
  }
  fixes.add(
    LocationFix(
      point: route.pointAt(route.totalM),
      headingDegrees: null,
      accuracyMeters: accuracyM,
      speedMps: 0,
      timestamp: t0.add(Duration(seconds: i)),
    ),
  );
  return fixes;
}

/// Simulasi pemanduan pada [route].
///
/// [cruiseSpeedMps] — kelajuan jelajah tetap (null = ikut anggaran segmen Valhalla).
/// [speedMultiplier] — mempercepat masa dinding + skala kelajuan dilaporkan (boleh diubah live).
ReplayLocationSource routeSimulation(
  NavRoute route, {
  double speedMultiplier = 1,
  double? cruiseSpeedMps,
  double startM = 0,
  Sleep? sleep,
  DateTime Function()? clock,
}) => ReplayLocationSource(
  simulateDrive(route, startM: startM, cruiseSpeedMps: cruiseSpeedMps),
  speedMultiplier: speedMultiplier,
  sleep: sleep,
  clock: clock,
);
