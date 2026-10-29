import 'dart:math' as math;

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/vehicle_model.dart';
import 'package:fgmap/features/navigation/presentation/cruise_frame_driver.dart';
import 'package:fgmap/features/navigation/presentation/navigation_frame_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';

/// Jumlah pusingan bertanda (jalan pendek setiap langkah) dan langkah terbesar.
({double signed, double maxStep}) _turn(List<double> bearings) {
  var signed = 0.0;
  var maxStep = 0.0;
  for (var i = 1; i < bearings.length; i++) {
    final d = angleDelta(bearings[i - 1], bearings[i]);
    signed += d;
    maxStep = math.max(maxStep, d.abs());
  }
  return (signed: signed, maxStep: maxStep);
}

void _expectShortTurn(
  List<double> bearings, {
  required double from,
  required double to,
  required String reason,
}) {
  final turn = _turn(bearings);
  final want = angleDelta(from, to);
  expect(
    turn.maxStep,
    lessThan(30),
    reason: '$reason: satu langkah ${turn.maxStep.toStringAsFixed(1)}°',
  );
  expect(
    turn.signed,
    closeTo(want, 12),
    reason:
        '$reason: jumlah ${turn.signed.toStringAsFixed(1)}° '
        '(jalan panjang ialah ${angleDelta(to, from).toStringAsFixed(1)}°)',
  );
  expect(angleDelta(bearings.last, to).abs(), lessThan(5), reason: reason);
}

void main() {
  const point = GeoPoint(3.14, 101.69);

  test('followHeading: 359° ke 1° ialah +2°, hingar perlahan dipegang', () {
    expect(
      angleDelta(359, followHeading(359, 1, speedMps: 12, known: true)),
      closeTo(2, 1e-9),
    );
    expect(
      angleDelta(1, followHeading(1, 359, speedMps: 12, known: true)),
      closeTo(-2, 1e-9),
    );
    expect(followHeading(40, 220, speedMps: 1.2, known: true), 40);
    expect(followHeading(40, 220, speedMps: 0, known: true), 40);
    // Kelajuan tinggi: lawan arah diambil sekali, tetapi tetap jalan pendek.
    expect(
      angleDelta(10, followHeading(10, 200, speedMps: 14, known: true)).abs(),
      lessThanOrEqualTo(180),
    );
  });

  test('kamera: 359° ke 1° tidak melalui jalan panjang', () {
    final rig = CameraRig(
      entry: const CameraPose(center: point, zoom: 17, tilt: 55, bearing: 359),
      entryDuration: Duration.zero,
    );
    final bearings = <double>[359];
    for (var i = 0; i < 20; i++) {
      bearings.add(
        rig
            .step(
              dt: 1 / 30,
              vehicle: point,
              vehicleBearing: 359,
              speedMps: 12,
              distanceToNextM: null,
              nextKind: null,
              viewportHeightPx: 800,
            )
            .bearing,
      );
    }
    for (var i = 0; i < 90; i++) {
      bearings.add(
        rig
            .step(
              dt: 1 / 30,
              vehicle: point,
              vehicleBearing: 1,
              speedMps: 12,
              distanceToNextM: null,
              nextKind: null,
              viewportHeightPx: 800,
            )
            .bearing,
      );
    }
    _expectShortTurn(bearings, from: 359, to: 1, reason: 'rig 359→1');
  });

  test(
    'kamera dipulihkan pada 350° mengejar 10° melalui +20°, bukan −340°',
    () {
      final rig = CameraRig(
        entry: const CameraPose(
          center: point,
          zoom: 17,
          tilt: 55,
          bearing: 350,
        ),
        entryDuration: Duration.zero,
      );
      final bearings = <double>[350];
      for (var i = 0; i < 90; i++) {
        bearings.add(
          rig
              .step(
                dt: 1 / 30,
                vehicle: point,
                vehicleBearing: 10,
                speedMps: 12,
                distanceToNextM: null,
                nextKind: null,
                viewportHeightPx: 800,
              )
              .bearing,
        );
      }
      _expectShortTurn(
        bearings,
        from: 350,
        to: 10,
        reason: 'bearing dipulihkan',
      );
    },
  );

  test(
    'navigasi: selepas resume kereta tidak berpusing dan kamera tidak mengorbit',
    () {
      final clock = FakeClock()..now = DateTime.utc(2026, 1, 1, 12);
      final camera = FakeCamera()
        ..pose = const CameraPose(
          center: point,
          zoom: 17,
          tilt: 55,
          bearing: 90,
        )
        ..cameraLatency = const Duration(milliseconds: 80);
      var bearing = 90.0;
      final driver = NavigationFrameDriver(
        camera: camera,
        poseAt: (_) => VehiclePose(
          point: point,
          bearing: bearing,
          speedMps: 12,
          onRoute: true,
          alongM: 100,
        ),
        progress: () => null,
        viewportHeight: () => 800,
        cameraMode: () => NavCameraMode.tilted,
        clock: clock.call,
        reduceMotion: true,
      );
      addTearDown(driver.dispose);

      var elapsed = Duration.zero;
      const frame = Duration(milliseconds: 16);
      for (var i = 0; i < 90; i++) {
        clock.advance(frame);
        elapsed += frame;
        driver.step(elapsed);
      }
      final before = camera.moveToCalls.last.bearing;
      expect(angleDelta(before, 90).abs(), lessThan(5));
      expect(driver.car.value!.yawDeg.abs(), lessThan(8));

      // Pemandu membelok semasa app di latar. Ticker dimulakan semula: elapsed jatuh.
      bearing = 120;
      driver.step(const Duration(milliseconds: 16));
      final yaw = driver.car.value!.yawDeg;
      expect(
        yaw.abs(),
        lessThan(80),
        reason: 'kereta berpusing selepas resume',
      );

      final after = <double>[before];
      for (var i = 0; i < 90; i++) {
        clock.advance(frame);
        driver.step(frame * (i + 2));
        after.add(camera.moveToCalls.last.bearing);
        expect(driver.car.value!.yawDeg.abs(), lessThan(80));
      }
      _expectShortTurn(
        after,
        from: before,
        to: 120,
        reason: 'kamera selepas resume',
      );
      expect(driver.car.value!.yawDeg.abs(), lessThan(8));
    },
  );

  test(
    'memandu bebas: 359° ke 1° pendek, hingar perlahan tidak memutar kereta',
    () {
      final clock = FakeClock()..now = DateTime.utc(2026, 1, 1, 12);
      final camera = FakeCamera()
        ..pose = const CameraPose(
          center: point,
          zoom: 17,
          tilt: 55,
          bearing: 20,
        );
      var bearing = 20.0;
      var speed = 12.0;
      var fixTime = clock.now;
      final driver = CruiseFrameDriver(
        camera: camera,
        sample: () => CruiseFix(
          point: point,
          bearing: bearing,
          speedMps: speed,
          time: fixTime,
        ),
        viewportHeight: () => 800,
        cameraMode: () => NavCameraMode.auto,
        clock: clock.call,
        reduceMotion: true,
      );
      addTearDown(driver.dispose);

      var tick = 0;
      void frames(int n) {
        for (var i = 0; i < n; i++) {
          tick++;
          clock.advance(const Duration(milliseconds: 16));
          driver.step(const Duration(milliseconds: 16) * tick);
        }
      }

      frames(40);
      expect(
        angleDelta(camera.moveToCalls.last.bearing, 20).abs(),
        lessThan(5),
      );

      speed = 1.2;
      for (final noisy in [200.0, 90.0, 300.0, 10.0]) {
        bearing = noisy;
        fixTime = fixTime.add(const Duration(seconds: 1));
        frames(20);
      }
      expect(
        angleDelta(camera.moveToCalls.last.bearing, 20).abs(),
        lessThan(8),
        reason: 'hingar GPS perlahan memutar kamera',
      );
      // Free-ride: tiada overlay 3D; penanda peta sahaja.
      expect(driver.car.value, isNull);

      speed = 12;
      bearing = 359;
      fixTime = fixTime.add(const Duration(seconds: 1));
      camera.pose = const CameraPose(
        center: point,
        zoom: 17,
        tilt: 55,
        bearing: 359,
      );
      driver.recenter();
      frames(30);
      final started = camera.moveToCalls.last.bearing;
      bearing = 1;
      fixTime = fixTime.add(const Duration(seconds: 1));
      final turned = <double>[started];
      for (var i = 0; i < 90; i++) {
        frames(1);
        turned.add(camera.moveToCalls.last.bearing);
      }
      _expectShortTurn(turned, from: started, to: 1, reason: 'cruise 359→1');
      expect(driver.car.value, isNull);
      expect(camera.moveToCalls.last.tilt, lessThan(5));
    },
  );

  test(
    'di luar laluan, heading perlahan tidak menggantikan arah perjalanan',
    () {
      final route = NavRoute(lShapedRoute());
      final v = VehicleModel(route);
      final t0 = DateTime.utc(2026, 1, 1, 12);
      v.onRouteFix(alongM: 100, speedMps: 12, time: t0);
      v.onFreeFix(
        point: const GeoPoint(3.5, 101.5),
        bearing: 33,
        speedMps: 12,
        time: t0.add(const Duration(seconds: 1)),
      );
      expect(v.poseAt(t0.add(const Duration(seconds: 1))).bearing, 33);
      v.onFreeFix(
        point: const GeoPoint(3.5, 101.5),
        bearing: 300,
        speedMps: 1,
        time: t0.add(const Duration(seconds: 2)),
      );
      expect(v.poseAt(t0.add(const Duration(seconds: 2))).bearing, 33);
      v.onFreeFix(
        point: const GeoPoint(3.5, 101.5),
        bearing: 1,
        speedMps: 12,
        time: t0.add(const Duration(seconds: 3)),
      );
      // 33° ke 1° ialah −32°, bukan +328° yang dipotong jadi separuh pusingan.
      expect(
        v.poseAt(t0.add(const Duration(seconds: 3))).bearing,
        closeTo(1, 1e-6),
      );
    },
  );
}
