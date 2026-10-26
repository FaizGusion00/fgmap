import 'dart:math' as math;

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// Model kamera MapLibre (altitud 1.5 x tinggi viewport, medan pandang ~36.87 darjah): di mana
/// kenderaan yang berada [groundPx] di belakang pusat kamera (di atas tanah) muncul pada skrin,
/// sebagai pecahan tinggi dari ATAS.
double carScreenY({
  required double groundPx,
  required double tiltDegrees,
  required double viewportPx,
}) {
  final t = tiltDegrees * math.pi / 180;
  const altitude = 1.5;
  final a = altitude * viewportPx;
  final below = a * groundPx * math.cos(t) / (a - groundPx * math.sin(t));
  return 0.5 + below / viewportPx;
}

void main() {
  group('kedudukan kenderaan pada skrin', () {
    test(
      'groundOffsetPx: kenderaan di kedudukan sama pada SEMUA condongan',
      () {
        for (final h in [600.0, 800.0, 925.0, 1100.0]) {
          for (var tilt = 0.0; tilt <= 60; tilt += 5) {
            final y = carScreenY(
              groundPx: groundOffsetPx(tilt, h),
              tiltDegrees: tilt,
              viewportPx: h,
            );
            expect(
              y,
              closeTo(0.5 + carScreenOffset, 1e-9),
              reason: 'tilt $tilt, tinggi $h',
            );
          }
        }
      },
    );

    test(
      'jarak di tanah membesar dengan condongan (perspektif memampatkannya)',
      () {
        // Kod lama MENGURANGKAN ofset bila condong sehingga kereta jatuh ke ~59% (hampir tengah)
        // pada condongan kruis 56 darjah.
        expect(
          groundOffsetPx(56, 800),
          greaterThan(groundOffsetPx(0, 800) * 1.3),
        );
        expect(groundOffsetPx(0, 800), closeTo(carScreenOffset * 800, 1e-9));
      },
    );

    CameraPose settle(
      CameraRig rig, {
      required GeoPoint car,
      required double speed,
      required NavCameraMode mode,
      double? dist,
      ManeuverKind? kind,
      double zoomBias = 0,
      double seconds = 10,
    }) {
      late CameraPose pose;
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        pose = rig.step(
          dt: 1 / 60,
          vehicle: car,
          vehicleBearing: 90,
          speedMps: speed,
          distanceToNextM: dist,
          nextKind: kind,
          viewportHeightPx: 900,
          mode: mode,
          zoomBias: zoomBias,
        );
      }
      return pose;
    }

    double screenYOf(CameraPose pose, GeoPoint car, double viewport) {
      final groundM = distanceMeters(car, pose.center);
      final px = groundM / metersPerPixel(pose.zoom, car.lat);
      return carScreenY(
        groundPx: px,
        tiltDegrees: pose.tilt,
        viewportPx: viewport,
      );
    }

    test(
      'CameraRig menghasilkan kenderaan pada ~69% skrin, apa pun mod/kelajuan/zum',
      () {
        const car = GeoPoint(3.1, 101.7);
        for (final mode in NavCameraMode.values) {
          for (final speed in [0.0, 8.0, 14.0, 25.0, 33.0]) {
            final rig = CameraRig(
              entry: const CameraPose(
                center: car,
                zoom: 15,
                tilt: 0,
                bearing: 90,
              ),
              entryDuration: Duration.zero,
            );
            final pose = settle(rig, car: car, speed: speed, mode: mode);
            final y = screenYOf(pose, car, 900);
            expect(
              y,
              closeTo(0.5 + carScreenOffset, 0.01),
              reason:
                  '$mode @ $speed m/s (tilt ${pose.tilt.toStringAsFixed(0)})',
            );
          }
        }
      },
    );

    test(
      'kedudukan kenderaan stabil semasa menghampiri belokan (condongan/zum berubah)',
      () {
        const car = GeoPoint(3.1, 101.7);
        final rig = CameraRig(
          entry: const CameraPose(center: car, zoom: 15, tilt: 0, bearing: 90),
          entryDuration: Duration.zero,
        );
        settle(rig, car: car, speed: 14, mode: NavCameraMode.auto, seconds: 8);
        // Sepanjang peralihan 3D -> 2D dan zum masuk, kenderaan tidak boleh melonjak di skrin.
        var minY = 1.0, maxY = 0.0;
        for (var t = 0.0; t < 6; t += 1 / 60) {
          final pose = rig.step(
            dt: 1 / 60,
            vehicle: car,
            vehicleBearing: 90,
            speedMps: 14,
            distanceToNextM: 30,
            nextKind: ManeuverKind.right,
            viewportHeightPx: 900,
          );
          final y = screenYOf(pose, car, 900);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
        expect(minY, greaterThan(0.64));
        expect(maxY, lessThan(0.74));
      },
    );
  });

  group('zoomBias (butang +/-)', () {
    CameraPose settle(double bias, {double speed = 14}) {
      const car = GeoPoint(3.1, 101.7);
      final rig = CameraRig(
        entry: const CameraPose(center: car, zoom: 16, tilt: 50, bearing: 90),
        entryDuration: Duration.zero,
      );
      late CameraPose pose;
      for (var t = 0.0; t < 12; t += 1 / 60) {
        pose = rig.step(
          dt: 1 / 60,
          vehicle: car,
          vehicleBearing: 90,
          speedMps: speed,
          distanceToNextM: null,
          nextKind: null,
          viewportHeightPx: 900,
          zoomBias: bias,
        );
      }
      return pose;
    }

    test('ditambah pada zum automatik', () {
      final base = settle(0);
      expect(settle(1).zoom, closeTo(base.zoom + 1, 0.05));
      expect(settle(-1).zoom, closeTo(base.zoom - 1, 0.05));
    });

    test(
      'kekal bila kelajuan berubah (zum automatik tetap mengikut kelajuan)',
      () {
        final slowBias = settle(1, speed: 5);
        final fastBias = settle(1, speed: 30);
        expect(slowBias.zoom, greaterThan(fastBias.zoom + 0.8));
        expect(slowBias.zoom, closeTo(settle(0, speed: 5).zoom + 1, 0.05));
      },
    );

    test('dihad ke julat zum yang sah', () {
      expect(settle(50).zoom, lessThanOrEqualTo(20));
      expect(settle(-50).zoom, greaterThanOrEqualTo(2));
    });
  });
}
