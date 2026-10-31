import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

NavManeuver m(
  ManeuverKind kind, {
  List<String> streets = const [],
  int? exit,
}) => NavManeuver(
  index: 1,
  kind: kind,
  startM: 0,
  lengthM: 0,
  timeS: 0,
  streetNames: streets,
  roundaboutExit: exit,
);

void main() {
  group('maneuverKindFromValhalla', () {
    test('memetakan jenis lazim', () {
      expect(maneuverKindFromValhalla(10), ManeuverKind.right);
      expect(maneuverKindFromValhalla(15), ManeuverKind.left);
      expect(maneuverKindFromValhalla(26), ManeuverKind.roundabout);
      expect(maneuverKindFromValhalla(27), ManeuverKind.none);
      expect(maneuverKindFromValhalla(8), ManeuverKind.none);
      expect(maneuverKindFromValhalla(6), ManeuverKind.arriveLeft);
      expect(maneuverKindFromValhalla(12), ManeuverKind.uTurn);
      expect(maneuverKindFromValhalla(13), ManeuverKind.uTurn);
      expect(maneuverKindFromValhalla(99), ManeuverKind.none);
    });
  });

  group('InstructionText', () {
    const ms = InstructionText(VoiceLanguage.ms);
    const en = InstructionText(VoiceLanguage.en);

    test(
      'setiap jenis manuver ada ayat tidak kosong dalam kedua-dua bahasa',
      () {
        for (final kind in ManeuverKind.values) {
          expect(ms.action(m(kind)), isNotEmpty, reason: '$kind ms');
          expect(en.action(m(kind)), isNotEmpty, reason: '$kind en');
        }
      },
    );

    test('ayat dengan jarak dan jalan', () {
      final right = m(ManeuverKind.right, streets: ['Jalan Ampang']);
      expect(
        ms.spoken(right, distanceM: 500),
        'Dalam 500 meter, belok kanan ke Jalan Ampang.',
      );
      expect(
        en.spoken(right, distanceM: 500),
        'In 500 meters, turn right onto Jalan Ampang.',
      );
      expect(ms.spoken(right), 'Belok kanan ke Jalan Ampang.');
    });

    test('bulatan menyebut nombor simpang keluar', () {
      final r = m(ManeuverKind.roundabout, exit: 2);
      expect(
        ms.spoken(r, distanceM: 300),
        'Dalam 300 meter, di bulatan, ambil simpang keluar ke-2.',
      );
      expect(en.spoken(r), 'At the roundabout, take the second exit.');
      // Kad: pendek, ikon sudah menunjukkan bulatan.
      expect(ms.cardAction(r), 'Ambil simpang keluar ke-2');
      expect(en.cardAction(r), 'Take the 2nd exit');
      expect(ms.cardAction(m(ManeuverKind.roundabout)), 'Masuk bulatan');
      expect(en.cardAction(m(ManeuverKind.left)), 'Turn left');
    });

    test('ordinal Inggeris: 1st, 2nd, 3rd, 11th-13th, 21st', () {
      expect(
        [1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 101, 111]
            .map(InstructionText.ordinalNumber)
            .toList(),
        [
          '1st', '2nd', '3rd', '4th', '11th', '12th', '13th',
          '21st', '22nd', '23rd', '101st', '111th',
        ],
      );
      // Sebutan: dieja hingga enam, angka selepas itu (bukan "21th").
      final r21 = m(ManeuverKind.roundabout, exit: 21);
      expect(en.spoken(r21), 'At the roundabout, take the 21st exit.');
    });

    test('klausa kemudian', () {
      final a = m(ManeuverKind.left);
      final b = m(ManeuverKind.right);
      expect(ms.spoken(a, then: b), 'Belok kiri, kemudian belok kanan.');
      expect(
        en.spoken(a, distanceM: 200, then: b),
        'In 200 meters, turn left, then turn right.',
      );
    });

    test('bundaran jarak sebutan', () {
      expect(ms.distance(12), '50 meter');
      expect(ms.distance(120), '100 meter');
      expect(ms.distance(310), '300 meter');
      expect(ms.distance(480), '500 meter');
      expect(ms.distance(940), '900 meter');
      expect(ms.distance(960), '1 kilometer');
      expect(ms.distance(1480), '1.5 kilometer');
      expect(ms.distance(2300), '2.5 kilometer');
      expect(ms.distance(5200), '5 kilometer');
      expect(en.distance(1000), '1 kilometer');
      expect(en.distance(2000), '2 kilometers');
    });

    test('tiba: tiada klausa jarak yang janggal', () {
      expect(ms.spoken(m(ManeuverKind.arrive)), 'Anda telah sampai.');
      expect(
        en.spoken(m(ManeuverKind.arriveRight)),
        'Your destination is on the right.',
      );
    });

    test('ikut jalan sejauh', () {
      expect(
        ms.keepGoing('Lebuhraya Utara-Selatan', 11300),
        'Ikut Lebuhraya Utara-Selatan sejauh 11 kilometer.',
      );
      expect(en.keepGoing(null, 5000), 'Continue for 5 kilometers.');
    });
  });

  group('stageDistancesFor', () {
    test('lebuh raya mendapat amaran lebih awal daripada bandar', () {
      final city = stageDistancesFor(13.9);
      final highway = stageDistancesFor(27.8);
      expect(highway.far, greaterThan(city.far));
      expect(highway.near, greaterThan(city.near));
      expect(highway.now, greaterThan(city.now));
      expect(city.far, closeTo(765, 5));
      expect(highway.far, closeTo(1529, 5));
    });

    test('trafik perlahan tidak menjadikan arahan terlalu lewat', () {
      final crawl = stageDistancesFor(0.5);
      final slow = stageDistancesFor(6);
      expect(crawl.near, slow.near);
      expect(crawl.near, greaterThanOrEqualTo(150));
    });
  });

  group('AnnouncementPlanner', () {
    final route = NavRoute(lShapedRoute(legM: 3000));
    AnnouncementPlanner planner([NavRoute? r]) => AnnouncementPlanner(
      route: r ?? route,
      text: const InstructionText(VoiceLanguage.ms),
    );

    List<Announcement> drive(
      AnnouncementPlanner p,
      double speed, {
      double from = 0,
      double to = 3000,
    }) {
      final out = <Announcement>[];
      for (var along = from; along <= to; along += speed) {
        out.addAll(p.update(alongM: along, speedMps: speed));
      }
      return out;
    }

    test('far, near, now berturutan; tepat sekali setiap satu', () {
      final out = drive(planner(), 13.9);
      final kinds = out
          .where((a) => a.kind != AnnouncementKind.keepGoing)
          .map((a) => a.kind)
          .toList();
      expect(kinds.take(3), [
        AnnouncementKind.far,
        AnnouncementKind.near,
        AnnouncementKind.now,
      ]);
      expect(kinds.where((k) => k == AnnouncementKind.far).length, 1);
      expect(kinds.where((k) => k == AnnouncementKind.near).length, 1);
    });

    test('far menyebut jarak, now tidak, dan now memotong ucapan semasa', () {
      final out = drive(planner(), 13.9);
      final far = out.firstWhere((a) => a.kind == AnnouncementKind.far);
      final now = out.firstWhere((a) => a.kind == AnnouncementKind.now);
      expect(far.text, startsWith('Dalam '));
      expect(far.text, contains('belok kanan'));
      expect(now.text, isNot(contains('Dalam')));
      expect(now.interrupt, isTrue);
      expect(far.chime, ChimeKind.early);
      expect(now.chime, ChimeKind.now);
    });

    test(
      'mula dekat belokan: hanya peringkat terkini, bukan yang terlepas',
      () {
        final p = planner();
        final out = p.update(alongM: 3000 - 180, speedMps: 13.9);
        expect(out.length, 1);
        expect(out.single.kind, AnnouncementKind.near);
        expect(p.update(alongM: 3000 - 170, speedMps: 13.9), isEmpty);
      },
    );

    test('lebuh raya: amaran pertama lebih awal (dalam kilometer)', () {
      Announcement firstFar(double speed) => drive(
        planner(),
        speed,
      ).firstWhere((a) => a.kind == AnnouncementKind.far);
      expect(firstFar(27.8).text, contains('kilometer'));
      expect(firstFar(11).text, contains('meter'));
    });

    test('jalan lurus panjang selepas manuver: "ikut ... sejauh"', () {
      final short = drive(planner(), 13.9, from: 3000, to: 3100);
      expect(
        short.where((a) => a.kind == AnnouncementKind.keepGoing),
        isEmpty,
      ); // baki ~3 km < 4 km

      final longer = NavRoute(lShapedRoute(legM: 6000));
      final p = planner(longer);
      final out = <Announcement>[];
      for (var a = 5900.0; a <= 6300; a += 13.9) {
        out.addAll(p.update(alongM: a, speedMps: 13.9));
      }
      final keep = out
          .where((a) => a.kind == AnnouncementKind.keepGoing)
          .toList();
      expect(keep, hasLength(1));
      expect(keep.single.text, contains('Jalan Dua'));
    });

    test('arrival sekali sahaja dan menutup pengumuman selanjutnya', () {
      final p = planner();
      expect(p.arrival()!.text, 'Anda telah sampai.');
      expect(p.arrival(), isNull);
      expect(p.update(alongM: 100, speedMps: 10), isEmpty);
    });

    test('start berbeza untuk re-route dan hanya sekali', () {
      final p = planner();
      expect(p.start().single.kind, AnnouncementKind.start);
      expect(p.start(), isEmpty);
      expect(
        planner().start(isReroute: true).single.kind,
        AnnouncementKind.newRoute,
      );
    });

    test('tukar bahasa berkuat kuasa pada pengumuman seterusnya', () {
      final p = planner()..language = VoiceLanguage.en;
      final out = drive(p, 13.9);
      expect(
        out.firstWhere((a) => a.kind == AnnouncementKind.far).text,
        startsWith('In '),
      );
    });
  });
}
