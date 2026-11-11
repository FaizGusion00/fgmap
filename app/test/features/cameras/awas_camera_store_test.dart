import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/cameras/data/awas_camera_store.dart';
import 'package:fgmap/features/cameras/domain/camera_alert_logic.dart';
import 'package:fgmap/features/cameras/domain/speed_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('aset cameras_my.json dimuat: AwAS dan OSM', () async {
    final cams = await AwasCameraStore().load();
    expect(cams.length, greaterThan(50));
    expect(cams.any((c) => c.source == SpeedCameraSource.jpjAwas), isTrue);
    expect(cams.any((c) => c.source == SpeedCameraSource.osm), isTrue);
    expect(cams.every((c) => c.id.isNotEmpty && c.name.isNotEmpty), isTrue);
    expect(cams.any((c) => c.directionDegrees != null), isTrue);
    expect(cams.any((c) => c.maxSpeedKmh != null), isTrue);
  });

  test('id unik, koordinat dalam Malaysia, medan sah', () async {
    final cams = await AwasCameraStore().load();
    expect(cams.map((c) => c.id).toSet().length, cams.length);
    for (final c in cams) {
      expect(c.point.lat, inInclusiveRange(0.8, 7.5), reason: c.id);
      expect(c.point.lng, inInclusiveRange(99.0, 119.5), reason: c.id);
      expect(c.type, anyOf('speed', 'red_light'), reason: c.id);
      expect(c.bound, anyOf(isNull, 'NB', 'SB', 'EB', 'WB'), reason: c.id);
      final d = c.directionDegrees;
      if (d != null) expect(d, inInclusiveRange(0, 359.99), reason: c.id);
    }
  });

  test('pin AwAS jauh dari jalan utama telah dibuang', () async {
    final ids = (await AwasCameraStore().load()).map((c) => c.id).toSet();
    for (final id in [
      'awas-plus-rawang-sb',
      'awas-lpt2-kl',
      'awas-lpt2-kt',
      'awas-gua-musang',
    ]) {
      expect(ids.contains(id), isFalse, reason: id);
    }
  });

  test('E2 Pagoh arah utara (~305°): kamera di hadapan diberi amaran', () async {
    final cams = await AwasCameraStore().load();
    // Kamera OSM "AWAS Pagoh - Northbound" (direction 305). Mula ~600 m sebelumnya.
    const cam = GeoPoint(2.1582863, 102.6590445);
    final start = destinationPoint(cam, 125, 600);
    final alert = nextCameraAheadFreeDrive(
      position: start,
      headingDegrees: 305,
      cameras: cams,
      alertWithinM: 800,
    );
    expect(alert, isNotNull);
    expect(distanceMeters(alert!.camera.point, cam), lessThan(50));
    // Arah bertentangan (SB) tidak memberi amaran untuk kamera NB ini.
    final back = nextCameraAheadFreeDrive(
      position: destinationPoint(cam, 305, 600),
      headingDegrees: 125,
      cameras: cams,
      alertWithinM: 800,
    );
    expect(back == null || distanceMeters(back.camera.point, cam) > 50, isTrue);
  });

  test('load kali kedua memulangkan cache yang sama', () async {
    final store = AwasCameraStore();
    final a = await store.load();
    final b = await store.load();
    expect(identical(a, b), isTrue);
  });

  test('parse: sumber, direction (darjah/kardinal/forward), maxspeed', () {
    final cams = AwasCameraStore.parse('''
{
  "asOf": "2026-11-11",
  "cameras": [
    {"id": "awas-a", "name": "A (NB)", "lat": 2.1, "lng": 102.6, "type": "speed",
     "bound": "NB", "direction": 305, "maxspeed": 110, "source": "jpj_awas",
     "confidence": "high"},
    {"id": "osm-1", "name": "B", "lat": 3.1, "lng": 101.6, "type": "red_light",
     "direction": "NE", "maxspeed": "80", "source": "osm", "confidence": "high"},
    {"id": "osm-2", "name": "C", "lat": 3.2, "lng": 101.7, "direction": "forward",
     "source": "osm", "confidence": "approx"},
    {"id": "rosak", "name": "tiada koordinat"},
    "bukan peta"
  ]
}''');
    expect(cams.map((c) => c.id), ['awas-a', 'osm-1', 'osm-2']);
    expect(cams[0].source, SpeedCameraSource.jpjAwas);
    expect(cams[0].bound, 'NB');
    expect(cams[0].directionDegrees, 305);
    expect(cams[0].maxSpeedKmh, 110);
    expect(cams[0].confidence, SpeedCameraConfidence.high);
    expect(cams[1].source, SpeedCameraSource.osm);
    expect(cams[1].type, 'red_light');
    expect(cams[1].directionDegrees, 45);
    expect(cams[1].maxSpeedKmh, 80);
    expect(cams[2].type, 'speed');
    expect(cams[2].directionDegrees, isNull);
    expect(cams[2].bound, isNull);
    expect(cams[2].confidence, SpeedCameraConfidence.approx);
  });

  test('parse: JSON bukan objek memberi senarai kosong', () {
    expect(AwasCameraStore.parse('[]'), isEmpty);
    expect(AwasCameraStore.parse('{"cameras": 3}'), isEmpty);
  });
}
