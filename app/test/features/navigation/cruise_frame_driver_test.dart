import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/map_view.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/presentation/cruise_frame_driver.dart';
import 'package:fgmap/features/navigation/presentation/navigation_frame_driver.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';

void main() {
  const point = GeoPoint(3.14, 101.68);

  CruiseFrameDriver buildDriver({
    required FakeCamera camera,
    required FakeClock clock,
    required CruiseFix? Function() sample,
    NavCameraMode mode = NavCameraMode.auto,
    bool reduceMotion = false,
  }) {
    final driver = CruiseFrameDriver(
      camera: camera,
      sample: sample,
      viewportHeight: () => 800,
      viewportWidth: () => 400,
      cameraMode: () => mode,
      clock: clock.call,
      reduceMotion: reduceMotion,
      autoRecenter: const Duration(seconds: 10),
    );
    addTearDown(driver.dispose);
    return driver;
  }

  void runFrames(CruiseFrameDriver driver, FakeClock clock, int n) {
    var tick = 0;
    for (var i = 0; i < n; i++) {
      tick++;
      clock.advance(const Duration(milliseconds: 16));
      driver.step(Duration(milliseconds: 16 * tick));
    }
  }

  test(
    'pan bebas → recenter mengembalikan follow dan puck 2D (tiada overlay 3D)',
    () {
      final clock = FakeClock()..now = DateTime.utc(2026, 1, 1, 12);
      final camera = FakeCamera()
        ..pose = const CameraPose(
          center: point,
          zoom: 17,
          tilt: 0,
          bearing: 90,
        );
      final fix = CruiseFix(
        point: point,
        bearing: 90,
        speedMps: 12,
        time: clock.now,
      );
      final driver = buildDriver(
        camera: camera,
        clock: clock,
        sample: () => fix,
      );

      runFrames(driver, clock, 20);
      expect(driver.follow.value, NavFollow.following);
      expect(driver.car.value, isNull);
      expect(camera.vehicleCalls, isNotEmpty);
      expect(camera.moveToCalls.last.tilt, lessThan(5));

      driver.userInteracted();
      expect(driver.follow.value, NavFollow.free);
      runFrames(driver, clock, 5);
      expect(driver.car.value, isNull);
      expect(camera.vehicleCalls, isNotEmpty);

      driver.recenter();
      expect(driver.follow.value, NavFollow.following);
      runFrames(driver, clock, 120);
      expect(driver.car.value, isNull);
      expect(camera.moveToCalls.last.tilt, lessThan(5));
      expect(camera.vehicleCalls.last, isNotNull);
    },
  );

  test('mod navigasi diabaikan: free-ride sentiasa tilt ~0', () {
    final clock = FakeClock()..now = DateTime.utc(2026, 1, 1, 12);
    final fix = CruiseFix(
      point: point,
      bearing: 0,
      speedMps: 14,
      time: clock.now,
    );

    for (final mode in NavCameraMode.values) {
      final camera = FakeCamera()
        ..pose = const CameraPose(
          center: point,
          zoom: 17,
          tilt: 55,
          bearing: 0,
        );
      final driver = buildDriver(
        camera: camera,
        clock: clock,
        sample: () => fix,
        mode: mode,
        reduceMotion: true,
      );
      runFrames(driver, clock, 90);
      expect(camera.moveToCalls.last.tilt, lessThan(5), reason: '$mode');
      expect(driver.car.value, isNull, reason: '$mode');
    }
  });

  test('auto-recenter selepas pan walaupun sample null sekejap', () {
    final clock = FakeClock()..now = DateTime.utc(2026, 1, 1, 12);
    final camera = FakeCamera()
      ..pose = const CameraPose(center: point, zoom: 17, tilt: 0, bearing: 10);
    CruiseFix? fix = CruiseFix(
      point: point,
      bearing: 10,
      speedMps: 10,
      time: clock.now,
    );
    final driver = buildDriver(
      camera: camera,
      clock: clock,
      sample: () => fix,
      mode: NavCameraMode.auto,
      reduceMotion: true,
    );
    runFrames(driver, clock, 10);
    driver.userInteracted();
    expect(driver.follow.value, NavFollow.free);
    fix = null;
    clock.advance(const Duration(seconds: 11));
    driver.step(const Duration(seconds: 11));
    expect(driver.follow.value, NavFollow.following);
  });

  test('parseMatchedEnd: matched_points atau shape', () {
    expect(
      parseMatchedEnd({
        'matched_points': [
          {'lat': 3.1, 'lon': 101.6},
          {'lat': 3.2, 'lon': 101.7},
        ],
      }),
      const GeoPoint(3.2, 101.7),
    );
    final fromShape = parseMatchedEnd({
      'shape': encodePolyline6(const [
        GeoPoint(3.0, 101.0),
        GeoPoint(3.05, 101.05),
      ]),
    });
    expect(fromShape!.lat, closeTo(3.05, 1e-5));
    expect(fromShape.lng, closeTo(101.05, 1e-5));
    expect(parseMatchedEnd({'edges': []}), isNull);
  });
}
