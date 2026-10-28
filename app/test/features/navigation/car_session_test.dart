import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/car_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pose = CameraPose(
    center: GeoPoint(3.1, 101.7),
    zoom: 17,
    tilt: 56,
    bearing: 90,
  );
  const route = [GeoPoint(3.1, 101.7), GeoPoint(3.2, 101.8)];

  test('browse tiada laluan', () {
    final snap = mapCarSession(navigating: false, cruising: false);
    expect(snap.mode, CarDriveMode.browse);
    expect(snap.route, isEmpty);
    expect(snap.hasRoute, isFalse);
    expect(snap.toMap()['route'], isEmpty);
    expect(snap.toMap()['maneuver'], isNull);
  });

  test('cruise ada pose dan kelajuan, tiada laluan', () {
    final snap = mapCarSession(
      navigating: false,
      cruising: true,
      pose: pose,
      speedMps: 12,
      limitKmh: 80,
      overspeed: false,
      navigationRoute: route,
    );
    expect(snap.mode, CarDriveMode.cruise);
    expect(snap.route, isEmpty);
    expect(snap.pose!.bearing, 90);
    expect(snap.pose!.tilt, inInclusiveRange(52, 60));
    expect(snap.speed.kmh, 43);
    expect(snap.speed.showLimit, isTrue);
    final map = snap.toMap();
    expect(map['route'], isEmpty);
    expect(map['speedKmh'], 43);
    expect(map['limitKmh'], 80);
    expect(map['maneuver'], isNull);
  });

  test('navigasi ada laluan dan manuver; cruise mati', () {
    final snap = mapCarSession(
      navigating: true,
      cruising: true,
      pose: pose,
      speedMps: 10,
      navigationRoute: route,
      routeVersion: 3,
      maneuver: 'Belok kanan',
      distanceToManeuverM: 120,
      remainingM: 4000,
      remainingS: 300,
    );
    expect(snap.mode, CarDriveMode.navigating);
    expect(snap.route, route);
    expect(snap.maneuver, 'Belok kanan');
    expect(snap.hasRoute, isTrue);
    final map = snap.toMap();
    expect(map['mode'], 'navigating');
    expect((map['route'] as List), hasLength(2));
    expect(map['maneuver'], 'Belok kanan');
  });

  test('had tidak diketahui: papan tidak dihantar', () {
    final snap = mapCarSession(
      navigating: false,
      cruising: true,
      speedMps: 8,
      limitKmh: null,
    );
    expect(snap.speed.showLimit, isFalse);
    expect(snap.toMap()['limitKmh'], isNull);
  });
}
