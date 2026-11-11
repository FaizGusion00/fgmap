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
    const nb = SpeedCamera(
      id: 'nb',
      name: 'NB',
      point: GeoPoint(0, 0.02),
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
    const approx = SpeedCamera(
      id: 'km',
      name: 'KM',
      point: GeoPoint(0.005, 0.02), // ~555 m off-track
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
    const precise = SpeedCamera(
      id: 'gps',
      name: 'GPS',
      point: GeoPoint(0.005, 0.02),
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

  group('penapis arah (bound separuh satah + direction)', () {
    SpeedCamera bound(String? b, {double? dir}) => SpeedCamera(
      id: 'k',
      name: 'k',
      point: const GeoPoint(2.15, 102.69),
      source: SpeedCameraSource.jpjAwas,
      bound: b,
      directionDegrees: dir,
    );

    test('E2 Pagoh (~300°/120°): NB lulus pada 300, SB lulus pada 120', () {
      expect(cameraAppliesToHeading(bound('NB'), 300), isTrue);
      expect(cameraAppliesToHeading(bound('SB'), 120), isTrue);
    });

    test('NB ditolak pada 120, SB ditolak pada 300', () {
      expect(cameraAppliesToHeading(bound('NB'), 120), isFalse);
      expect(cameraAppliesToHeading(bound('SB'), 300), isFalse);
    });

    test('EB/WB separuh satah timur/barat', () {
      expect(cameraAppliesToHeading(bound('EB'), 20), isTrue);
      expect(cameraAppliesToHeading(bound('EB'), 170), isTrue);
      expect(cameraAppliesToHeading(bound('EB'), 200), isFalse);
      expect(cameraAppliesToHeading(bound('WB'), 200), isTrue);
      expect(cameraAppliesToHeading(bound('WB'), 350), isTrue);
      expect(cameraAppliesToHeading(bound('WB'), 10), isFalse);
    });

    test('bound/arah tiada = lulus', () {
      expect(cameraAppliesToHeading(bound(null), 123), isTrue);
      expect(cameraAppliesToHeading(bound('NB'), null), isTrue);
      expect(cameraAppliesToHeading(bound(null, dir: 305), null), isTrue);
      expect(cameraAppliesToHeading(bound('??'), 180), isTrue);
    });

    test('direction OSM: lulus jika beza ≤ 60°', () {
      final c = bound(null, dir: 305);
      expect(cameraAppliesToHeading(c, 300), isTrue);
      expect(cameraAppliesToHeading(c, 5), isTrue); // 60° ikut jam
      expect(cameraAppliesToHeading(c, 250), isTrue); // 55°
      expect(cameraAppliesToHeading(c, 240), isFalse); // 65°
      expect(cameraAppliesToHeading(c, 125), isFalse); // arah bertentangan
      expect(cameraAppliesToHeading(bound(null, dir: 10), 340), isTrue);
    });

    test('nextCameraAlert menggunakan direction', () {
      const ahead = SpeedCamera(
        id: 'dir',
        name: 'dir',
        point: GeoPoint(0, 0.02),
        source: SpeedCameraSource.osm,
        directionDegrees: 270,
      );
      expect(
        nextCameraAlert(
          routePoints: _route,
          cameras: [ahead],
          alongNow: 0,
          alertWithinM: 5000,
          travelBearingDegrees: 90,
        ),
        isNull,
      );
      expect(
        nextCameraAlert(
          routePoints: _route,
          cameras: [ahead],
          alongNow: 0,
          alertWithinM: 5000,
          travelBearingDegrees: 270,
        ),
        isNotNull,
      );
    });
  });

  group('nextCameraAheadFreeDrive', () {
    // Memandu ke timur dari (0, 0). 0.001 darjah ~ 111 m.
    const here = GeoPoint(0, 0);
    CameraAlert? free(
      List<SpeedCamera> cams, {
      double? heading = 90,
      double within = 1000,
    }) => nextCameraAheadFreeDrive(
      position: here,
      headingDegrees: heading,
      cameras: cams,
      alertWithinM: within,
    );

    test('kamera di hadapan dalam jarak diberi amaran (jarak lurus)', () {
      final a = free([_cam('depan', 0, 0.005)]); // ~556 m
      expect(a?.camera.id, 'depan');
      expect(a!.distanceAheadM, closeTo(556, 2));
      expect(a.alongM, a.distanceAheadM);
    });

    test('di belakang, di sisi, terlalu jauh atau terlalu dekat diabaikan', () {
      expect(free([_cam('belakang', 0, -0.005)]), isNull);
      expect(free([_cam('sisi', 0.005, 0)]), isNull);
      expect(free([_cam('jauh', 0, 0.02)]), isNull); // ~2.2 km
      expect(free([_cam('rapat', 0, 0.0002)]), isNull); // ~22 m
    });

    test('ofset sisi kecil diterima, besar ditolak walaupun dalam kon', () {
      expect(free([_cam('lorong', 0.0003, 0.005)]), isNotNull); // ~33 m sisi
      // ~111 m sisi pada ~556 m (sudut ~11°, dalam kon 30°) -> ditolak.
      expect(free([_cam('jalan-lain', 0.001, 0.005)]), isNull);
    });

    test('pin approx diberi ofset sisi ≥150 m', () {
      const approx = SpeedCamera(
        id: 'km',
        name: 'km',
        point: GeoPoint(0.001, 0.005),
        source: SpeedCameraSource.jpjAwas,
        confidence: SpeedCameraConfidence.approx,
      );
      expect(free([approx])?.camera.id, 'km');
    });

    test('kon: dekat tetapi sudut > 30° ditolak', () {
      // ~45° dari arah: ofset sisi ~55 m (< 60) tetapi di luar kon.
      expect(free([_cam('serong', 0.0005, 0.0005)]), isNull);
    });

    test('tanpa arah GPS tiada amaran', () {
      expect(free([_cam('depan', 0, 0.005)], heading: null), isNull);
      expect(free(const []), isNull);
    });

    test('penapis bound/direction digunakan', () {
      const sb = SpeedCamera(
        id: 'sb',
        name: 'sb',
        point: GeoPoint(-0.003, 0.003),
        source: SpeedCameraSource.jpjAwas,
        bound: 'SB',
      );
      // Arah 135 (tenggara): SB lulus; ke barat laut tiada kamera di hadapan.
      expect(free([sb], heading: 135)?.camera.id, 'sb');
      const nb = SpeedCamera(
        id: 'nb',
        name: 'nb',
        point: GeoPoint(-0.003, 0.003),
        source: SpeedCameraSource.jpjAwas,
        bound: 'NB',
      );
      expect(free([nb], heading: 135), isNull);
      const wrongDir = SpeedCamera(
        id: 'dir',
        name: 'dir',
        point: GeoPoint(0, 0.005),
        source: SpeedCameraSource.osm,
        directionDegrees: 270,
      );
      expect(free([wrongDir]), isNull);
    });

    test('memilih yang terdekat di hadapan', () {
      final a = free([
        _cam('c2', 0, 0.008),
        _cam('c1', 0, 0.004),
        _cam('belakang', 0, -0.001),
      ]);
      expect(a?.camera.id, 'c1');
    });
  });

  test('mergeLiveCameras membuang pendua id/jarak', () {
    final bundled = [_cam('osm-1', 3, 101), _cam('awas-x', 3.1, 101)];
    final merged = mergeLiveCameras(bundled, [
      _cam('osm-1', 3.0001, 101), // id sama
      _cam('osm-2', 3.1005, 101), // ~56 m dari awas-x
      _cam('osm-3', 3.2, 101), // baharu
    ]);
    expect(merged.map((c) => c.id), ['osm-1', 'awas-x', 'osm-3']);
    expect(identical(mergeLiveCameras(bundled, const []), bundled), isTrue);
  });
}
