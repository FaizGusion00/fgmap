import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

void main() {
  group('geo', () {
    test('distanceMeters: 1 darjah latitud ~ 111.19 km', () {
      expect(
        distanceMeters(const GeoPoint(3, 101), const GeoPoint(4, 101)),
        closeTo(111195, 100),
      );
    });

    test('bearingDegrees: empat arah utama', () {
      const o = GeoPoint(3, 101);
      expect(bearingDegrees(o, const GeoPoint(4, 101)), closeTo(0, 0.01));
      expect(bearingDegrees(o, const GeoPoint(3, 102)), closeTo(90, 0.6));
      expect(bearingDegrees(o, const GeoPoint(2, 101)), closeTo(180, 0.01));
      expect(bearingDegrees(o, const GeoPoint(3, 100)), closeTo(270, 0.6));
    });

    test('destinationPoint adalah songsang distance + bearing', () {
      const o = GeoPoint(3.139, 101.687);
      for (final b in [0.0, 45.0, 133.0, 270.0, 359.0]) {
        final d = destinationPoint(o, b, 1234);
        expect(distanceMeters(o, d), closeTo(1234, 0.5));
        expect(angleDelta(bearingDegrees(o, d), b).abs(), lessThan(0.05));
      }
    });

    test('angleDelta: terpendek dan bertanda, merentas 0/360', () {
      expect(angleDelta(350, 10), 20);
      expect(angleDelta(10, 350), -20);
      expect(angleDelta(0, 180).abs(), 180);
      expect(angleDelta(90, 90), 0);
      expect(normalizeBearing(-10), 350);
      expect(normalizeBearing(725), 5);
    });

    test('projectToSegment: tengah, hujung, dan segmen sifar panjang', () {
      const a = GeoPoint(3, 101);
      final b = destinationPoint(a, 90, 100);
      final mid = destinationPoint(destinationPoint(a, 90, 40), 0, 7);
      final p = projectToSegment(mid, a, b);
      expect(p.t, closeTo(0.4, 0.01));
      expect(p.distanceM, closeTo(7, 0.1));

      final before = destinationPoint(a, 270, 50);
      expect(projectToSegment(before, a, b).t, 0);
      expect(projectToSegment(before, a, b).distanceM, closeTo(50, 0.1));

      expect(
        projectToSegment(mid, a, a).distanceM,
        closeTo(distanceMeters(mid, a), 0.1),
      );
    });

    test('metersPerPixel menyusut separuh setiap zum', () {
      expect(metersPerPixel(15, 3) / metersPerPixel(16, 3), closeTo(2, 0.0001));
    });
  });

  group('NavRoute', () {
    final route = NavRoute(lShapedRoute());

    test('jarak kumulatif dan jumlah', () {
      expect(route.totalM, closeTo(2000, 2));
      expect(route.cum.first, 0);
    });

    test('pointAt dan bearingAt pada kedua-dua kaki', () {
      expect(
        distanceMeters(route.pointAt(0), route.points.first),
        lessThan(0.01),
      );
      expect(route.bearingAt(500), closeTo(90, 1));
      expect(route.bearingAt(1500), closeTo(180, 1));
      // Hujung laluan: arah dari titik sebelumnya, bukan 0.
      expect(route.bearingAt(route.totalM), closeTo(180, 1));
      // Di luar julat dikepit.
      expect(
        distanceMeters(route.pointAt(-50), route.points.first),
        lessThan(0.01),
      );
      expect(
        distanceMeters(route.pointAt(99999), route.points.last),
        lessThan(0.01),
      );
    });

    test('manuver: kedudukan, jenis, dan nextActionable', () {
      expect(route.maneuvers.map((m) => m.kind), [
        ManeuverKind.depart,
        ManeuverKind.right,
        ManeuverKind.arrive,
      ]);
      expect(route.maneuvers[1].startM, closeTo(1000, 2));
      expect(route.nextActionable(0)!.kind, ManeuverKind.right);
      expect(route.nextActionable(1001)!.kind, ManeuverKind.arrive);
      expect(route.nextActionable(route.totalM), isNull);
      expect(route.maneuverAt(1200)!.kind, ManeuverKind.right);
    });

    test('masa baki berkurang mengikut jarak dan sampai sifar', () {
      expect(route.plannedRemainingTime(0), closeTo(144, 1));
      expect(route.plannedRemainingTime(1000), closeTo(72, 1));
      expect(route.plannedRemainingTime(route.totalM), closeTo(0, 0.5));
    });

    test('street memilih nama biasa berbanding kod jalan', () {
      const m = NavManeuver(
        index: 0,
        kind: ManeuverKind.right,
        startM: 0,
        lengthM: 0,
        timeS: 0,
        streetNames: ['E12', 'Lebuhraya Ampang'],
      );
      expect(m.street, 'Lebuhraya Ampang');
      const onlyRef = NavManeuver(
        index: 0,
        kind: ManeuverKind.right,
        startM: 0,
        lengthM: 0,
        timeS: 0,
        streetNames: ['E12'],
      );
      expect(onlyRef.street, 'E12');
    });

    test('remainingShape: mula di kedudukan semasa, dihad dan dijarangkan', () {
      final shape = route.remainingShape(500);
      expect(distanceMeters(shape.first, route.pointAt(500)), lessThan(0.01));
      expect(distanceMeters(shape.last, route.points.last), lessThan(0.01));
      final limited = route.remainingShape(0, aheadM: 600);
      expect(distanceMeters(limited.last, route.pointAt(600)), lessThan(0.5));
    });

    test(
      'remainingShape laluan jauh meliputi destinasi dan menjarangkan titik jauh',
      () {
        const origin = GeoPoint(3, 101);
        final points = [
          for (var distance = 0.0; distance <= 100000; distance += 100)
            destinationPoint(origin, 90, distance),
        ];
        final longRoute = NavRoute(
          RouteOption(
            distanceM: 100000,
            durationS: 7200,
            hasTolls: false,
            points: points,
          ),
        );

        final shape = longRoute.remainingShape(0);

        expect(shape.first, points.first);
        expect(shape.last, points.last);
        expect(shape.length, lessThan(points.length));
      },
    );

    test('laluan sebenar KLCC-KLIA: 31 manuver, jarak sepadan ringkasan', () {
      final real = loadFixtureNavRoute();
      expect(real.maneuvers.length, 31);
      expect(real.totalM, closeTo(67049, 400));
      expect(real.maneuvers.first.kind, ManeuverKind.depart);
      expect(real.maneuvers.last.isArrival, isTrue);
      for (var i = 1; i < real.maneuvers.length; i++) {
        expect(
          real.maneuvers[i].startM,
          greaterThanOrEqualTo(real.maneuvers[i - 1].startM),
        );
      }
      expect(real.plannedRemainingTime(0), closeTo(3477, 5));
    });
  });
}
