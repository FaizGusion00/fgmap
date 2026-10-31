import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/cameras/domain/camera_alert_logic.dart';
import 'package:fgmap/features/cameras/domain/speed_camera.dart';
import 'package:flutter_test/flutter_test.dart';

// Laluan lurus ke timur di khatulistiwa (~11.1 km). 0.01 darjah ~ 1112 m.
final _route = [const GeoPoint(0, 0), const GeoPoint(0, 0.1)];

SpeedCamera _cam(String id, double lat, double lng) => SpeedCamera(
  id: id,
  name: id,
  point: GeoPoint(lat, lng),
  source: SpeedCameraSource.jpjAwas,
);

void main() {
  test('tiada kamera atau laluan pendek memberi null', () {
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: const [],
        alongNow: 0,
        alertWithinM: 1000,
      ),
      isNull,
    );
    expect(
      nextCameraAlert(
        routePoints: [const GeoPoint(0, 0)],
        cameras: [_cam('a', 0, 0.01)],
        alongNow: 0,
        alertWithinM: 1000,
      ),
      isNull,
    );
  });

  test('amaran dicetuskan dalam jarak pendekatan', () {
    final alert = nextCameraAlert(
      routePoints: _route,
      cameras: [_cam('depan', 0, 0.02)], // ~2224 m
      alongNow: 1500,
      alertWithinM: 1000,
    );
    expect(alert, isNotNull);
    expect(alert!.camera.id, 'depan');
    expect(alert.alongM, closeTo(2224, 5));
    expect(alert.distanceAheadM, closeTo(724, 5));
  });

  test('di luar jarak pendekatan tidak diberi amaran', () {
    final alert = nextCameraAlert(
      routePoints: _route,
      cameras: [_cam('jauh', 0, 0.05)],
      alongNow: 0,
      alertWithinM: 1000,
    );
    expect(alert, isNull);
  });

  test('kamera di belakang atau terlalu dekat (<=30 m) diabaikan', () {
    final behind = _cam('belakang', 0, 0.01); // ~1112 m
    final tooClose = _cam('rapat', 0, 0.0102); // ~1134 m
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: [behind],
        alongNow: 1500,
        alertWithinM: 1000,
      ),
      isNull,
    );
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: [tooClose],
        alongNow: 1112 + 10,
        alertWithinM: 1000,
      ),
      isNull,
    );
  });

  test('penapis koridor: kamera jauh dari laluan ditolak', () {
    final off = _cam('sisi', 0.002, 0.02); // ~222 m dari laluan
    final on = _cam('atas', 0.0005, 0.03); // ~55 m dari laluan
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: [off],
        alongNow: 0,
        alertWithinM: 5000,
        corridorM: 120,
      ),
      isNull,
    );
    final alert = nextCameraAlert(
      routePoints: _route,
      cameras: [off, on],
      alongNow: 0,
      alertWithinM: 5000,
      corridorM: 120,
    );
    expect(alert!.camera.id, 'atas');
  });

  test('bound NB/SB menapis arah perjalanan', () {
    final nb = SpeedCamera(
      id: 'nb',
      name: 'NB',
      point: const GeoPoint(0, 0.02),
      source: SpeedCameraSource.jpjAwas,
      bound: 'NB',
    );
    // Laluan ke timur (bearing ~90): NB tidak sepadan.
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: [nb],
        alongNow: 0,
        alertWithinM: 5000,
        travelBearingDegrees: 90,
      ),
      isNull,
    );
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: [nb],
        alongNow: 0,
        alertWithinM: 5000,
        travelBearingDegrees: 0,
      ),
      isNotNull,
    );
  });

  test('corridorM boleh dilaraskan', () {
    final off = _cam('sisi', 0.002, 0.02);
    final alert = nextCameraAlert(
      routePoints: _route,
      cameras: [off],
      alongNow: 0,
      alertWithinM: 5000,
      corridorM: 300,
    );
    expect(alert?.camera.id, 'sisi');
  });

  test('memilih kamera paling hampir di hadapan', () {
    final alert = nextCameraAlert(
      routePoints: _route,
      cameras: [_cam('c3', 0, 0.03), _cam('c1', 0, 0.01), _cam('c2', 0, 0.02)],
      alongNow: 0,
      alertWithinM: 5000,
    );
    expect(alert!.camera.id, 'c1');
  });

  test('pin approx guna koridor ≥700 m walaupun corridorM ketat', () {
    final approx = SpeedCamera(
      id: 'km',
      name: 'KM',
      point: const GeoPoint(0.005, 0.02), // ~555 m off-track
      source: SpeedCameraSource.jpjAwas,
      confidence: SpeedCameraConfidence.approx,
    );
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: [approx],
        alongNow: 0,
        alertWithinM: 5000,
        corridorM: 120,
      ),
      isNotNull,
    );
    final precise = SpeedCamera(
      id: 'gps',
      name: 'GPS',
      point: const GeoPoint(0.005, 0.02),
      source: SpeedCameraSource.jpjAwas,
      confidence: SpeedCameraConfidence.high,
    );
    expect(
      nextCameraAlert(
        routePoints: _route,
        cameras: [precise],
        alongNow: 0,
        alertWithinM: 5000,
        corridorM: 120,
      ),
      isNull,
    );
  });
}
