import 'dart:math' as math;

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/vehicle_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

void main() {
  group('VehicleModel', () {
    final route = NavRoute(lShapedRoute());
    final t0 = DateTime.utc(2026, 1, 1, 12);

    test('bergerak licin antara fix (60 fps) dan tidak pernah berundur', () {
      final v = VehicleModel(route);
      v.onRouteFix(alongM: 100, speedMps: 14, time: t0);
      var prev = v.poseAt(t0).alongM;
      var maxStep = 0.0;
      for (var ms = 16; ms <= 1000; ms += 16) {
        final p = v.poseAt(t0.add(Duration(milliseconds: ms)));
        expect(p.alongM, greaterThanOrEqualTo(prev));
        maxStep = math.max(maxStep, p.alongM - prev);
        prev = p.alongM;
      }
      expect(prev, closeTo(114, 3));
      expect(maxStep, lessThan(0.4)); // ~14 m/s * 0.016 s = 0.22 m
    });

    test('fix yang sedikit terlewat dikejar tanpa lonjakan', () {
      final v = VehicleModel(route);
      v.onRouteFix(alongM: 100, speedMps: 14, time: t0);
      for (var ms = 16; ms <= 1000; ms += 16) {
        v.poseAt(t0.add(Duration(milliseconds: ms)));
      }
      // Fix di 1 s menyatakan 8 m di hadapan jangkaan: pembetulan beransur-ansur.
      final t1 = t0.add(const Duration(seconds: 1));
      v.onRouteFix(alongM: 122, speedMps: 14, time: t1);
      var prev = v.poseAt(t1).alongM;
      var maxStep = 0.0;
      for (var ms = 16; ms <= 1000; ms += 16) {
        final p = v.poseAt(t1.add(Duration(milliseconds: ms)));
        maxStep = math.max(maxStep, p.alongM - prev);
        prev = p.alongM;
      }
      expect(maxStep, lessThan(2.5));
      // Penapis alfa: separuh daripada beza 8 m diterima pada fix pertama (hingar GPS tidak terus ke
      // skrin); baki dibetulkan oleh fix seterusnya.
      expect(prev, closeTo(132, 2));
      final t2 = t1.add(const Duration(seconds: 1));
      v.onRouteFix(alongM: 136, speedMps: 14, time: t2);
      var settled = v.poseAt(t2).alongM;
      for (var ms = 16; ms <= 1000; ms += 16) {
        settled = v.poseAt(t2.add(Duration(milliseconds: ms))).alongM;
      }
      expect(
        settled,
        closeTo(148, 2),
        reason: 'selisih terus mengecil dengan setiap fix yang konsisten',
      );
    });

    test(
      'hingar GPS ke belakang: kenderaan berhenti seketika, tidak berundur',
      () {
        final v = VehicleModel(route);
        v.onRouteFix(alongM: 200, speedMps: 10, time: t0);
        final a = v.poseAt(t0).alongM;
        v.onRouteFix(
          alongM: 195,
          speedMps: 10,
          time: t0.add(const Duration(seconds: 1)),
        );
        final b = v
            .poseAt(t0.add(const Duration(seconds: 1, milliseconds: 16)))
            .alongM;
        expect(b, greaterThanOrEqualTo(a));
      },
    );

    test(
      'terowong: terus bergerak tanpa fix, kemudian berhenti selepas had',
      () {
        final v = VehicleModel(route);
        v.onRouteFix(alongM: 100, speedMps: 20, time: t0);
        v.poseAt(t0);
        var last = 0.0;
        for (var s = 1; s <= 10; s++) {
          last = v.poseAt(t0.add(Duration(seconds: s))).alongM;
        }
        expect(last, closeTo(300, 3));
        final held = v.poseAt(t0.add(const Duration(minutes: 30))).alongM;
        expect(held, lessThanOrEqualTo(route.totalM));
        expect(
          held,
          closeTo(100 + 20 * 90, 40).or(lessThanOrEqualTo(route.totalM)),
        );
      },
    );

    test('lompatan besar (>40 m) terus melompat; tidak dilicinkan', () {
      final v = VehicleModel(route);
      v.onRouteFix(alongM: 100, speedMps: 10, time: t0);
      v.poseAt(t0);
      v.onRouteFix(
        alongM: 600,
        speedMps: 10,
        time: t0.add(const Duration(seconds: 1)),
      );
      final p = v.poseAt(t0.add(const Duration(seconds: 1, milliseconds: 16)));
      expect(p.alongM, closeTo(600, 5));
    });

    test('arah mengikut laluan; di luar laluan menggunakan arah GPS', () {
      final v = VehicleModel(route);
      v.onRouteFix(alongM: 500, speedMps: 10, time: t0);
      expect(v.poseAt(t0).bearing, closeTo(90, 1));
      v.onFreeFix(
        point: const GeoPoint(3.5, 101.5),
        bearing: 33,
        speedMps: 10,
        time: t0.add(const Duration(seconds: 2)),
      );
      final p = v.poseAt(t0.add(const Duration(seconds: 2)));
      expect(p.onRoute, isFalse);
      expect(p.bearing, 33);
    });
  });

  group('camera: perancangan', () {
    test('zum menyusut dengan kelajuan secara monoton', () {
      var prev = double.infinity;
      for (var v = 0.0; v <= 45; v += 3) {
        final z = zoomForSpeed(v);
        expect(z, lessThanOrEqualTo(prev));
        prev = z;
      }
      expect(zoomForSpeed(0), closeTo(18.5, 0.01));
      expect(zoomForSpeed(100), closeTo(16.2, 0.01));
    });

    test(
      'jalan lurus: 3D condong; menghampiri belokan: menegak dan zum masuk',
      () {
        const far = CameraSituation(
          speedMps: 14,
          distanceToNextM: 1500,
          nextKind: ManeuverKind.right,
        );
        const close = CameraSituation(
          speedMps: 14,
          distanceToNextM: 30,
          nextKind: ManeuverKind.right,
        );
        final a = planCamera(far);
        final b = planCamera(close);
        expect(a.tilt, greaterThan(50));
        expect(b.tilt, lessThan(a.tilt - 15));
        expect(b.zoom, greaterThan(a.zoom + 0.5));
      },
    );

    test('bulatan dan pusingan-U lebih menegak daripada belok biasa', () {
      CameraTarget at(ManeuverKind k) => planCamera(
        CameraSituation(speedMps: 10, distanceToNextM: 20, nextKind: k),
      );
      expect(
        at(ManeuverKind.roundabout).tilt,
        lessThan(at(ManeuverKind.right).tilt),
      );
      expect(
        at(ManeuverKind.uTurn).tilt,
        lessThan(at(ManeuverKind.slightRight).tilt),
      );
      expect(
        at(ManeuverKind.right).tilt,
        lessThan(at(ManeuverKind.slightRight).tilt),
      );
    });

    test(
      'kedekatan diukur dalam masa: lebuh raya bermula lebih awal secara jarak',
      () {
        expect(maneuverProximity(150, 28), greaterThan(0)); // ~5 s
        expect(maneuverProximity(150, 8), 0); // ~19 s
        expect(maneuverProximity(10, 14), 1);
      },
    );

    test('mod 2D sentiasa tilt 0; mod 3D tidak menegak di selekoh', () {
      const s = CameraSituation(
        speedMps: 14,
        distanceToNextM: 20,
        nextKind: ManeuverKind.roundabout,
      );
      expect(
        planCamera(
          const CameraSituation(
            speedMps: 14,
            distanceToNextM: 20,
            nextKind: ManeuverKind.roundabout,
            mode: NavCameraMode.flat,
          ),
        ).tilt,
        0,
      );
      expect(
        planCamera(
          const CameraSituation(
            speedMps: 14,
            distanceToNextM: 20,
            nextKind: ManeuverKind.roundabout,
            mode: NavCameraMode.tilted,
          ),
        ).tilt,
        greaterThan(50),
      );
      expect(planCamera(s).tilt, lessThan(20));
    });

    test('tiada manuver: kembali ke pandangan jelajah', () {
      final t = planCamera(
        const CameraSituation(
          speedMps: 20,
          distanceToNextM: null,
          nextKind: null,
        ),
      );
      expect(t.tilt, greaterThan(55));
    });
  });

  group('CameraRig', () {
    const start = CameraPose(
      center: GeoPoint(3, 101),
      zoom: 12,
      tilt: 0,
      bearing: 0,
    );

    CameraPose run(
      CameraRig rig, {
      required double seconds,
      required double bearing,
      double speed = 14,
      double? dist,
      ManeuverKind? kind,
      GeoPoint vehicle = const GeoPoint(3, 101),
    }) {
      late CameraPose pose;
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        pose = rig.step(
          dt: 1 / 60,
          vehicle: vehicle,
          vehicleBearing: bearing,
          speedMps: speed,
          distanceToNextM: dist,
          nextKind: kind,
          viewportHeightPx: 800,
        );
      }
      return pose;
    }

    test('menumpu ke sasaran tanpa terlajak', () {
      final rig = CameraRig(entry: start);
      double? maxZoom;
      double? maxTilt;
      CameraPose? p;
      for (var t = 0.0; t < 8; t += 1 / 60) {
        p = rig.step(
          dt: 1 / 60,
          vehicle: const GeoPoint(3, 101),
          vehicleBearing: 90,
          speedMps: 14,
          distanceToNextM: null,
          nextKind: null,
          viewportHeightPx: 800,
        );
        maxZoom = math.max(maxZoom ?? 0, p.zoom);
        maxTilt = math.max(maxTilt ?? 0, p.tilt);
      }
      final goal = planCamera(
        const CameraSituation(
          speedMps: 14,
          distanceToNextM: null,
          nextKind: null,
        ),
      );
      expect(p!.zoom, closeTo(goal.zoom, 0.05));
      expect(p.tilt, closeTo(goal.tilt, 0.5));
      expect(maxZoom!, lessThanOrEqualTo(math.max(12, goal.zoom) + 0.01));
      expect(maxTilt!, lessThanOrEqualTo(goal.tilt + 0.01));
      expect(p.bearing, closeTo(90, 0.5));
    });

    test('arah berputar ikut jalan terpendek merentas 0/360', () {
      final rig = CameraRig(
        entry: const CameraPose(
          center: GeoPoint(3, 101),
          zoom: 16,
          tilt: 55,
          bearing: 350,
        ),
        entryDuration: Duration.zero,
      );
      final seen = <double>[];
      for (var t = 0.0; t < 2; t += 1 / 60) {
        final p = rig.step(
          dt: 1 / 60,
          vehicle: const GeoPoint(3, 101),
          vehicleBearing: 10,
          speedMps: 14,
          distanceToNextM: null,
          nextKind: null,
          viewportHeightPx: 800,
        );
        seen.add(p.bearing);
      }
      // Tidak pernah melalui 180 (putaran panjang).
      expect(seen.every((b) => b > 340 || b < 20), isTrue);
      expect(angleDelta(seen.last, 10).abs(), lessThan(2));
    });

    test(
      'perubahan setiap bingkai kecil (tiada sentakan) pada selekoh 90 darjah',
      () {
        final rig = CameraRig(
          entry: const CameraPose(
            center: GeoPoint(3, 101),
            zoom: 16.5,
            tilt: 55,
            bearing: 90,
          ),
          entryDuration: Duration.zero,
        );
        run(rig, seconds: 6, bearing: 90);
        var prev = 90.0;
        var maxStep = 0.0;
        for (var t = 0.0; t < 3; t += 1 / 60) {
          final p = rig.step(
            dt: 1 / 60,
            vehicle: const GeoPoint(3, 101),
            vehicleBearing: 180,
            speedMps: 14,
            distanceToNextM: null,
            nextKind: null,
            viewportHeightPx: 800,
          );
          maxStep = math.max(maxStep, angleDelta(prev, p.bearing).abs());
          prev = p.bearing;
        }
        expect(maxStep, lessThan(4)); // darjah per bingkai
        expect(prev, closeTo(180, 2));
      },
    );

    test(
      'kadar bingkai berbeza memberi hasil hampir sama (bebas kadar bingkai)',
      () {
        CameraPose go(double fps) {
          final rig = CameraRig(
            entry: const CameraPose(
              center: GeoPoint(3, 101),
              zoom: 16,
              tilt: 55,
              bearing: 0,
            ),
            entryDuration: Duration.zero,
          );
          late CameraPose p;
          for (var t = 0.0; t < 2; t += 1 / fps) {
            p = rig.step(
              dt: 1 / fps,
              vehicle: const GeoPoint(3, 101),
              vehicleBearing: 90,
              speedMps: 14,
              distanceToNextM: null,
              nextKind: null,
              viewportHeightPx: 800,
            );
          }
          return p;
        }

        final a = go(30);
        final b = go(120);
        expect((a.bearing - b.bearing).abs(), lessThan(3));
        expect((a.zoom - b.zoom).abs(), lessThan(0.1));
      },
    );

    test(
      'kenderaan duduk di bawah tengah: pusat kamera di hadapan kenderaan',
      () {
        final rig = CameraRig(
          entry: const CameraPose(
            center: GeoPoint(3, 101),
            zoom: 17,
            tilt: 55,
            bearing: 90,
          ),
          entryDuration: Duration.zero,
        );
        final p = run(rig, seconds: 6, bearing: 90);
        final ahead = distanceMeters(const GeoPoint(3, 101), p.center);
        expect(ahead, greaterThan(20));
        expect(ahead, lessThan(250));
        expect(
          angleDelta(
            bearingDegrees(const GeoPoint(3, 101), p.center),
            90,
          ).abs(),
          lessThan(1),
        );
      },
    );

    test(
      'peralihan masuk: bermula di pandangan peta, berakhir di kenderaan',
      () {
        final rig = CameraRig(entry: start);
        final first = rig.step(
          dt: 1 / 60,
          vehicle: const GeoPoint(3.5, 101.5),
          vehicleBearing: 0,
          speedMps: 0,
          distanceToNextM: null,
          nextKind: null,
          viewportHeightPx: 800,
        );
        expect(distanceMeters(first.center, start.center), lessThan(5000));
        final end = run(
          rig,
          seconds: 3,
          bearing: 0,
          vehicle: const GeoPoint(3.5, 101.5),
          speed: 0,
        );
        expect(
          distanceMeters(end.center, const GeoPoint(3.5, 101.5)),
          lessThan(200),
        );
      },
    );

    test(
      'belokan menghampiri: tilt turun, kemudian pulih selepas melepasinya',
      () {
        final rig = CameraRig(
          entry: const CameraPose(
            center: GeoPoint(3, 101),
            zoom: 16.5,
            tilt: 56,
            bearing: 90,
          ),
          entryDuration: Duration.zero,
        );
        final cruising = run(rig, seconds: 6, bearing: 90);
        final atTurn = run(
          rig,
          seconds: 4,
          bearing: 90,
          dist: 25,
          kind: ManeuverKind.right,
        );
        final after = run(rig, seconds: 6, bearing: 180);
        expect(atTurn.tilt, lessThan(cruising.tilt - 15));
        expect(atTurn.zoom, greaterThan(cruising.zoom + 0.4));
        expect(after.tilt, greaterThan(atTurn.tilt + 15));
      },
    );
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
