import 'dart:math' as math;

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/route_tracker.dart';
import 'package:fgmap/features/navigation/domain/vehicle_model.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

RouteOption _option(List<GeoPoint> pts) =>
    RouteOption(distanceM: 1000, durationS: 100, hasTolls: false, points: pts);

void main() {
  group('selekoh paparan (lengkung, bukan bucu tajam)', () {
    final route = NavRoute(lShapedRoute(legM: 600));
    const radius = NavRoute.displayCornerRadiusM;
    final corner = route.points[(600 / 50).ceil()];

    test(
      'tepat di bucu: kereta ~R(1/cos45-1) = 5 m di dalam bucu; arah = 135 deg',
      () {
        final p = route.displayPointAt(600);
        expect(
          distanceMeters(p, corner),
          closeTo(radius * (1 / math.cos(math.pi / 4) - 1), 0.4),
        );
        expect(route.displayBearingAt(600), closeTo(135, 1));
      },
    );

    test('di luar selekoh sama dengan polyline', () {
      for (final d in [10.0, 300.0, 560.0, 640.0, 900.0, 1190.0]) {
        expect(
          distanceMeters(route.displayPointAt(d), route.pointAt(d)),
          lessThan(0.05),
          reason: 'jarak $d',
        );
      }
    });

    test(
      'lengkung bersambung (kedudukan dan arah) pada sempadan masuk dan keluar',
      () {
        const t = radius * 1.0; // tangen = R tan(45 deg) = R untuk belok 90 deg
        for (final edge in [600 - t, 600 + t]) {
          final before = route.displayPointAt(edge - 0.02);
          final after = route.displayPointAt(edge + 0.02);
          expect(distanceMeters(before, after), lessThan(0.1));
          expect(
            angleDelta(
              route.displayBearingAt(edge - 0.02, lookAheadM: 1),
              route.displayBearingAt(edge + 0.02, lookAheadM: 1),
            ).abs(),
            lessThan(3),
          );
        }
      },
    );

    test('arah berubah licin dan menaik (tiada lonjakan) merentasi selekoh', () {
      var prev = route.displayBearingAt(570);
      var maxStep = 0.0;
      for (var d = 570.0; d <= 630; d += 0.5) {
        final b = route.displayBearingAt(d);
        maxStep = math.max(maxStep, angleDelta(prev, b).abs());
        prev = b;
      }
      // 90 deg dalam ~19 m lengkung = ~4.8 deg setiap 1 m; langkah 0.5 m ~2.4 deg.
      expect(maxStep, lessThan(3.5));
      expect(prev, closeTo(180, 2));
    });

    test('panjang arka sampel ≈ R·θ untuk selekoh 90°', () {
      const t = radius; // tan(45°)=1
      var path = 0.0;
      var prev = route.displayPointAt(600 - t);
      for (var d = 600 - t + 0.25; d <= 600 + t; d += 0.25) {
        final cur = route.displayPointAt(d);
        path += distanceMeters(prev, cur);
        prev = cur;
      }
      final expected = radius * math.pi / 2;
      expect(path, closeTo(expected, expected * 0.08));
    });

    test('displayPolyline melepasi dalam lengkung, bukan bucu tajam', () {
      final line = route.displayPolyline(stepM: 5);
      expect(line.points.length, greaterThan(route.points.length));
      expect(line.points.length, line.cumulativeM.length);
      expect(line.cumulativeM.first, 0);
      expect(line.cumulativeM.last, closeTo(route.totalM, 0.01));
      final corner = route.points[(600 / 50).ceil()];
      var minDist = double.infinity;
      for (final p in line.points) {
        minDist = math.min(minDist, distanceMeters(p, corner));
      }
      // Sampel lengkung tidak melalui bucu tajam (inset ~5 m untuk R=12).
      expect(minDist, greaterThan(3));
    });

    test('AA polyline lebih jarang daripada telefon', () {
      final phone = route.displayPolyline(stepM: 5, cornerStepM: 3);
      final aa = route.displayPolyline(
        stepM: 25,
        cornerStepM: 8,
        cornerPadM: 50,
      );
      expect(aa.points.length, lessThan(phone.points.length));
      expect(aa.points.length, lessThan(route.totalM / 12));
      // Masih melalui selekoh (bukan hanya bucu tajam).
      final corner = route.points[(600 / 50).ceil()];
      var minDist = double.infinity;
      for (final p in aa.points) {
        minDist = math.min(minDist, distanceMeters(p, corner));
      }
      expect(minDist, greaterThan(2));
    });

    test('belokan kecil (< 25 deg) dan pusingan-U tidak dilengkungkan', () {
      const origin = GeoPoint(3.0, 101.0);
      final a = destinationPoint(origin, 90, 200);
      final slight = destinationPoint(a, 90 + 15, 200);
      final r1 = NavRoute(_option([origin, a, slight]));
      expect(
        distanceMeters(r1.displayPointAt(200), r1.pointAt(200)),
        lessThan(0.05),
      );
      final uturn = destinationPoint(a, 270, 200);
      final r2 = NavRoute(_option([origin, a, uturn]));
      expect(
        distanceMeters(r2.displayPointAt(200), r2.pointAt(200)),
        lessThan(0.05),
      );
    });

    test(
      'segmen pendek: jejari dikecilkan, dua selekoh rapat tidak bertindih',
      () {
        const origin = GeoPoint(3.0, 101.0);
        // Zigzag 20 m: tangen selekoh 12 m tidak muat; mesti dikecilkan.
        final p1 = destinationPoint(origin, 90, 20);
        final p2 = destinationPoint(p1, 0, 20);
        final p3 = destinationPoint(p2, 90, 20);
        final r = NavRoute(_option([origin, p1, p2, p3]));
        var prev = r.displayPointAt(0);
        for (var d = 0.5; d <= r.totalM; d += 0.5) {
          final cur = r.displayPointAt(d);
          // Tiada lompatan: setiap 0.5 m jarak laluan memajukan paparan <= ~1 m.
          expect(distanceMeters(prev, cur), lessThan(1.0), reason: 'jarak $d');
          prev = cur;
        }
      },
    );

    test('belok kiri: lengkung ke dalam (kiri), arah menurun 90 -> 0', () {
      const origin = GeoPoint(3.0, 101.0);
      final a = destinationPoint(origin, 90, 300);
      final end = destinationPoint(a, 0, 300);
      final r = NavRoute(_option([origin, a, end]));
      expect(r.displayBearingAt(300), closeTo(45, 1));
      // Titik tengah lengkung berada di sebelah dalam bucu (utara-barat bucu).
      final p = r.displayPointAt(300);
      expect(p.lat, greaterThan(a.lat));
      expect(p.lng, lessThan(a.lng));
    });
  });

  group('padanan laluan di selekoh dengan heading GPS lewat', () {
    test('heading lama (belum belok) tidak menahan padanan di kaki lama', () {
      final route = NavRoute(lShapedRoute(legM: 600));
      final tracker = RouteTracker(route);
      // Sebelum bucu.
      tracker.match(
        route.pointAt(560),
        headingDegrees: 90,
        speedMps: 8,
        gap: const Duration(seconds: 1),
      );
      // 10 m melepasi bucu pada kaki baharu, tetapi heading GPS masih 90 (lewat ~1 s).
      final past = route.pointAt(610);
      final match = tracker.match(
        past,
        headingDegrees: 90,
        speedMps: 8,
        gap: const Duration(seconds: 1),
      );
      expect(match.alongM, closeTo(610, 3));
    });
  });

  group('ekstrapolasi dengan pecutan (membrek ke selekoh)', () {
    final route = NavRoute(lShapedRoute(legM: 2000));
    final t0 = DateTime.utc(2026, 1, 1, 12);

    test(
      'kelajuan menurun 14 -> 10 m/s: unjuran lebih pendek daripada kelajuan malar',
      () {
        final v = VehicleModel(route);
        v.onRouteFix(alongM: 100, speedMps: 14, time: t0);
        v.poseAt(t0);
        final t1 = t0.add(const Duration(seconds: 1));
        v.onRouteFix(alongM: 114, speedMps: 10, time: t1);
        v.poseAt(t1);
        // 1.5 s selepas fix kedua: kelajuan malar (~11.6) memberi ~17 m; dengan brek kurang.
        var a = 0.0;
        for (var ms = 16; ms <= 1500; ms += 16) {
          a = v.poseAt(t1.add(Duration(milliseconds: ms))).alongM;
        }
        const constant = 114 + 11.6 * 1.5;
        expect(a, lessThan(constant - 1.0));
        expect(a, greaterThan(114));
      },
    );

    test('brek keras tidak mengunjur ke belakang (kelajuan tidak negatif)', () {
      final v = VehicleModel(route);
      v.onRouteFix(alongM: 100, speedMps: 8, time: t0);
      v.poseAt(t0);
      final t1 = t0.add(const Duration(seconds: 1));
      v.onRouteFix(alongM: 108, speedMps: 1, time: t1);
      v.poseAt(t1);
      var last = v.poseAt(t1).alongM;
      for (var ms = 16; ms <= 4000; ms += 16) {
        final a = v.poseAt(t1.add(Duration(milliseconds: ms))).alongM;
        expect(a, greaterThanOrEqualTo(last - 1e-9));
        last = a;
      }
      expect(last, lessThan(108 + 6));
    });
  });
}
