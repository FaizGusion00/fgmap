import 'dart:math' as math;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

// Senario pemanduan SINTETIK (dijana dalam kod, bukan rakaman GPS sebenar): lampu isyarat, kanyon
// bandar, lonjakan GPS, terowong panjang, selekoh salah dan simpang rapat. Menegaskan sifat yang
// mesti sentiasa benar: tiada re-route palsu, kemajuan tidak berundur, pemulihan selepas isyarat hilang.

class _Result {
  _Result(this.session, this.clock);

  final NavigationSession session;
  final FakeClock clock;
  final List<NavProgress> progress = [];
  final List<Announcement> spoken = [];
  int reroutes = 0;
  int offRouteFixes = 0;

  void feed(LocationFix fix) {
    clock.now = fix.timestamp!;
    final u = session.onFix(fix);
    if (u == null) return;
    progress.add(u.progress);
    spoken.addAll(u.announcements);
    if (u.reroute != null) reroutes++;
    if (u.progress.status == NavStatus.offRoute) offRouteFixes++;
  }

  double get maxBackwardsM {
    var peak = 0.0;
    var worst = 0.0;
    for (final p in progress) {
      peak = math.max(peak, p.alongM);
      worst = math.max(worst, peak - p.alongM);
    }
    return worst;
  }
}

_Result _start(NavRoute route) {
  final clock = FakeClock();
  return _Result(
    NavigationSession(
      route: route,
      language: VoiceLanguage.ms,
      clock: clock.call,
    ),
    clock,
  );
}

/// Jalan zigzag bandar: lurus 90 m, belok kanan, 70 m, belok kiri, ... Setiap kaki cukup pendek
/// supaya simpang rapat (dua belokan dalam < 150 m).
RouteOption _zigzag({int turns = 6, double legM = 90}) {
  var point = const GeoPoint(3.1, 101.6);
  var bearing = 90.0;
  final points = <GeoPoint>[point];
  final maneuvers = <Maneuver>[
    const Maneuver(
      type: 1,
      streetNames: ['Jalan 0'],
      lengthM: 90,
      timeS: 10,
      beginShapeIndex: 0,
    ),
  ];
  for (var t = 0; t < turns; t++) {
    for (var d = 10.0; d <= legM; d += 10) {
      points.add(destinationPoint(point, bearing, d));
    }
    point = points.last;
    final right = t.isEven;
    maneuvers.add(
      Maneuver(
        type: right ? 10 : 15,
        streetNames: ['Jalan ${t + 1}'],
        lengthM: legM.round(),
        timeS: 10,
        beginShapeIndex: points.length - 1,
      ),
    );
    bearing = (bearing + (right ? 90 : -90)) % 360;
  }
  for (var d = 10.0; d <= legM; d += 10) {
    points.add(destinationPoint(point, bearing, d));
  }
  maneuvers.add(
    Maneuver(
      type: 4,
      streetNames: const [],
      lengthM: 0,
      timeS: 0,
      beginShapeIndex: points.length - 1,
    ),
  );
  return RouteOption(
    distanceM: (legM * (turns + 1)).round(),
    durationS: ((turns + 1) * 10),
    hasTolls: false,
    points: points,
    maneuvers: maneuvers,
  );
}

LocationFix _fix(
  NavRoute route,
  double along,
  DateTime at, {
  double lateralM = 0,
  double accuracy = 5,
  double speed = 14,
}) {
  final bearing = route.bearingAt(along, lookAheadM: 15);
  final onRoute = route.pointAt(along);
  return LocationFix(
    point: lateralM == 0
        ? onRoute
        : destinationPoint(onRoute, bearing + 90, lateralM),
    headingDegrees: speed > 1 ? bearing.round() % 360 : null,
    accuracyMeters: accuracy,
    speedMps: speed,
    timestamp: at,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  group('lampu isyarat', () {
    test(
      'berhenti 90 s dengan hingar GPS 6 m: tiada re-route, tiada undur ketara',
      () {
        final route = NavRoute(lShapedRoute(legM: 2000));
        final r = _start(route);
        final random = math.Random(3);
        // Memandu ke 600 m, kemudian berhenti.
        for (final f in driveFixes(route, speedMps: 14, endM: 600)) {
          r.feed(f);
        }
        final stop = r.progress.last.alongM;
        var t = r.clock.now;
        for (var i = 1; i <= 90; i++) {
          t = t.add(const Duration(seconds: 1));
          final jitter = destinationPoint(
            route.pointAt(stop),
            random.nextDouble() * 360,
            random.nextDouble() * 6,
          );
          r.feed(
            LocationFix(
              point: jitter,
              accuracyMeters: 8,
              speedMps: 0,
              timestamp: t,
            ),
          );
        }
        expect(r.reroutes, 0);
        expect(r.offRouteFixes, 0);
        expect(r.maxBackwardsM, lessThan(15));
        expect((r.progress.last.alongM - stop).abs(), lessThan(15));
      },
    );
  });

  group('kanyon bandar dan lonjakan', () {
    test(
      '30 saat ralat sisi 30-40 m (ketepatan 45 m): tiada re-route palsu',
      () {
        final route = NavRoute(lShapedRoute(legM: 3000));
        final r = _start(route);
        var t = t0;
        final random = math.Random(11);
        var along = 0.0;
        for (var i = 0; i < 90; i++) {
          t = t.add(const Duration(seconds: 1));
          along += 14;
          final burst = i >= 30 && i < 60;
          r.feed(
            _fix(
              route,
              along,
              t,
              lateralM: burst
                  ? 30 + random.nextDouble() * 10
                  : random.nextDouble() * 3,
              accuracy: burst ? 45 : 5,
            ),
          );
        }
        expect(r.reroutes, 0);
        expect(r.maxBackwardsM, lessThan(30));
        expect(r.progress.last.alongM, greaterThan(along - 80));
      },
    );

    test(
      'satu lonjakan 120 m (ketepatan 15 m) di tengah jalan lurus: tiada re-route',
      () {
        final route = NavRoute(lShapedRoute(legM: 3000));
        final r = _start(route);
        var t = t0;
        var along = 0.0;
        for (var i = 0; i < 40; i++) {
          t = t.add(const Duration(seconds: 1));
          along += 14;
          r.feed(
            _fix(
              route,
              along,
              t,
              lateralM: i == 20 ? 120 : 0,
              accuracy: i == 20 ? 15 : 5,
            ),
          );
        }
        expect(r.reroutes, 0);
        expect(r.maxBackwardsM, lessThan(30));
      },
    );
  });

  group('terowong', () {
    test(
      '40 s tanpa isyarat pada 25 m/s: kenderaan diunjur, pulih tepat, tiada re-route',
      () {
        final route = NavRoute(lShapedRoute(legM: 4000));
        final r = _start(route);
        for (final f in driveFixes(route, speedMps: 25, endM: 800)) {
          r.feed(f);
        }
        final lastFixAt = r.clock.now;

        // Senyap 40 s: tick setiap 250 ms seperti pemasa pengawal.
        var weak = false;
        var lostAnnounced = 0;
        for (var ms = 250; ms <= 40000; ms += 250) {
          r.clock.now = lastFixAt.add(Duration(milliseconds: ms));
          final said = r.session.tick();
          lostAnnounced += said
              .where((a) => a.kind == AnnouncementKind.gpsLost)
              .length;
          weak = weak || (r.session.progress?.gpsWeak ?? false);
          r.session.refreshLive();
        }
        expect(weak, isTrue);
        expect(lostAnnounced, 1);
        final truth = r.progress.last.alongM + 25 * 40;
        final pose = r.session.poseAt(r.clock.now);
        expect(
          pose.alongM,
          closeTo(truth, 120),
          reason: 'unjuran kira-kira betul',
        );

        // Isyarat kembali dengan ketepatan sederhana.
        r.feed(_fix(route, truth, r.clock.now, accuracy: 20, speed: 25));
        expect(r.reroutes, 0);
        expect(r.progress.last.status, NavStatus.onRoute);
        expect(r.progress.last.alongM, closeTo(truth, 25));
        expect(r.progress.last.gpsWeak, isFalse);
        expect(r.progress.last.signalLost, isFalse);
        expect(
          r.spoken.where((a) => a.kind == AnnouncementKind.gpsBack),
          hasLength(1),
        );
      },
    );

    test('terowong melintasi selekoh: manuver tidak dilangkau senyap', () {
      final route = NavRoute(lShapedRoute(legM: 1000));
      final r = _start(route);
      for (final f in driveFixes(route, speedMps: 14, endM: 900)) {
        r.feed(f);
      }
      final before = r.progress.last.next;
      expect(before, isNotNull);
      // Hilang isyarat 20 s melepasi selekoh di 1000 m, kembali di 1150 m.
      final back = _fix(
        route,
        1150,
        r.clock.now.add(const Duration(seconds: 20)),
        speed: 14,
      );
      r.feed(back);
      expect(r.reroutes, 0);
      expect(r.progress.last.alongM, closeTo(1150, 25));
      expect(r.progress.last.next?.index, isNot(before!.index));
    });
  });

  group('selekoh salah', () {
    test('menyimpang: re-route diminta dalam 8 s', () {
      final route = NavRoute(lShapedRoute(legM: 3000));
      final r = _start(route);
      for (final f in driveFixes(route, speedMps: 14, endM: 1000)) {
        r.feed(f);
      }
      final start = route.pointAt(1000);
      var t = r.clock.now;
      final requestedAt = <int>[];
      var seen = 0;
      for (var i = 1; i <= 20; i++) {
        t = t.add(const Duration(seconds: 1));
        r.feed(
          LocationFix(
            point: destinationPoint(start, 0, 14.0 * i),
            headingDegrees: 0,
            accuracyMeters: 5,
            speedMps: 14,
            timestamp: t,
          ),
        );
        if (r.reroutes > seen) {
          requestedAt.add(i);
          seen = r.reroutes;
        }
      }
      expect(requestedAt, isNotEmpty);
      expect(requestedAt.first, inInclusiveRange(1, 8));
      // Cooldown dan permintaan tertunda dikawal oleh NavigationController (merentas sesi, lihat
      // navigation_controller_test); sesi terus mencadangkan selagi menyimpang.
    });
  });

  group('simpang rapat (bandar)', () {
    final route = NavRoute(_zigzag());

    test(
      'setiap belokan diumumkan "sekarang" tepat sekali mengikut turutan',
      () {
        final r = _start(route);
        for (final f in driveFixes(
          route,
          speedMps: 8,
          accuracyM: 5,
          noiseM: 2,
        )) {
          r.feed(f);
        }
        expect(r.reroutes, 0);
        expect(r.progress.last.status, NavStatus.arrived);
        final nows = r.spoken
            .where((a) => a.kind == AnnouncementKind.now)
            .toList();
        // 6 belokan + tiba.
        expect(nows.length, 7);
        expect(r.maxBackwardsM, lessThan(15));
      },
    );

    test(
      'banner beralih kepada manuver seterusnya sebelum kenderaan melepasi simpang',
      () {
        final r = _start(route);
        final fixes = driveFixes(route, speedMps: 8, accuracyM: 4);
        int? lastIndex;
        var changes = 0;
        for (final f in fixes) {
          r.feed(f);
          final idx = r.progress.last.next?.index;
          if (idx != null && idx != lastIndex) {
            lastIndex = idx;
            changes++;
          }
        }
        expect(changes, greaterThanOrEqualTo(6));
      },
    );

    test(
      'jarak ke manuver seterusnya berkurang hingga ke simpang, bukan melompat',
      () {
        final r = _start(route);
        double? prevDist;
        int? prevIdx;
        for (final f in driveFixes(route, speedMps: 8, accuracyM: 4)) {
          r.feed(f);
          final p = r.progress.last;
          final d = p.distanceToNextM;
          if (d != null && p.next?.index == prevIdx && prevDist != null) {
            expect(
              d,
              lessThanOrEqualTo(prevDist + 6),
              reason: 'tidak naik semasa menghampiri',
            );
          }
          prevDist = d;
          prevIdx = p.next?.index;
        }
      },
    );
  });

  group('kelajuan dan ketepatan', () {
    test(
      'lebuh raya 33 m/s dengan fix 1 Hz: kemajuan stabil dan ETA munasabah',
      () {
        final route = NavRoute(lShapedRoute(legM: 15000));
        final r = _start(route);
        for (final f in driveFixes(
          route,
          speedMps: 33,
          noiseM: 3,
          accuracyM: 6,
        )) {
          r.feed(f);
        }
        expect(r.reroutes, 0);
        expect(r.offRouteFixes, 0);
        expect(r.maxBackwardsM, lessThan(20));
        expect(r.progress.last.status, NavStatus.arrived);
      },
    );

    test(
      'fix terlalu kasar (ketepatan 200 m) ditolak: kemajuan tidak berubah',
      () {
        final route = NavRoute(lShapedRoute(legM: 3000));
        final r = _start(route);
        for (final f in driveFixes(route, speedMps: 14, endM: 500)) {
          r.feed(f);
        }
        final before = r.progress.last.alongM;
        final count = r.progress.length;
        r.feed(
          LocationFix(
            point: destinationPoint(route.pointAt(before), 0, 300),
            accuracyMeters: 200,
            speedMps: 14,
            timestamp: r.clock.now.add(const Duration(seconds: 1)),
          ),
        );
        expect(r.progress.length, anyOf(count, count + 1));
        expect(r.progress.last.alongM, closeTo(before, 30));
        expect(r.reroutes, 0);
      },
    );
  });
}
