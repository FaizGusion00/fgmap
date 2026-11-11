import 'dart:io';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/cameras/data/awas_camera_store.dart';
import 'package:fgmap/features/cameras/domain/camera_alert_logic.dart';
import 'package:fgmap/features/cameras/domain/speed_camera.dart';
import 'package:flutter_test/flutter_test.dart';

/// E2 (PLUS) arah utara melalui kamera AwAS Pagoh KM 151.4, geometri jalan OSM sebenar
/// (diambil 2026-11-11). Dulu tiada amaran di sini: jalan menyerong ~300°, penapis arah lama
/// hanya menerima ±45° dari utara, dan pin kamera berada di laluan bertentangan.
const _e2Northbound = [
  GeoPoint(2.153097, 102.6788659),
  GeoPoint(2.1532682, 102.6727295),
  GeoPoint(2.1534113, 102.67086),
  GeoPoint(2.1534381, 102.6705623),
  GeoPoint(2.153623, 102.6693955),
  GeoPoint(2.1541296, 102.6672363),
  GeoPoint(2.1545343, 102.6659945),
  GeoPoint(2.1548747, 102.6650825),
  GeoPoint(2.1553277, 102.6640365),
  GeoPoint(2.1558289, 102.6630145),
  GeoPoint(2.1560219, 102.66269),
  GeoPoint(2.1582863, 102.6590445),
  GeoPoint(2.1591204, 102.6577252),
];

/// Sampel setiap [stepM] sepanjang garis, dengan arah perjalanan segmen.
List<(GeoPoint, double)> _drive(List<GeoPoint> line, {double stepM = 25}) {
  final out = <(GeoPoint, double)>[];
  for (var i = 0; i < line.length - 1; i++) {
    final a = line[i];
    final b = line[i + 1];
    final heading = bearingDegrees(a, b);
    final length = distanceMeters(a, b);
    for (var d = 0.0; d < length; d += stepM) {
      out.add((destinationPoint(a, heading, d), heading));
    }
  }
  return out;
}

void main() {
  late List<SpeedCamera> cameras;

  setUpAll(() {
    cameras = AwasCameraStore.parse(
      File('assets/cameras/cameras_my.json').readAsStringSync(),
    );
  });

  test('memandu tanpa destinasi ke utara di E2 Pagoh: amaran AwAS keluar', () {
    final alerts = <CameraAlert>[];
    for (final (point, heading) in _drive(_e2Northbound)) {
      final alert = nextCameraAheadFreeDrive(
        position: point,
        headingDegrees: heading,
        cameras: cameras,
        alertWithinM: 800,
        maxLateralM: 90,
      );
      if (alert != null) alerts.add(alert);
    }
    expect(alerts, isNotEmpty);
    expect(alerts.first.camera.id, 'awas-plus-pagoh-nb');
    // Amaran pertama keluar cukup awal (bukan pada saat terakhir).
    expect(alerts.first.distanceAheadM, greaterThan(500));
  });

  test('arah bertentangan (selatan) tidak diberi amaran kamera arah utara', () {
    final southbound = _e2Northbound.reversed.toList();
    for (final (point, heading) in _drive(southbound)) {
      final alert = nextCameraAheadFreeDrive(
        position: point,
        headingDegrees: heading,
        cameras: cameras,
        alertWithinM: 800,
        maxLateralM: 90,
      );
      expect(alert?.camera.id, isNot('awas-plus-pagoh-nb'));
    }
  });
}
