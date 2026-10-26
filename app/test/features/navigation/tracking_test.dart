import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/fix_filter.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/off_route_detector.dart';
import 'package:fgmap/features/navigation/domain/route_tracker.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

void main() {
  group('RouteTracker', () {
    final route = NavRoute(lShapedRoute());

    test('memadankan titik di atas laluan dan di sisinya', () {
      final tracker = RouteTracker(route);
      final p = destinationPoint(route.pointAt(300), 0, 12); // 12 m utara jalan
      final m = tracker.match(p, headingDegrees: 90);
      expect(m.alongM, closeTo(300, 3));
      expect(m.crossTrackM, closeTo(12, 0.5));
      expect(m.routeBearing, closeTo(90, 1));
    });

    test('kemajuan tidak berundur kerana hingar kecil', () {
      final tracker = RouteTracker(route);
      tracker.match(route.pointAt(400), headingDegrees: 90);
      final m = tracker.match(route.pointAt(390), headingDegrees: 90);
      expect(m.alongM, greaterThan(385));
      // Tetapi lompatan ke belakang yang besar dikenakan penalti.
      final m2 = tracker.match(route.pointAt(100), headingDegrees: 90);
      expect(m2.crossTrackM, lessThan(1)); // padanan sah dipilih (satu-satunya)
    });

    test('lorong bertentangan: arah gerakan memilih jalan yang betul', () {
      // Dua laluan selari 10 m: laluan (timur) dan jalan lawan arah. Laluan hanya satu, jadi uji
      // melalui laluan U: pergi timur lalu pulang barat 10 m ke selatan.
      const o = GeoPoint(3, 101);
      final east = destinationPoint(o, 90, 1000);
      final back = destinationPoint(east, 180, 10);
      final end = destinationPoint(back, 270, 1000);
      final uRoute = NavRoute(
        RouteOption(
          distanceM: 2010,
          durationS: 150,
          hasTolls: false,
          points: [o, east, back, end],
        ),
      );
      final tracker = RouteTracker(uRoute);
      // Kereta di pertengahan jalan balik (barat), 3 m ke utara jalan balik.
      final p = destinationPoint(destinationPoint(east, 270, 500), 180, 7);
      final west = tracker.match(p, headingDegrees: 270);
      expect(west.alongM, greaterThan(1500)); // kaki pulang
      final eastbound = RouteTracker(uRoute).match(p, headingDegrees: 90);
      expect(eastbound.alongM, lessThan(600)); // kaki pergi
    });

    test('jurang isyarat panjang: tetingkap ke hadapan melebar', () {
      final tracker = RouteTracker(route);
      tracker.match(route.pointAt(100), headingDegrees: 90, speedMps: 20);
      final m = tracker.match(
        route.pointAt(1700),
        headingDegrees: 180,
        speedMps: 20,
        gap: const Duration(seconds: 70),
      );
      expect(m.alongM, closeTo(1700, 5));
      expect(m.crossTrackM, lessThan(1));
    });

    test('padanan global selepas tetingkap meragukan', () {
      final tracker = RouteTracker(route);
      tracker.match(route.pointAt(50), headingDegrees: 90);
      final m = tracker.match(route.pointAt(1900), headingDegrees: 180);
      expect(m.crossTrackM, lessThan(1));
      expect(m.alongM, closeTo(1900, 5));
    });
  });

  group('FixFilter', () {
    final t0 = DateTime.utc(2026, 1, 1);
    LocationFix fix(
      double lat,
      double lng,
      int sec, {
      double acc = 5,
      double? speed,
      int? heading,
    }) => LocationFix(
      point: GeoPoint(lat, lng),
      accuracyMeters: acc,
      speedMps: speed,
      headingDegrees: heading,
      timestamp: t0.add(Duration(seconds: sec)),
    );

    test('fix pertama diterima apa adanya', () {
      final f = FixFilter();
      final out = f.accept(fix(3, 101, 0), now: t0)!;
      expect(out.point, const GeoPoint(3, 101));
    });

    test('fix GPS cache ditolak sehingga fix segar tiba', () {
      final f = FixFilter();
      expect(
        f.accept(fix(3, 101, 0), now: t0.add(const Duration(seconds: 11))),
        isNull,
      );
      final fresh = f.accept(
        fix(3, 101, 12),
        now: t0.add(const Duration(seconds: 12)),
      );
      expect(fresh, isNotNull);
      expect(fresh!.point, const GeoPoint(3, 101));
    });

    test('fix awal yang lemah atau tiada ukuran ketepatan tidak digunakan', () {
      final filter = FixFilter();
      expect(filter.accept(fix(3, 101, 0, acc: 200), now: t0), isNull);
      expect(
        filter.accept(
          LocationFix(point: const GeoPoint(3, 101), timestamp: t0),
          now: t0,
        ),
        isNull,
      );
      final accurate = filter.accept(
        fix(3, 101, 1),
        now: t0.add(const Duration(seconds: 1)),
      );
      expect(accurate, isNotNull);
      expect(accurate!.degraded, isFalse);
    });

    test(
      'menolak ketepatan rendah, tetapi menerimanya jika sudah lama tiada fix baik',
      () {
        final f = FixFilter();
        f.accept(fix(3, 101, 0), now: t0);
        expect(f.accept(fix(3, 101, 2, acc: 200), now: t0), isNull);
        final late = f.accept(
          fix(3, 101, 12, acc: 200),
          now: t0.add(const Duration(seconds: 12)),
        );
        expect(late, isNotNull);
        expect(late!.degraded, isTrue);
      },
    );

    test('menolak fix berulang / tidak tertib', () {
      final f = FixFilter();
      f.accept(fix(3, 101, 5), now: t0.add(const Duration(seconds: 5)));
      expect(
        f.accept(fix(3, 101, 5), now: t0.add(const Duration(seconds: 5))),
        isNull,
      );
      expect(
        f.accept(fix(3, 101, 4), now: t0.add(const Duration(seconds: 4))),
        isNull,
      );
    });

    test(
      'lompatan mustahil ditolak, tetapi berterusan = lokasi baharu sebenar',
      () {
        final f = FixFilter();
        f.accept(fix(3, 101, 0), now: t0);
        expect(
          f.accept(fix(3.5, 101, 1), now: t0.add(const Duration(seconds: 1))),
          isNull,
        );
        expect(
          f.accept(fix(3.5, 101, 2), now: t0.add(const Duration(seconds: 2))),
          isNull,
        );
        final third = f.accept(
          fix(3.5, 101, 3),
          now: t0.add(const Duration(seconds: 3)),
        );
        expect(third, isNotNull);
        expect(third!.point.lat, closeTo(3.5, 0.001));
      },
    );

    test(
      'hingar dilicinkan: sisihan piawai output lebih kecil daripada input',
      () {
        final f = FixFilter();
        const mPerDegLat = 111195.0;
        final noise = [
          6.0,
          -5.0,
          7.0,
          -6.0,
          4.0,
          -7.0,
          5.0,
          -4.0,
          6.0,
          -5.0,
          7.0,
          -6.0,
        ];
        final outputs = <double>[];
        for (var i = 0; i < noise.length; i++) {
          final out = f.accept(
            fix(3 + noise[i] / mPerDegLat, 101, i, acc: 8, speed: 0),
            now: t0.add(Duration(seconds: i)),
          )!;
          outputs.add((out.point.lat - 3) * mPerDegLat);
        }
        double rms(Iterable<double> v) =>
            (v.map((x) => x * x).reduce((a, b) => a + b) / v.length);
        expect(rms(outputs.skip(4)), lessThan(rms(noise.skip(4)) * 0.5));
      },
    );

    test(
      'pada kelajuan tinggi, penapis mengikut pengukuran (tidak ketinggalan)',
      () {
        final f = FixFilter();
        const mPerDegLat = 111195.0;
        FilteredFix? last;
        for (var i = 0; i < 10; i++) {
          last = f.accept(
            fix(3 + i * 25 / mPerDegLat, 101, i, acc: 5, speed: 25, heading: 0),
            now: t0.add(Duration(seconds: i)),
          );
        }
        const truthLat = 3 + 9 * 25 / mPerDegLat;
        expect(((last!.point.lat - truthLat) * mPerDegLat).abs(), lessThan(4));
        expect(last.speedMps, 25);
      },
    );

    test('arah diterbitkan daripada perpindahan jika peranti tiada arah', () {
      final f = FixFilter();
      const mPerDegLng = 111195.0 * 0.99863;
      FilteredFix? last;
      for (var i = 0; i < 6; i++) {
        last = f.accept(
          fix(3, 101 + i * 15 / mPerDegLng, i, speed: 15),
          now: t0.add(Duration(seconds: i)),
        );
      }
      expect(last!.headingDegrees, isNotNull);
      expect(angleDelta(last.headingDegrees!, 90).abs(), lessThan(5));
    });
  });

  group('OffRouteDetector', () {
    final route = NavRoute(lShapedRoute());
    FilteredFix fix(
      GeoPoint p,
      int sec, {
      double heading = 90,
      double speed = 14,
      double acc = 5,
    }) => FilteredFix(
      point: p,
      time: DateTime.utc(2026, 1, 1).add(Duration(seconds: sec)),
      accuracyM: acc,
      speedMps: speed,
      headingDegrees: heading,
    );

    RouteMatch matchFor(GeoPoint p) =>
        RouteTracker(route).match(p, headingDegrees: 0);

    test('ambang adaptif mengikut ketepatan', () {
      expect(OffRouteDetector.thresholdFor(5), 35);
      expect(OffRouteDetector.thresholdFor(30), closeTo(70, 0.1));
      expect(OffRouteDetector.thresholdFor(400), 120);
    });

    test('di atas laluan: tidak pernah re-route', () {
      final d = OffRouteDetector();
      for (var i = 0; i < 10; i++) {
        final p = route.pointAt(100.0 * i);
        expect(d.update(matchFor(p), fix(p, i)), isFalse);
      }
    });

    test(
      'menyimpang jauh + arah lain: disahkan awal; cooldown mengawal ulangan',
      () {
        final d = OffRouteDetector();
        final base = route.pointAt(400);
        var triggered = 0;
        for (var i = 0; i < 12; i++) {
          final p = destinationPoint(base, 0, 80.0 + i * 14);
          final fired = d.update(matchFor(p), fix(p, i, heading: 0));
          if (fired) {
            triggered++;
            d.markRequested(DateTime.utc(2026, 1, 1).add(Duration(seconds: i)));
          }
        }
        // Jauh (>3x ambang) disahkan pada fix ke-2; cooldown 8 s menghalang ulangan serta-merta.
        expect(triggered, 2);
      },
    );

    test('hingar sekali sahaja (satu fix jauh) tidak mencetuskan', () {
      final d = OffRouteDetector();
      final near = route.pointAt(400);
      final far = destinationPoint(near, 0, 60);
      expect(d.update(matchFor(near), fix(near, 0)), isFalse);
      expect(d.update(matchFor(far), fix(far, 1, heading: 0)), isFalse);
      expect(d.update(matchFor(near), fix(near, 2)), isFalse);
      expect(d.update(matchFor(far), fix(far, 3, heading: 0)), isFalse);
    });

    test('jalan selari searah di bawah ambang: bukan menyimpang', () {
      final d = OffRouteDetector();
      for (var i = 0; i < 10; i++) {
        final p = destinationPoint(route.pointAt(100.0 * i), 0, 20);
        expect(d.update(matchFor(p), fix(p, i)), isFalse);
      }
    });

    test('pegun jauh dari laluan (cth. stesen minyak) tidak mencetuskan', () {
      final d = OffRouteDetector();
      final p = destinationPoint(route.pointAt(300), 0, 60);
      for (var i = 0; i < 10; i++) {
        expect(d.update(matchFor(p), fix(p, i, speed: 0)), isFalse);
      }
    });
  });
}
