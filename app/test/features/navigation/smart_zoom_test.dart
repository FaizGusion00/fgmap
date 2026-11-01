import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zum automatik ikut keadaan (laporan penguji 2026-11-02: "pandai zoom in dan out").
void main() {
  CameraTarget plan({
    double speed = 8,
    double? distance,
    ManeuverKind? kind,
    double? gap,
    double? since,
    ManeuverKind? last,
  }) => planCamera(
    CameraSituation(
      speedMps: speed,
      distanceToNextM: distance,
      nextKind: kind,
      followingGapM: gap,
      sinceTurnM: since,
      lastKind: last,
    ),
  );

  final cruise = plan(speed: 8);

  test('belokan bandar perlahan: zum masuk ikut jarak, bukan hanya masa', () {
    // 150 m pada 6 m/s = 25 s: dahulu langsung tiada zum masuk.
    final t = plan(speed: 6, distance: 150, kind: ManeuverKind.right);
    expect(t.zoom, greaterThan(plan(speed: 6).zoom + 0.2));
    expect(t.tilt, lessThan(plan(speed: 6).tilt));
  });

  test('belokan berangkai: kekal dekat, tidak zum keluar di antara', () {
    final chained = plan(distance: 180, kind: ManeuverKind.left, gap: 120);
    final lone = plan(distance: 180, kind: ManeuverKind.left, gap: 900);
    expect(chained.zoom, greaterThan(lone.zoom));
  });

  test('selepas belok: pegang pandangan sebentar, kemudian lepaskan', () {
    final justTurned = plan(
      distance: 1500,
      kind: ManeuverKind.left,
      since: 10,
      last: ManeuverKind.right,
    );
    final later = plan(
      distance: 1500,
      kind: ManeuverKind.left,
      since: 120,
      last: ManeuverKind.right,
    );
    expect(justTurned.zoom, greaterThan(cruise.zoom + 0.6));
    expect(later.zoom, closeTo(cruise.zoom, 0.01));
  });

  test('lebuh raya: zum keluar; keluar lebuh raya disediakan lebih awal', () {
    final open = plan(speed: 30, distance: 8000, kind: ManeuverKind.exitLeft);
    expect(open.zoom, lessThan(zoomForSpeed(30)));
    // 400 m pada 28 m/s = 14 s: keluar lebuh raya sudah separuh zum masuk (dahulu hampir tiada).
    final exit = plan(speed: 28, distance: 400, kind: ManeuverKind.exitLeft);
    expect(exit.zoom, greaterThan(zoomForSpeed(28) + 0.3));
  });

  test('zum berubah lancar: tiada "siku" kelajuan bila hampir sasaran', () {
    const car = GeoPoint(3, 101);
    final rig = CameraRig(
      entry: const CameraPose(center: car, zoom: 14, tilt: 50, bearing: 0),
      entryDuration: Duration.zero,
    );
    final zooms = <double>[];
    for (var i = 0; i < 300; i++) {
      zooms.add(
        rig
            .step(
              dt: 1 / 60,
              vehicle: car,
              vehicleBearing: 0,
              speedMps: 0,
              distanceToNextM: null,
              nextKind: null,
              viewportHeightPx: 800,
            )
            .zoom,
      );
    }
    var maxJerk = 0.0;
    for (var i = 2; i < zooms.length; i++) {
      final a = zooms[i - 1] - zooms[i - 2];
      final b = zooms[i] - zooms[i - 1];
      maxJerk = (b - a).abs() > maxJerk ? (b - a).abs() : maxJerk;
    }
    // Perubahan kadar zum antara bingkai sangat kecil (dahulu ~0.05 tahap pada lompatan 4->1 tahap/s).
    expect(maxJerk, lessThan(0.006));
  });
}
