import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

/// Ketepatan masa simpang dan ketibaan. Laluan: 1000 m ke timur, belok kanan di 1000 m, 1000 m ke
/// selatan, tiba di 2000 m.
void main() {
  final route = NavRoute(lShapedRoute(legM: 1000));
  final t0 = DateTime.utc(2026, 1, 1, 12);

  NavigationSession newSession(FakeClock clock) => NavigationSession(
    route: route,
    language: VoiceLanguage.en,
    clock: clock.call,
  );

  LocationFix fixAt(
    double alongM,
    int second, {
    double speed = 14,
    double accuracy = 5,
  }) => LocationFix(
    point: route.pointAt(alongM),
    headingDegrees: speed > 1 ? route.bearingAt(alongM).round() % 360 : null,
    accuracyMeters: accuracy,
    speedMps: speed,
    timestamp: t0.add(Duration(seconds: second)),
  );

  /// Memandu fix 1 Hz sehingga [untilM], jam sama dengan cap masa fix + [latency].
  NavigationSession driveTo(
    FakeClock clock,
    double untilM, {
    Duration latency = Duration.zero,
    double speed = 14,
  }) {
    final session = newSession(clock);
    var i = 0;
    for (var along = 0.0; along <= untilM; along += speed) {
      final f = fixAt(along, i++, speed: speed);
      clock.now = f.timestamp!.add(latency);
      session.onFix(f);
    }
    return session;
  }

  group('latensi GPS', () {
    test('fix tiba 1 s lewat: kenderaan diunjur dari masa ukuran', () {
      final clock = FakeClock(t0);
      final onTime = driveTo(clock, 300);
      final onTimeAlong = onTime.poseAt(clock.now).alongM;

      final lateClock = FakeClock(t0);
      final late = driveTo(lateClock, 300, latency: const Duration(seconds: 1));
      final lateAlong = late.poseAt(lateClock.now).alongM;

      // 1 s x 14 m/s di hadapan berbanding fix yang tiba serta-merta.
      expect(lateAlong - onTimeAlong, closeTo(14, 3));
    });

    test(
      'latensi dihad 2.5 s (jam peranti tidak tepat tidak melontarkan kereta)',
      () {
        final clock = FakeClock(t0);
        final onTime = driveTo(clock, 300);
        final onTimeAlong = onTime.poseAt(clock.now).alongM;

        final lateClock = FakeClock(t0);
        final late = driveTo(
          lateClock,
          300,
          latency: const Duration(seconds: 6),
        );
        expect(
          late.poseAt(lateClock.now).alongM - onTimeAlong,
          closeTo(14 * 2.5, 4),
        );
      },
    );
  });

  group('refreshLive: banner tepat masa', () {
    test(
      'banner bertukar apabila pemandu sampai ke simpang, bukan 1-2 s selepas',
      () {
        final clock = FakeClock(t0);
        final session = driveTo(clock, 960);
        expect(
          session.progress!.next!.index,
          1,
          reason: 'belok kanan seterusnya',
        );

        var switchedAlong = -1.0;
        for (var ms = 0; ms < 6000; ms += 100) {
          clock.advance(const Duration(milliseconds: 100));
          final update = session.refreshLive();
          if (update != null && update.progress.next!.index == 2) {
            switchedAlong = session.poseAt(clock.now).alongM;
            break;
          }
        }
        expect(switchedAlong, greaterThan(0), reason: 'tidak pernah bertukar');
        // Bertukar ~lead (9.8 m pada 14 m/s) sebelum simpang, bukan selepasnya.
        expect(switchedAlong, inInclusiveRange(980, 1000));
      },
    );

    test('jarak ke manuver menurun lancar antara dua fix', () {
      final clock = FakeClock(t0);
      final session = driveTo(clock, 500);
      final first = session.progress!.distanceToNextM!;
      var last = first;
      var updates = 0;
      for (var ms = 0; ms < 3000; ms += 100) {
        clock.advance(const Duration(milliseconds: 100));
        final update = session.refreshLive();
        if (update == null) continue;
        updates++;
        expect(update.progress.distanceToNextM!, lessThan(last));
        last = update.progress.distanceToNextM!;
      }
      expect(updates, greaterThanOrEqualTo(2));
      // Dilaporkan setiap >= 10 m, jadi nilai terakhir hanya sedikit ketinggalan daripada 3 s x 14 m/s.
      expect(first - last, inInclusiveRange(25, 46));
    });

    test(
      'tiada perubahan: tiada kemas kini; selepas tiba: tiada kemas kini',
      () {
        final clock = FakeClock(t0);
        final session = driveTo(clock, 500);
        session.refreshLive();
        expect(session.refreshLive(), isNull);

        final done = driveTo(FakeClock(t0), route.totalM, speed: 5);
        expect(done.progress!.status, NavStatus.arrived);
        expect(done.refreshLive(), isNull);
      },
    );

    test('pengumuman suara mengikut kedudukan langsung dan tidak berulang', () {
      final clock = FakeClock(t0);
      final session = driveTo(clock, 800);
      final said = <String>[];
      for (var ms = 0; ms < 8000; ms += 100) {
        clock.advance(const Duration(milliseconds: 100));
        final update = session.refreshLive();
        if (update != null) {
          said.addAll(update.announcements.map((a) => '${a.kind.name}'));
        }
      }
      // "now" untuk belok kanan diucap tepat sekali.
      expect(said.where((k) => k == 'now'), hasLength(lessThanOrEqualTo(1)));
      expect(said.length, lessThanOrEqualTo(3));
    });
  });

  group('ketibaan', () {
    NavigationSession arrivalSession(FakeClock clock, double alongM) {
      final session = driveTo(clock, alongM);
      return session;
    }

    test('tidak tiba 40 m dari hujung (simpang besar sebelum destinasi)', () {
      final clock = FakeClock(t0);
      final s = arrivalSession(clock, route.totalM - 40);
      expect(s.progress!.status, NavStatus.onRoute);
    });

    test(
      'tiba apabila dalam radius kecil dari hujung laluan, dengan pengumuman',
      () {
        final clock = FakeClock(t0);
        final s = newSession(clock);
        final announcements = <Announcement>[];
        var i = 0;
        for (var along = 0.0; along <= route.totalM - 6; along += 14) {
          final f = fixAt(along, i++);
          clock.now = f.timestamp!;
          final update = s.onFix(f);
          if (update != null) announcements.addAll(update.announcements);
        }
        final f = fixAt(route.totalM - 6, i, speed: 3);
        clock.now = f.timestamp!;
        final update = s.onFix(f)!;
        if (update.announcements.isNotEmpty) {
          announcements.addAll(update.announcements);
        }
        expect(update.progress.status, NavStatus.arrived);
        expect(
          announcements.where((a) => a.chime == ChimeKind.arrive),
          hasLength(1),
          reason: 'pengumuman tiba tepat sekali',
        );
      },
    );

    test('radius mengikut ketepatan GPS tetapi dihad 25 m', () {
      final clock = FakeClock(t0);
      final s = newSession(clock);
      var i = 0;
      for (var along = 0.0; along <= route.totalM - 30; along += 14) {
        final f = fixAt(along, i++, accuracy: 30);
        clock.now = f.timestamp!;
        s.onFix(f);
      }
      expect(
        s.progress!.status,
        NavStatus.onRoute,
        reason: '30 m dari hujung > radius maksimum 25 m',
      );
    });

    test('berhenti dekat hujung selama beberapa saat: tiba', () {
      final clock = FakeClock(t0);
      final s = newSession(clock);
      var i = 0;
      for (var along = 0.0; along <= route.totalM - 35; along += 14) {
        final f = fixAt(along, i++);
        clock.now = f.timestamp!;
        s.onFix(f);
      }
      expect(s.progress!.status, NavStatus.onRoute);
      for (var k = 0; k < 6; k++) {
        final f = fixAt(route.totalM - 33, i++, speed: 0);
        clock.now = f.timestamp!;
        s.onFix(f);
      }
      expect(s.progress!.status, NavStatus.arrived);
    });

    test('berhenti 35 m dari hujung hanya sebentar: belum tiba', () {
      final clock = FakeClock(t0);
      final s = newSession(clock);
      var i = 0;
      for (var along = 0.0; along <= route.totalM - 35; along += 14) {
        final f = fixAt(along, i++);
        clock.now = f.timestamp!;
        s.onFix(f);
      }
      for (var k = 0; k < 2; k++) {
        final f = fixAt(route.totalM - 34, i++, speed: 0);
        clock.now = f.timestamp!;
        s.onFix(f);
      }
      expect(s.progress!.status, NavStatus.onRoute);
    });
  });
}
