import 'dart:math' as math;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/data/location_sources.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/presentation/navigation_frame_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';

/// Peralihan masuk navigasi (laporan penguji 2026-11-02: kamera dan kereta 3D tidak licin selepas
/// "Mula"). Kamera palsu bermula pada pandangan pratonton laluan, seperti di app.
void main() {
  late FakeClock clock;
  late FakeCamera camera;
  late NavigationSession session;
  late NavRoute route;
  late NavigationFrameDriver driver;

  setUp(() {
    route = NavRoute(lShapedRoute(legM: 1500));
    clock = FakeClock();
    camera = FakeCamera()
      ..pose = CameraPose(
        // Pratonton: pusat laluan, zum ikhtisar.
        center: destinationPoint(const GeoPoint(3.0, 101.0), 120, 1100),
        zoom: 13,
        tilt: 0,
        bearing: 0,
      );
    session = NavigationSession(
      route: route,
      language: VoiceLanguage.ms,
      clock: clock.call,
    );
    driver = NavigationFrameDriver(
      camera: camera,
      poseAt: session.poseAt,
      progress: () => session.progress,
      route: () => route,
      viewportHeight: () => 800,
      cameraMode: () => NavCameraMode.auto,
      clock: clock.call,
    );
    addTearDown(driver.dispose);
  });

  var frame = 0;
  void frames(int count) {
    for (var i = 0; i < count; i++) {
      clock.advance(const Duration(milliseconds: 16));
      driver.step(Duration(milliseconds: 16 * frame++));
    }
  }

  void firstFix() {
    final f = driveFixes(route, speedMps: 14, endM: 0).first;
    clock.now = f.timestamp!;
    session.onFix(f);
  }

  test(
    'sebelum fix GPS pertama: kamera kekal pada pratonton (tiada terbang ke 0,0)',
    () {
      frame = 0;
      frames(90);
      expect(session.poseAt(clock.now), isNull);
      expect(camera.moveToCalls, isEmpty);
      expect(camera.vehicleCalls, isEmpty);
      expect(driver.car.value, isNull);
    },
  );

  test(
    'peralihan masuk: satu gerakan licin; zum dan condongan tiba bersama pusat',
    () {
      frame = 0;
      final preview = camera.pose!;
      frames(10); // menunggu GPS
      firstFix();
      final start = camera.moveToCalls.length;
      frames(240);
      final sent = camera.moveToCalls.sublist(start);
      expect(sent, isNotEmpty);
      // Tiada lompatan jauh dari pratonton.
      expect(distanceMeters(sent.first.center, preview.center), lessThan(30));

      var maxSlidePx = 0.0;
      for (var i = 1; i < sent.length; i++) {
        final a = sent[i - 1], b = sent[i];
        final px =
            distanceMeters(a.center, b.center) /
            metersPerPixel(b.zoom, b.center.lat);
        maxSlidePx = math.max(maxSlidePx, px);
        expect(
          (b.zoom - a.zoom).abs(),
          lessThan(0.12),
          reason: 'zum melompat pada bingkai $i',
        );
        expect((b.tilt - a.tilt).abs(), lessThan(1.6));
      }
      expect(maxSlidePx, lessThan(40));

      // Selepas tiba (2.2 s maksimum), kamera sudah mantap: tiada zum/condongan yang masih mengejar.
      final settled = sent.sublist(sent.length - 60);
      for (var i = 1; i < settled.length; i++) {
        expect((settled[i].zoom - settled[i - 1].zoom).abs(), lessThan(0.003));
        expect((settled[i].tilt - settled[i - 1].tilt).abs(), lessThan(0.05));
      }

      expect(driver.car.value!.opacity, 1);
    },
  );

  test('kereta 3D tidak kelihatan semasa jalan masih meluncur', () {
    frame = 0;
    firstFix();
    CameraPose? last;
    var previousOpacity = 0.0;
    for (var i = 0; i < 200; i++) {
      frames(1);
      final pose = camera.moveToCalls.last;
      final opacity = driver.car.value?.opacity ?? 0;
      expect(opacity, greaterThanOrEqualTo(previousOpacity - 1e-9));
      previousOpacity = opacity;
      if (last != null && opacity > 0.3) {
        final px =
            distanceMeters(last.center, pose.center) /
            metersPerPixel(pose.zoom, pose.center.lat);
        expect(px, lessThan(4), reason: 'bingkai $i, kelegapan $opacity');
      }
      last = pose;
    }
    expect(previousOpacity, 1);
  });

  test(
    'tempoh masuk: pendek bila dekat, lebih panjang bila jauh, maksimum 2.2 s',
    () {
      const car = GeoPoint(3.0, 101.0);
      Duration d(double km, double zoom) => CameraRig.entryDurationFor(
        from: CameraPose(
          center: destinationPoint(car, 0, km * 1000),
          zoom: zoom,
          tilt: 0,
          bearing: 0,
        ),
        vehicle: car,
        speedMps: 0,
        viewportHeightPx: 800,
      );
      expect(d(0, 18.5), const Duration(milliseconds: 900));
      expect(d(1, 14), greaterThan(d(0.1, 17)));
      expect(d(80, 9), const Duration(milliseconds: 2200));
    },
  );

  test('benih GPS untuk navigasi: hanya fix segar dan tepat', () {
    final now = DateTime.utc(2026, 11, 2, 12);
    LocationFix fix({double acc = 8, int ageS = 2}) => LocationFix(
      point: const GeoPoint(3, 101),
      accuracyMeters: acc,
      timestamp: now.subtract(Duration(seconds: ageS)),
    );
    expect(DeviceLocationSource.isUsableSeed(fix(), now), isTrue);
    expect(DeviceLocationSource.isUsableSeed(fix(acc: 60), now), isFalse);
    expect(DeviceLocationSource.isUsableSeed(fix(ageS: 40), now), isFalse);
  });
}
