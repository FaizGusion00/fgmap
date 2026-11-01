import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/domain/poi_category.dart';
import 'package:fgmap/features/map/domain/turn_label.dart';
import 'package:fgmap/features/map/presentation/nav_route_line.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:flutter_test/flutter_test.dart';

import '../navigation/nav_test_support.dart';

NavRouteLine eastLine(double lengthM) {
  const origin = GeoPoint(3.1, 101.7);
  final pts = [
    for (var d = 0.0; d <= lengthM; d += 25) destinationPoint(origin, 90, d),
  ];
  final cum = [for (var i = 0; i < pts.length; i++) i * 25.0];
  return NavRouteLine(points: pts, cumulativeM: cum, version: 1);
}

void main() {
  group('NavRouteLine.chevronsAhead', () {
    final line = eastLine(2000);

    test('tetap pada jalan: kelipatan 50 m, bukan relatif kepada kenderaan', () {
      final a = line.chevronsAhead(100);
      final same = line.chevronsAhead(110);
      final b = line.chevronsAhead(140);
      expect(a, hasLength(14));
      // Bergerak 10 m: tiada apa berubah. Bergerak 40 m: anak panah ke-2 menjadi yang pertama,
      // di tempat yang sama pada jalan.
      expect(same.first.point, a.first.point);
      expect(a[1].point.lat, closeTo(b[0].point.lat, 1e-9));
      expect(a[1].point.lng, closeTo(b[0].point.lng, 1e-9));
      for (final c in a) {
        expect(c.bearing, closeTo(90, 1));
      }
    });

    test(
      'mulai selepas ruang bersih di hadapan kenderaan, dan tidak di belakang',
      () {
        final first = line.chevronsAhead(100).first;
        final d = distanceMeters(line.pointAt(0), first.point);
        expect(d, greaterThanOrEqualTo(112 - 1));
        expect(d, lessThan(162));
      },
    );

    test(
      'berhenti sebelum hujung laluan; tiada apa-apa jika sudah di hujung',
      () {
        expect(line.chevronsAhead(1990), isEmpty);
        final nearEnd = line.chevronsAhead(1900);
        expect(nearEnd.length, lessThan(14));
        for (final c in nearEnd) {
          expect(distanceMeters(c.point, line.pointAt(2000)), greaterThan(11));
        }
      },
    );

    test('laluan kosong atau satu titik: senarai kosong', () {
      final one = NavRouteLine(
        points: const [GeoPoint(3, 101)],
        cumulativeM: const [0],
        version: 1,
      );
      expect(one.chevronsAhead(0), isEmpty);
    });

    test('arah mengikut selekoh: belok ke selatan memberi arah ~180', () {
      final l = lShapedLine();
      final turned = l.chevronsAhead(1100, count: 3);
      expect(turned, isNotEmpty);
      expect(turned.first.bearing, closeTo(180, 5));
    });
  });

  group('turnLabelFor', () {
    final route = NavRoute(lShapedRoute());
    final right = route.maneuvers[1];

    test('nama jalan yang dimasuki di titik belok', () {
      final label = turnLabelFor(route, right, 400)!;
      expect(label.text, 'Jalan Dua');
      expect(
        distanceMeters(label.point, route.pointAt(right.startM)),
        lessThan(1),
      );
    });

    test('terlalu jauh, tiada manuver atau jarak: tiada label', () {
      expect(turnLabelFor(route, right, 1500), isNull);
      expect(turnLabelFor(route, null, 100), isNull);
      expect(turnLabelFor(route, right, null), isNull);
    });

    test('mula, tiba dan tiada tindakan: tiada label', () {
      expect(turnLabelFor(route, route.maneuvers.first, 100), isNull);
      expect(turnLabelFor(route, route.maneuvers.last, 100), isNull);
    });

    test('tiada nama jalan: tiada label; nama panjang dipotong', () {
      NavManeuver named(List<String> names) => NavManeuver(
        index: 1,
        kind: ManeuverKind.right,
        startM: right.startM,
        lengthM: 100,
        timeS: 10,
        streetNames: names,
      );
      expect(turnLabelFor(route, named(const []), 100), isNull);
      expect(turnLabelFor(route, named(const ['  ']), 100), isNull);
      final long = turnLabelFor(
        route,
        named(const [
          'Persiaran Bestari, Kawasan Perindustrian Ringan Seksyen 7',
        ]),
        100,
      )!;
      expect(long.text.length, turnLabelMaxChars);
      expect(long.text.endsWith('…'), isTrue);
    });

    test(
      'kesamaan nilai supaya peta tidak menghantar semula label yang sama',
      () {
        final a = turnLabelFor(route, right, 400);
        final b = turnLabelFor(route, right, 250);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      },
    );
  });

  group('poiCategoryOf', () {
    test(
      'kelas OpenMapTiles dipetakan; yang tidak dikenali dan null tidak dilukis',
      () {
        expect(poiCategoryOf('fuel'), PoiCategory.fuel);
        expect(poiCategoryOf('fast_food'), PoiCategory.food);
        expect(poiCategoryOf('grocery'), PoiCategory.shop);
        expect(poiCategoryOf('school'), PoiCategory.school);
        expect(poiCategoryOf('hospital'), PoiCategory.health);
        expect(poiCategoryOf('place_of_worship'), PoiCategory.worship);
        expect(poiCategoryOf('parking'), PoiCategory.parking);
        expect(poiCategoryOf('post'), isNull);
        expect(poiCategoryOf(null), isNull);
      },
    );

    test(
      'tiada kelas dalam dua kategori; setiap kategori ada kelas dan nama imej unik',
      () {
        final seen = <String>{};
        for (final e in poiClassesByCategory.entries) {
          expect(e.value, isNotEmpty, reason: e.key.name);
          for (final c in e.value) {
            expect(seen.add(c), isTrue, reason: 'duplikat $c');
          }
        }
        expect(poiClassesByCategory.keys.toSet(), PoiCategory.values.toSet());
        expect(
          PoiCategory.values.map(poiImageName).toSet(),
          hasLength(PoiCategory.values.length),
        );
      },
    );
  });
}

/// Laluan timur 1000 m kemudian selatan 1000 m (garisan yang dilukis).
NavRouteLine lShapedLine() {
  const origin = GeoPoint(3.0, 101.0);
  final corner = destinationPoint(origin, 90, 1000);
  final pts = <GeoPoint>[
    for (var d = 0.0; d < 1000; d += 25) destinationPoint(origin, 90, d),
    corner,
    for (var d = 25.0; d <= 1000; d += 25) destinationPoint(corner, 180, d),
  ];
  final cum = <double>[0];
  for (var i = 1; i < pts.length; i++) {
    cum.add(cum.last + distanceMeters(pts[i - 1], pts[i]));
  }
  return NavRouteLine(points: pts, cumulativeM: cum, version: 1);
}
