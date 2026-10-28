import 'dart:io';
import 'dart:math' as math;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:fgmap/features/speed_limits/domain/speed_limits.dart';
import 'package:fgmap/features/navigation/data/voice_guide.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/route_preview/data/valhalla_codec.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';

/// Laluan sebenar KLCC -> KLIA (Valhalla 3.5.1) dengan 31 manuver.
RouteOption loadFixtureRoute() {
  final body = File('test/fixtures/valhalla_klcc_klia.json').readAsStringSync();
  return parseRouteResponse(body, source: RouteSource.online).first;
}

NavRoute loadFixtureNavRoute() => NavRoute(loadFixtureRoute());

/// Jalan lurus ke timur sepanjang [lengthM] meter, dengan satu belok kanan di tengah ke selatan.
/// Digunakan untuk ujian yang perlu geometri yang diketahui tepat.
RouteOption lShapedRoute({double legM = 1000}) {
  const origin = GeoPoint(3.0, 101.0);
  final corner = destinationPoint(origin, 90, legM);
  final end = destinationPoint(corner, 180, legM);
  final points = <GeoPoint>[
    for (var d = 0.0; d < legM; d += 50) destinationPoint(origin, 90, d),
    corner,
    for (var d = 50.0; d < legM; d += 50) destinationPoint(corner, 180, d),
    end,
  ];
  final cornerIndex = (legM / 50).ceil();
  return RouteOption(
    distanceM: (legM * 2).round(),
    durationS: (legM * 2 / 13.9).round(),
    hasTolls: false,
    points: points,
    maneuvers: [
      const Maneuver(
        type: 1,
        streetNames: ['Jalan Satu'],
        lengthM: 1000,
        timeS: 72,
        beginShapeIndex: 0,
      ),
      Maneuver(
        type: 10,
        streetNames: const ['Jalan Dua'],
        lengthM: 1000,
        timeS: 72,
        beginShapeIndex: cornerIndex,
      ),
      Maneuver(
        type: 4,
        streetNames: const [],
        lengthM: 0,
        timeS: 0,
        beginShapeIndex: points.length - 1,
      ),
    ],
  );
}

/// Menjana fix GPS memandu sepanjang [route] pada [speedMps], satu sesaat sekali, bermula pada [from].
/// [noiseM] menambah hingar sisi (taburan normal); [accuracyM] dilaporkan oleh "peranti".
List<LocationFix> driveFixes(
  NavRoute route, {
  double speedMps = 13.9,
  double startM = 0,
  double? endM,
  double noiseM = 0,
  double accuracyM = 5,
  int seed = 7,
  DateTime? from,
}) {
  final random = math.Random(seed);
  final t0 = from ?? DateTime.utc(2026, 1, 1, 12);
  final end = endM ?? route.totalM;
  final fixes = <LocationFix>[];
  var along = startM;
  var i = 0;
  while (along <= end) {
    final bearing = route.bearingAt(along, lookAheadM: 15);
    var point = route.pointAt(along);
    if (noiseM > 0) {
      final lateral = _gauss(random) * noiseM;
      final forward = _gauss(random) * noiseM;
      point = destinationPoint(point, bearing + 90, lateral);
      point = destinationPoint(point, bearing, forward);
    }
    fixes.add(
      LocationFix(
        point: point,
        headingDegrees: speedMps > 1 ? bearing.round() % 360 : null,
        accuracyMeters: accuracyM,
        speedMps: speedMps,
        timestamp: t0.add(Duration(seconds: i)),
      ),
    );
    along += speedMps;
    i++;
  }
  return fixes;
}

double _gauss(math.Random r) {
  final u1 = 1 - r.nextDouble();
  final u2 = r.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

/// Jam palsu yang boleh dimajukan.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 1, 1, 12);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

class FakeVoice implements VoiceGuide {
  final List<(Announcement, VoiceLanguage)> said = [];
  int stops = 0;

  /// Simulasi enjin suara yang baling ralat apabila dihentikan.
  bool failStop = false;

  @override
  Future<void> announce(Announcement a, VoiceLanguage language) async =>
      said.add((a, language));

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('tts');
  }

  @override
  Future<void> dispose() async {}
}

class FakeAwake implements ScreenAwake {
  bool enabled = false;
  int enableCalls = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enableCalls++;
  }

  @override
  Future<void> disable() async => enabled = false;
}

/// Perkhidmatan had laju palsu: tiada rangkaian; memulangkan [limits] (atau kosong).
class FakeSpeedLimitService implements SpeedLimitService {
  FakeSpeedLimitService([this.limits = SpeedLimits.empty]);

  SpeedLimits limits;
  int calls = 0;

  @override
  Future<SpeedLimits> forRoute(RouteOption route, RouteVehicle vehicle) async {
    calls++;
    return limits;
  }

  int traceCalls = 0;

  @override
  Future<int?> limitForTrace(
    List<GeoPoint> points,
    RouteVehicle vehicle,
  ) async {
    traceCalls++;
    if (points.length < 2) return null;
    return limits.atDistance(double.infinity);
  }
}

/// Had laju seragam [kmh] sepanjang [lengthM] meter.
SpeedLimits uniformLimit(int kmh, double lengthM) => SpeedLimits([
  SpeedLimitSegment(
    beginShapeIndex: 0,
    endShapeIndex: 1000,
    lengthM: lengthM,
    limitKmh: kmh,
  ),
]);
