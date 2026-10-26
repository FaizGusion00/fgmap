import 'dart:async';
import 'dart:math' as math;

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
class ReplayLocationSource implements NavLocationSource {
  ReplayLocationSource(
    this.recorded, {
    this.speedMultiplier = 1,
    Sleep? sleep,
    DateTime Function()? clock,
  }) : _sleep = sleep ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  final List<LocationFix> recorded;
  final double speedMultiplier;
  final Sleep _sleep;
  final DateTime Function() _clock;

  @override
  bool get isSimulated => true;

  @override
  Stream<LocationFix> fixes() async* {
    if (recorded.isEmpty) return;
    DateTime? previous;
    for (final fix in recorded) {
      final t = fix.timestamp;
      if (previous != null && t != null) {
        final gap = t.difference(previous);
        if (gap > Duration.zero) {
          await _sleep(
            Duration(
              microseconds: (gap.inMicroseconds / speedMultiplier).round(),
            ),
          );
        }
      }
      previous = t ?? previous;
      yield LocationFix(
        point: fix.point,
        headingDegrees: fix.headingDegrees,
        accuracyMeters: fix.accuracyMeters,
        speedMps: fix.speedMps == null ? null : fix.speedMps! * speedMultiplier,
        timestamp: _clock(),
      );
    }
  }
}

/// Menjana pemanduan sintetik sepanjang [route] untuk simulasi dalam app dan ujian.
///
/// Kelajuan mengikut kelajuan anggaran setiap segmen (jalan raya perlahan, lebuh raya laju),
/// memperlahan menghampiri manuver bertindakan, dan melahu pada destinasi.
List<LocationFix> simulateDrive(
  NavRoute route, {
  double startM = 0,
  DateTime? from,
  double accuracyM = 5,
  double maxSpeedMps = 33,
}) {
  final t0 = from ?? DateTime.utc(2026);
  final fixes = <LocationFix>[];
  var along = startM;
  var speed = 0.0;
  var i = 0;
  while (along < route.totalM) {
    final segment = route.maneuverAt(along);
    final cruise = segment == null || segment.timeS <= 0 || segment.lengthM <= 0
        ? 13.0
        : (segment.lengthM / segment.timeS).clamp(5.0, maxSpeedMps);
    final next = route.nextActionable(along);
    final toTurn = next == null ? double.infinity : next.startM - along;
    // Perlahan untuk selekoh: had kelajuan berkadar dengan jarak ke manuver.
    var target = math.min(cruise, 5 + toTurn * 0.25);
    final toEnd = route.totalM - along;
    target = math.min(target, 3 + toEnd * 0.25);
    // Pecutan/nyahpecutan realistik (~2.5 m/s setiap saat).
    speed = speed < target
        ? math.min(target, speed + 2.5)
        : math.max(target, speed - 4);
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

/// Simulasi pemanduan pada [route] dengan pengganda kelajuan [speedMultiplier].
NavLocationSource routeSimulation(
  NavRoute route, {
  double speedMultiplier = 1,
  double startM = 0,
  Sleep? sleep,
}) => ReplayLocationSource(
  simulateDrive(route, startM: startM),
  speedMultiplier: speedMultiplier,
  sleep: sleep,
);
