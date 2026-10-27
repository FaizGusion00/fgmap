import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

void main() {
  group('NavigationSession: pemanduan penuh KLCC -> KLIA (laluan sebenar)', () {
    final route = loadFixtureNavRoute();

    test(
      'hingar GPS 4 m: kemajuan monoton, tidak pernah keluar laluan, tiba',
      () {
        final clock = FakeClock();
        final session = NavigationSession(
          route: route,
          language: VoiceLanguage.ms,
          clock: clock.call,
        );
        final fixes = driveFixes(route, speedMps: 22, noiseM: 4, accuracyM: 6);
        var prev = -1.0;
        NavProgress? last;
        var offRoute = 0;
        var reroutes = 0;
        final spoken = <Announcement>[];
        for (final fix in fixes) {
          clock.now = fix.timestamp!;
          final update = session.onFix(fix);
          if (update == null) continue;
          final p = update.progress;
          expect(p.alongM, greaterThanOrEqualTo(prev));
          prev = p.alongM;
          if (p.status == NavStatus.offRoute) offRoute++;
          if (update.reroute != null) reroutes++;
          spoken.addAll(update.announcements);
          last = p;
        }
        expect(offRoute, 0);
        expect(reroutes, 0);
        expect(last!.status, NavStatus.arrived);
        expect(last.remainingM, lessThan(60));

        // Setiap manuver bertindakan diumumkan "sekarang" tepat sekali (kecuali kemuncak: tiba).
        final actionable = route.maneuvers
            .where((m) => m.isActionable && m.kind != ManeuverKind.depart)
            .length;
        final nows = spoken.where((a) => a.kind == AnnouncementKind.now).length;
        expect(nows, actionable); // termasuk satu 'sampai' daripada sesi
        // Tidak pernah mengulang ayat far/near yang sama untuk satu manuver.
        final fars = spoken
            .where((a) => a.kind == AnnouncementKind.far)
            .map((a) => a.text);
        expect(fars.toSet().length, fars.length);
        expect(
          spoken.last.text,
          anyOf('Anda telah sampai.', contains('Destinasi anda')),
        );
      },
    );

    test('ETA awal hampir anggaran laluan dan berkurang secara monoton', () {
      final clock = FakeClock();
      final session = NavigationSession(
        route: route,
        language: VoiceLanguage.en,
        clock: clock.call,
      );
      final fixes = driveFixes(
        route,
        speedMps: 19.3,
        accuracyM: 5,
      ); // ~ purata laluan (67 km / 3477 s)
      final etas = <double>[];
      for (final fix in fixes) {
        clock.now = fix.timestamp!;
        final u = session.onFix(fix);
        if (u != null) etas.add(u.progress.remainingS);
      }
      expect(etas.first, closeTo(3477, 120));
      for (var i = 1; i < etas.length; i++) {
        // Boleh turun naik sedikit kerana faktor ETA, tetapi tidak melonjak.
        expect(etas[i], lessThan(etas[i - 1] + 25));
      }
      expect(etas.last, lessThan(60));
    });

    test('trafik perlahan: ETA dilaras ke atas melebihi anggaran laluan', () {
      final clock = FakeClock();
      final session = NavigationSession(
        route: route,
        language: VoiceLanguage.en,
        clock: clock.call,
      );
      // Separuh daripada kelajuan anggaran, 15 minit pertama.
      final fixes = driveFixes(route, speedMps: 9, endM: 9 * 900, accuracyM: 5);
      NavProgress? p;
      for (final fix in fixes) {
        clock.now = fix.timestamp!;
        p = session.onFix(fix)?.progress ?? p;
      }
      final planned = route.plannedRemainingTime(p!.alongM);
      expect(p.remainingS, greaterThan(planned * 1.2));
    });

    test('manuver seterusnya, jarak, dan nama jalan dilaporkan', () {
      final clock = FakeClock();
      final session = NavigationSession(
        route: route,
        language: VoiceLanguage.ms,
        clock: clock.call,
      );
      final fixes = driveFixes(route, speedMps: 10, endM: 200);
      NavProgress? p;
      for (final fix in fixes) {
        clock.now = fix.timestamp!;
        p = session.onFix(fix)!.progress;
      }
      expect(p!.next, isNotNull);
      expect(p.next!.index, 1);
      expect(
        p.distanceToNextM,
        closeTo(route.maneuvers[1].startM - p.alongM, 1),
      );
      expect(p.street, 'Lorong Kuda');
      expect(p.following, isNotNull);
    });
  });

  group('NavigationSession: menyimpang dan pemulihan', () {
    final route = NavRoute(lShapedRoute(legM: 3000));

    List<LocationFix> offRouteDrive({int fixes = 12, double speed = 14}) {
      final base = DateTime.utc(2026, 1, 1, 12, 5);
      final start = route.pointAt(1000);
      return [
        for (var i = 0; i < fixes; i++)
          LocationFix(
            // Memandu ke utara (tegak lurus dengan jalan ke timur) dari km 1.
            point: destinationPoint(start, 0, speed * i + 20),
            headingDegrees: 0,
            accuracyMeters: 5,
            speedMps: speed,
            timestamp: base.add(Duration(seconds: i)),
          ),
      ];
    }

    test('re-route diminta sekali dengan kedudukan dan arah semasa', () {
      final clock = FakeClock();
      final session = NavigationSession(
        route: route,
        language: VoiceLanguage.ms,
        clock: clock.call,
      );
      // 15 saat di atas laluan dahulu.
      for (final f in driveFixes(
        route,
        speedMps: 14,
        startM: 800,
        endM: 1000,
      )) {
        clock.now = f.timestamp!;
        session.onFix(f);
      }
      RerouteRequest? request;
      var firstRequestFix = -1;
      var i = 0;
      for (final f in offRouteDrive()) {
        clock.now = f.timestamp!;
        final u = session.onFix(f)!;
        if (u.reroute != null && request == null) {
          request = u.reroute;
          firstRequestFix = i;
          // Pengawal yang menyebut "mengira semula", bukan sesi (supaya tidak berulang).
          expect(
            u.announcements.where((a) => a.kind == AnnouncementKind.reroute),
            isEmpty,
          );
        }
        i++;
      }
      expect(request, isNotNull);
      expect(
        firstRequestFix,
        inInclusiveRange(1, 4),
        reason: 'sah dalam beberapa fix',
      );
      expect(request!.headingDegrees, 0);
      expect(request.speedMps, closeTo(14, 0.5));
      expect(session.awaitingReroute, isFalse);
      session.noteRerouteRequested();
      expect(session.awaitingReroute, isTrue);
      expect(session.progress!.status, NavStatus.offRoute);
    });

    test('kembali ke laluan sebelum disahkan: tiada re-route', () {
      final clock = FakeClock();
      final session = NavigationSession(
        route: route,
        language: VoiceLanguage.ms,
        clock: clock.call,
      );
      for (final f in driveFixes(
        route,
        speedMps: 14,
        startM: 800,
        endM: 1000,
      )) {
        clock.now = f.timestamp!;
        session.onFix(f);
      }
      final base = DateTime.utc(2026, 1, 1, 12, 5);
      final start = route.pointAt(1000);
      var requests = 0;
      // Dua fix di luar laluan (60 m) kemudian kembali.
      for (var i = 0; i < 8; i++) {
        final off = i == 2 || i == 3;
        final f = LocationFix(
          point: destinationPoint(
            route.pointAt(1000 + 14.0 * i),
            0,
            off ? 60 : 3,
          ),
          headingDegrees: 90,
          accuracyMeters: 5,
          speedMps: 14,
          timestamp: base.add(Duration(seconds: i)),
        );
        clock.now = f.timestamp!;
        if (session.onFix(f)?.reroute != null) requests++;
      }
      expect(requests, 0);
      expect(start, isNotNull);
    });

    test('fix ditolak (ketepatan teruk) tidak mengubah kemajuan', () {
      final clock = FakeClock();
      final session = NavigationSession(
        route: route,
        language: VoiceLanguage.ms,
        clock: clock.call,
      );
      final fixes = driveFixes(route, speedMps: 14, endM: 300);
      for (final f in fixes) {
        clock.now = f.timestamp!;
        session.onFix(f);
      }
      final before = session.progress!;
      final bad = LocationFix(
        point: destinationPoint(route.pointAt(300), 0, 500),
        accuracyMeters: 400,
        speedMps: 14,
        timestamp: fixes.last.timestamp!.add(const Duration(seconds: 1)),
      );
      clock.now = bad.timestamp!;
      expect(session.onFix(bad), isNull);
      expect(session.progress!.alongM, before.alongM);
    });
  });

  group('NavigationSession: isyarat GPS hilang (terowong)', () {
    final route = NavRoute(lShapedRoute(legM: 3000));

    test(
      'amaran selepas 6 s senyap, kenderaan terus bergerak, pulih bila fix kembali',
      () {
        final clock = FakeClock();
        final session = NavigationSession(
          route: route,
          language: VoiceLanguage.en,
          clock: clock.call,
        );
        final fixes = driveFixes(route, speedMps: 20, endM: 400);
        for (final f in fixes) {
          clock.now = f.timestamp!;
          session.onFix(f);
        }
        expect(session.tick(), isEmpty);
        clock.advance(const Duration(seconds: 3));
        expect(session.tick(), isEmpty);
        clock.advance(const Duration(seconds: 4));
        final lost = session.tick();
        expect(lost.single.kind, AnnouncementKind.gpsLost);
        expect(session.progress!.gpsWeak, isTrue);
        // Hanya sekali.
        clock.advance(const Duration(seconds: 5));
        expect(session.tick(), isEmpty);

        // Kenderaan diunjur sepanjang laluan semasa senyap.
        final pose = session.poseAt(clock.now);
        expect(pose.alongM, greaterThan(session.progress!.alongM + 100));

        // Fix kembali pada 600 m (selepas terowong).
        final back = LocationFix(
          point: route.pointAt(600),
          headingDegrees: 90,
          accuracyMeters: 8,
          speedMps: 20,
          timestamp: fixes.last.timestamp!.add(const Duration(seconds: 15)),
        );
        clock.now = back.timestamp!;
        final u = session.onFix(back)!;
        expect(u.progress.alongM, closeTo(600, 5));
        expect(
          u.announcements.any((a) => a.kind == AnnouncementKind.gpsBack),
          isTrue,
        );
      },
    );
  });

  group('NavigationSession: permulaan', () {
    test('pengumuman pembukaan sekali sahaja; berbeza untuk re-route', () {
      final route = NavRoute(lShapedRoute());
      final s = NavigationSession(route: route, language: VoiceLanguage.ms);
      expect(s.takeStartAnnouncements().single.kind, AnnouncementKind.start);
      expect(s.takeStartAnnouncements(), isEmpty);
      final r = NavigationSession(
        route: route,
        language: VoiceLanguage.ms,
        isReroute: true,
      );
      expect(r.takeStartAnnouncements().single.kind, AnnouncementKind.newRoute);
    });

    test(
      'memulakan navigasi di tengah laluan (cth. re-route berhampiran): tiada pengumuman lapuk',
      () {
        final route = NavRoute(lShapedRoute(legM: 3000));
        final clock = FakeClock();
        final s = NavigationSession(
          route: route,
          language: VoiceLanguage.ms,
          clock: clock.call,
        );
        final out = <Announcement>[];
        for (final f in driveFixes(
          route,
          speedMps: 14,
          startM: 2750,
          endM: 3000,
        )) {
          clock.now = f.timestamp!;
          out.addAll(s.onFix(f)!.announcements);
        }
        // Sudah dalam jarak "near"; tiada "far".
        expect(out.where((a) => a.kind == AnnouncementKind.far), isEmpty);
        expect(out.first.kind, AnnouncementKind.near);
      },
    );
  });
}
