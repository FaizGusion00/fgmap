import 'dart:math' as math;

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/data/location_sources.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/presentation/navigation_frame_driver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fgmap/features/map/presentation/map_view.dart'
    show VehicleMarker;
import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';

/// Ujian "rasa": memandu seluruh laluan sebenar KLCC -> KLIA pada 60 fps melalui sesi, model
/// kenderaan dan pemacu kamera, kemudian mengukur kelicinan. Ini menggantikan penilaian mata
/// dengan ambang yang boleh diuji: kamera tidak boleh tersentak, bergoyang atau terlajak.
void main() {
  final route = loadFixtureNavRoute();

  test(
    'pemanduan penuh pada 60 fps: kamera licin, stabil, dan tepat pada kenderaan',
    () {
      final clock = FakeClock();
      final camera = FakeCamera();
      final session = NavigationSession(
        route: route,
        language: VoiceLanguage.ms,
        clock: clock.call,
      );
      final driver = NavigationFrameDriver(
        camera: camera,
        poseAt: session.poseAt,
        progress: () => session.progress,
        viewportHeight: () => 844,
        cameraMode: () => NavCameraMode.auto,
        clock: clock.call,
      );
      addTearDown(driver.dispose);

      final fixes = simulateDrive(route);
      final start = fixes.first.timestamp!;
      var nextFix = 0;
      const frameDt = Duration(microseconds: 16667);
      var elapsed = Duration.zero;
      clock.now = start;

      final frames = <({CameraPose cam, VehicleMarker car, double speed})>[];
      final end = fixes.last.timestamp!;
      var fixedAlong = 0.0;
      while (clock.now.isBefore(end.add(const Duration(seconds: 2)))) {
        while (nextFix < fixes.length &&
            !fixes[nextFix].timestamp!.isAfter(clock.now)) {
          final f = fixes[nextFix++];
          final u = session.onFix(f);
          if (u != null) fixedAlong = u.progress.alongM;
        }
        driver.step(elapsed);
        frames.add((
          cam: camera.moveToCalls.last,
          car: camera.vehicleCalls.last!,
          speed: session.progress?.speedMps ?? 0,
        ));
        clock.advance(frameDt);
        elapsed += frameDt;
      }
      expect(fixedAlong, greaterThan(route.totalM - 60));

      // Abaikan 3 saat pertama (peralihan masuk dari peta sedia ada).
      final settled = frames.skip(180).toList();
      var maxBearingStep = 0.0;
      var maxZoomStep = 0.0;
      var maxTiltStep = 0.0;
      var maxCarStep = 0.0;
      var maxScreenJump = 0.0;
      var minForwardFrac = 0.0;
      var maxForwardFrac = -1.0;
      var maxLateralPx = 0.0;
      double? prevForwardPx;
      var tiltReversals = 0;
      var zoomReversals = 0;
      var lastTiltDir = 0;
      var lastZoomDir = 0;
      var tiltTurnFrames = 0;
      var tiltCruiseFrames = 0;
      for (var i = 1; i < settled.length; i++) {
        final a = settled[i - 1];
        final b = settled[i];
        maxBearingStep = math.max(
          maxBearingStep,
          angleDelta(a.cam.bearing, b.cam.bearing).abs(),
        );
        maxZoomStep = math.max(maxZoomStep, (b.cam.zoom - a.cam.zoom).abs());
        if ((b.cam.tilt - a.cam.tilt).abs() > maxTiltStep) {
          maxTiltStep = (b.cam.tilt - a.cam.tilt).abs();
        }
        final car = distanceMeters(a.car.point, b.car.point);
        maxCarStep = math.max(maxCarStep, car);
        // Kedudukan kenderaan pada skrin (piksel logikal) relatif kepada pusat kamera.
        final east =
            (b.car.point.lng - b.cam.center.lng) *
            111195 *
            math.cos(b.cam.center.lat * math.pi / 180);
        final north = (b.car.point.lat - b.cam.center.lat) * 111195;
        final theta = b.cam.bearing * math.pi / 180;
        final mpp = metersPerPixel(b.cam.zoom, b.cam.center.lat);
        final groundForwardPx =
            (east * math.sin(theta) + north * math.cos(theta)) / mpp;
        final lateralPx =
            (east * math.cos(theta) - north * math.sin(theta)) / mpp;
        // Kedudukan SEBENAR pada skrin: jarak di tanah dimampatkan perspektif kamera condong MapLibre
        // (altitud 1.5 x tinggi, y = A.d.cos(t) / (A - d.sin(t))). Mengukur pada satah rata
        // menyembunyikan kereta yang terlalu dekat tengah pada condongan kruis.
        const altitudePx = 1.5 * 844;
        final tiltRad = b.cam.tilt * math.pi / 180;
        final groundBehindPx = -groundForwardPx;
        final forwardPx =
            -(altitudePx *
                groundBehindPx *
                math.cos(tiltRad) /
                (altitudePx - groundBehindPx * math.sin(tiltRad)));
        if (prevForwardPx != null) {
          maxScreenJump = math.max(
            maxScreenJump,
            (forwardPx - prevForwardPx).abs(),
          );
        }
        prevForwardPx = forwardPx;
        final frac = -forwardPx / 844;
        minForwardFrac = frac < minForwardFrac || minForwardFrac == 0
            ? frac
            : minForwardFrac;
        maxForwardFrac = math.max(maxForwardFrac, frac);
        maxLateralPx = math.max(maxLateralPx, lateralPx.abs());

        final dTilt = b.cam.tilt - a.cam.tilt;
        if (dTilt.abs() > 0.02) {
          final dir = dTilt.sign.toInt();
          if (lastTiltDir != 0 && dir != lastTiltDir) tiltReversals++;
          lastTiltDir = dir;
        }
        final dZoom = b.cam.zoom - a.cam.zoom;
        if (dZoom.abs() > 0.0005) {
          final dir = dZoom.sign.toInt();
          if (lastZoomDir != 0 && dir != lastZoomDir) zoomReversals++;
          lastZoomDir = dir;
        }
        if (b.cam.tilt < 25) tiltTurnFrames++;
        if (b.cam.tilt > 50) tiltCruiseFrames++;
      }

      // Per bingkai (16.7 ms): had persepsi "licin".
      expect(maxBearingStep, lessThan(2.5), reason: 'arah tersentak');
      expect(maxZoomStep, lessThan(0.02), reason: 'zum tersentak');
      expect(maxTiltStep, lessThan(0.45), reason: 'condongan tersentak');
      // Kenderaan: tidak lebih 33 m/s x 16.7 ms = 0.55 m + sedikit pembetulan.
      expect(maxCarStep, lessThan(1.2), reason: 'kenderaan melompat');
      // Kenderaan kekal di bahagian bawah skrin, di tengah secara mendatar, dan tidak berayun-ayun.
      expect(
        maxLateralPx,
        lessThan(6),
        reason: 'kenderaan tersasar ke tepi skrin',
      );
      // Sasaran: 19% tinggi skrin di bawah tengah (carScreenOffset), pada SEMUA condongan.
      expect(
        minForwardFrac,
        greaterThan(0.16),
        reason: 'kenderaan terlalu dekat tengah',
      );
      expect(
        maxForwardFrac,
        lessThan(0.22),
        reason: 'kenderaan terlalu dekat bawah',
      );
      expect(
        maxScreenJump,
        lessThan(4),
        reason: 'kenderaan bergerak pada skrin',
      );

      // Kestabilan: zum tidak bergoyang naik-turun berulang-ulang; condongan hanya berubah untuk
      // manuver (30 manuver -> beberapa puluh pembalikan, bukan beribu).
      expect(zoomReversals, lessThan(400), reason: 'zum bergoyang');
      expect(tiltReversals, lessThan(250), reason: 'condongan bergoyang');

      // Kedua-dua gaya paparan benar-benar digunakan: 3D di jalan lurus, menegak di selekoh.
      expect(tiltCruiseFrames, greaterThan(settled.length * 0.5));
      expect(tiltTurnFrames, greaterThan(300));

      // Ketepatan: marker kenderaan sentiasa pada laluan (dalam 1.5 m) kerana dipadankan.
      var maxOffRoute = 0.0;
      for (var i = 0; i < settled.length; i += 30) {
        final p = settled[i].car.point;
        var best = double.infinity;
        // Cari segmen terdekat dalam tetingkap sekitar kedudukan (cukup untuk ujian).
        for (var j = 0; j < route.points.length - 1; j++) {
          final d = projectToSegment(
            p,
            route.points[j],
            route.points[j + 1],
          ).distanceM;
          if (d < best) best = d;
          if (best < 1) break;
        }
        maxOffRoute = math.max(maxOffRoute, best);
      }
      expect(maxOffRoute, lessThan(1.5), reason: 'kenderaan terkeluar laluan');
    },
  );
}
