import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pose cruise: condong 52-60, bearing ke hadapan, tiada zum manuver', () {
    const speed = 15.0;
    final cruise = planCamera(
      const CameraSituation(
        speedMps: speed,
        distanceToNextM: null,
        nextKind: null,
      ),
    );
    final maneuver = planCamera(
      const CameraSituation(
        speedMps: speed,
        distanceToNextM: 30,
        nextKind: ManeuverKind.right,
      ),
    );
    expect(cruise.tilt, inInclusiveRange(52, 60));
    expect(cruise.zoom, closeTo(zoomForSpeed(speed), 1e-9));
    expect(maneuver.zoom, greaterThan(cruise.zoom));

    final rig = CameraRig(
      entry: const CameraPose(
        center: GeoPoint(3, 101),
        zoom: 16,
        tilt: 0,
        bearing: 0,
      ),
      entryDuration: Duration.zero,
    );
    const vehicle = GeoPoint(3.01, 101.02);
    CameraPose? pose;
    for (var i = 0; i < 180; i++) {
      pose = rig.step(
        dt: 1 / 30,
        vehicle: vehicle,
        vehicleBearing: 90,
        speedMps: speed,
        distanceToNextM: null,
        nextKind: null,
        viewportHeightPx: 800,
      );
    }
    expect(pose!.bearing, closeTo(90, 1));
    expect(pose.tilt, inInclusiveRange(52, 60));
    expect(pose.zoom, lessThan(maneuver.zoom));
  });
}
