import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/domain/vehicle_model.dart';
import 'package:fgmap/features/navigation/presentation/navigation_frame_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';

void main() {
  late FakeClock clock;
  late FakeCamera camera;
  late NavigationSession session;
  late NavRoute route;
  late NavigationFrameDriver driver;

  void primeSession() {
    for (final f in driveFixes(route, speedMps: 14, endM: 120)) {
      clock.now = f.timestamp!;
      session.onFix(f);
    }
  }

  setUp(() {
    route = NavRoute(lShapedRoute(legM: 1500));
    clock = FakeClock();
    camera = FakeCamera();
    session = NavigationSession(
      route: route,
      language: VoiceLanguage.ms,
      clock: clock.call,
    );
    primeSession();
    driver = NavigationFrameDriver(
      camera: camera,
      poseAt: session.poseAt,
      progress: () => session.progress,
      viewportHeight: () => 800,
      cameraMode: () => NavCameraMode.auto,
      clock: clock.call,
    );
    addTearDown(driver.dispose);
  });

  Duration t(int ms) => Duration(milliseconds: ms);

  test('setiap bingkai: marker kenderaan dan kamera dikemas kini', () {
    for (var i = 0; i < 30; i++) {
      clock.advance(const Duration(milliseconds: 16));
      driver.step(t(16 * i));
    }
    expect(camera.vehicleCalls.length, 30);
    expect(camera.moveToCalls.length, 30);
    expect(camera.vehicleCalls.last!.bearing, closeTo(90, 2));
  });

  test(
    'kamera masuk dengan peralihan dari pose peta dan menghala ke arah gerakan',
    () {
      for (var i = 0; i < 200; i++) {
        clock.advance(const Duration(milliseconds: 16));
        driver.step(t(16 * i));
      }
      final last = camera.moveToCalls.last;
      expect(last.bearing, closeTo(90, 3));
      expect(last.tilt, greaterThan(40));
      expect(last.zoom, greaterThan(15));
      // Pusat kamera di hadapan kenderaan (kenderaan di bahagian bawah skrin).
      final car = camera.vehicleCalls.last!.point;
      expect(distanceMeters(car, last.center), greaterThan(10));
    },
  );

  test('nudgeZoom: zum dilaras SAMBIL kamera terus mengikut kenderaan', () {
    var i = 0;
    void frames(int n) {
      for (var k = 0; k < n; k++) {
        clock.advance(const Duration(milliseconds: 16));
        driver.step(t(16 * i++));
      }
    }

    frames(400);
    final before = camera.moveToCalls.last.zoom;
    driver.nudgeZoom(1);
    frames(400);
    expect(driver.follow.value, NavFollow.following);
    expect(camera.moveToCalls.last.zoom, closeTo(before + 1, 0.1));

    // Dihad: tekan berkali-kali tidak melarikan zum tanpa had.
    driver.nudgeZoom(20);
    expect(driver.zoomBias, 2);
    driver.nudgeZoom(-20);
    expect(driver.zoomBias, -3);
  });

  test('tiada lonjakan antara bingkai berturutan (kenderaan dan kamera)', () {
    for (var i = 0; i < 300; i++) {
      clock.advance(const Duration(milliseconds: 16));
      driver.step(t(16 * i));
    }
    var maxCarStep = 0.0;
    var maxCamStep = 0.0;
    for (var i = 260; i < camera.moveToCalls.length; i++) {
      maxCarStep =
          maxCarStep >
              distanceMeters(
                camera.vehicleCalls[i]!.point,
                camera.vehicleCalls[i - 1]!.point,
              )
          ? maxCarStep
          : distanceMeters(
              camera.vehicleCalls[i]!.point,
              camera.vehicleCalls[i - 1]!.point,
            );
      final d = distanceMeters(
        camera.moveToCalls[i].center,
        camera.moveToCalls[i - 1].center,
      );
      maxCamStep = maxCamStep > d ? maxCamStep : d;
    }
    expect(maxCarStep, lessThan(0.6)); // 14 m/s x 16 ms ~ 0.22 m
    expect(maxCamStep, lessThan(0.8));
  });

  test(
    'pengguna menggerakkan peta: kamera berhenti mengikut, kenderaan terus bergerak',
    () {
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(milliseconds: 16));
        driver.step(t(16 * i));
      }
      driver.userInteracted();
      expect(driver.follow.value, NavFollow.free);
      final moves = camera.moveToCalls.length;
      final cars = camera.vehicleCalls.length;
      for (var i = 10; i < 20; i++) {
        clock.advance(const Duration(milliseconds: 16));
        driver.step(t(16 * i));
      }
      expect(camera.moveToCalls.length, moves);
      expect(camera.vehicleCalls.length, cars + 10);
    },
  );

  test('auto-pusat selepas tamat masa tanpa sentuhan', () {
    driver.userInteracted();
    clock.advance(const Duration(seconds: 5));
    driver.step(t(0));
    expect(driver.follow.value, NavFollow.free);
    clock.advance(const Duration(seconds: 6));
    driver.step(t(16));
    expect(driver.follow.value, NavFollow.following);
  });

  test('recenter(): kembali mengikut, terbang masuk dari pose peta semasa', () {
    for (var i = 0; i < 100; i++) {
      clock.advance(const Duration(milliseconds: 16));
      driver.step(t(16 * i));
    }
    driver.userInteracted();
    // Pengguna menggeser peta jauh dan memutarnya.
    camera.pose = const CameraPose(
      center: GeoPoint(3.5, 101.5),
      zoom: 12,
      tilt: 0,
      bearing: 200,
    );
    driver.recenter();
    clock.advance(const Duration(milliseconds: 16));
    driver.step(t(1600));
    final first = camera.moveToCalls.last;
    expect(
      distanceMeters(first.center, const GeoPoint(3.5, 101.5)),
      lessThan(20000),
    );
    expect(
      (first.zoom - 12).abs(),
      lessThan(0.3),
    ); // bermula dekat pandangan pengguna
    for (var i = 0; i < 200; i++) {
      clock.advance(const Duration(milliseconds: 16));
      driver.step(t(1616 + 16 * i));
    }
    expect(camera.moveToCalls.last.zoom, greaterThan(15));
    expect(angleDelta(camera.moveToCalls.last.bearing, 90).abs(), lessThan(5));
  });

  test('overview: fitTo laluan dan kamera tidak diganggu', () {
    driver.showOverview(route.points, padding: const EdgeInsets.all(20));
    expect(driver.follow.value, NavFollow.overview);
    expect(camera.fitToCalls, hasLength(1));
    final moves = camera.moveToCalls.length;
    clock.advance(const Duration(milliseconds: 16));
    driver.step(t(16));
    expect(camera.moveToCalls.length, moves);
  });

  group('kenderaan berhenti (jimat CPU/bateri pada peranti lemah)', () {
    NavigationFrameDriver stoppedDriver() {
      final d = NavigationFrameDriver(
        camera: camera,
        // Pose tetap: kenderaan berhenti di lampu isyarat.
        poseAt: (_) => const VehiclePose(
          point: GeoPoint(3.14, 101.69),
          bearing: 90,
          alongM: 100,
          speedMps: 0,
          onRoute: true,
        ),
        progress: () => null,
        viewportHeight: () => 800,
        cameraMode: () => NavCameraMode.flat,
        clock: clock.call,
        reduceMotion: true,
      );
      addTearDown(d.dispose);
      return d;
    }

    void run(NavigationFrameDriver d, int frames, {int from = 0}) {
      for (var i = from; i < from + frames; i++) {
        clock.advance(const Duration(milliseconds: 16));
        d.step(t(16 * i));
      }
    }

    test('pose tidak berubah: panggilan platform digugurkan', () {
      final d = stoppedDriver();
      run(
        d,
        600,
      ); // kamera meluncur masuk ke sasaran dahulu (pergerakan sebenar)
      final cars = camera.vehicleCalls.length;
      final moves = camera.moveToCalls.length;
      run(d, 300, from: 600); // ~5 saat berhenti
      // Sebelum ini 300 + 300 panggilan platform; kini hanya degupan (~1 setiap 30 bingkai).
      expect(camera.vehicleCalls.length - cars, lessThanOrEqualTo(11));
      expect(camera.moveToCalls.length - moves, lessThanOrEqualTo(11));
      expect(camera.vehicleCalls, isNotEmpty);
      expect(camera.moveToCalls, isNotEmpty);
    });

    test(
      'degupan: pose sama dihantar semula berkala (panggilan lama mungkin digugurkan platform)',
      () {
        final d = stoppedDriver();
        run(d, 100);
        final first = camera.moveToCalls.length;
        run(d, 100, from: 100);
        expect(camera.moveToCalls.length, greaterThan(first));
      },
    );

    test(
      'recenter() selepas pengguna menggeser peta: kamera dipulangkan walaupun pose sama',
      () {
        final d = stoppedDriver();
        run(d, 200);
        d.userInteracted();
        camera.pose = const CameraPose(
          center: GeoPoint(3.5, 101.5),
          zoom: 12,
          tilt: 0,
          bearing: 200,
        );
        d.recenter();
        final before = camera.moveToCalls.length;
        run(d, 1, from: 200);
        expect(
          camera.moveToCalls.length,
          before + 1,
          reason: 'bingkai pertama selepas pusat semula mesti dihantar',
        );
      },
    );

    test('kenderaan bergerak semula: dikemas kini setiap bingkai lagi', () {
      var moving = false;
      var lat = 3.14;
      final d = NavigationFrameDriver(
        camera: camera,
        poseAt: (_) {
          if (moving) lat += 0.000002; // ~0.2 m / bingkai
          return VehiclePose(
            point: GeoPoint(lat, 101.69),
            bearing: 0,
            alongM: 100,
            speedMps: moving ? 14 : 0,
            onRoute: true,
          );
        },
        progress: () => null,
        viewportHeight: () => 800,
        cameraMode: () => NavCameraMode.flat,
        clock: clock.call,
        reduceMotion: true,
      );
      addTearDown(d.dispose);
      run(d, 100);
      moving = true;
      final cars = camera.vehicleCalls.length;
      run(d, 30, from: 100);
      expect(camera.vehicleCalls.length, cars + 30);
    });
  });

  test('tiada pose (navigasi belum bermula): tidak berbuat apa-apa', () {
    final d = NavigationFrameDriver(
      camera: camera,
      poseAt: (_) => null,
      progress: () => null,
      viewportHeight: () => 800,
      cameraMode: () => NavCameraMode.auto,
      clock: clock.call,
    );
    addTearDown(d.dispose);
    d.step(t(0));
    expect(camera.moveToCalls, isEmpty);
    expect(camera.vehicleCalls, isEmpty);
  });
}
