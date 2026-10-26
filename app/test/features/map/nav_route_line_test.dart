import 'dart:math' as math;

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/nav_route_line.dart';
import 'package:flutter_test/flutter_test.dart';

NavRouteLine lineFrom(List<GeoPoint> pts, {int version = 1}) {
  final cum = List<double>.filled(pts.length, 0);
  for (var i = 1; i < pts.length; i++) {
    cum[i] = cum[i - 1] + distanceMeters(pts[i - 1], pts[i]);
  }
  return NavRouteLine(points: pts, cumulativeM: cum, version: version);
}

void main() {
  // Laluan utara-selatan panjang (~330 km) dan laluan timur-barat pendek.
  final long = lineFrom([
    for (var lat = 1.0; lat <= 4.0; lat += 0.05) GeoPoint(lat, 103.0),
  ]);
  final short = lineFrom([
    for (var d = 0.0; d <= 1000; d += 100)
      destinationPoint(const GeoPoint(3.1, 101.7), 90, d),
  ]);

  test('pecahan 0 di permulaan dan 1 di hujung, monoton', () {
    for (final line in [long, short]) {
      expect(line.fractionAt(0), 0);
      expect(line.fractionAt(line.totalM), closeTo(1, 1e-9));
      var prev = -1.0;
      for (var d = 0.0; d <= line.totalM; d += line.totalM / 50) {
        final f = line.fractionAt(d);
        expect(f, greaterThanOrEqualTo(prev));
        prev = f;
      }
    }
  });

  test('di luar julat dihad', () {
    expect(short.fractionAt(-50), 0);
    expect(short.fractionAt(1e9), closeTo(1, 1e-9));
  });

  test(
    'ruang Mercator: pecahan menyimpang daripada nisbah geodesik pada laluan panjang utara-selatan',
    () {
      final mid = long.totalM / 2;
      final geodesic = mid / long.totalM;
      final mercator = long.fractionAt(mid);
      // Perbezaan wujud (itulah sebab kita tidak boleh guna nisbah geodesik), tetapi kecil.
      expect((mercator - geodesic).abs(), greaterThan(1e-4));
      expect((mercator - geodesic).abs(), lessThan(0.01));
      // Dalam meter: ralat jika nisbah geodesik digunakan.
      expect(((mercator - geodesic) * long.totalM).abs(), greaterThan(30));
    },
  );

  test('laluan pendek: pecahan ~ nisbah jarak', () {
    expect(short.fractionAt(500), closeTo(0.5, 0.001));
  });

  test('remainingFrom bermula tepat pada kedudukan dan berakhir di hujung', () {
    final rest = short.remainingFrom(450);
    expect(rest.first, isNot(equals(short.points.first)));
    expect(
      distanceMeters(
        rest.first,
        destinationPoint(const GeoPoint(3.1, 101.7), 90, 450),
      ),
      lessThan(0.5),
    );
    expect(rest.last, short.points.last);
    // Titik sebelum kedudukan dibuang.
    expect(rest.length, short.points.length - 4);
    expect(short.remainingFrom(0).length, short.points.length);
    expect(short.remainingFrom(short.totalM).length, 2);
  });

  test('ungkapan gradient: langkah menaik tegas dan format sah', () {
    final g = trimGradient(0.25, '#2563eb');
    expect(g.first, 'step');
    expect(g[2], 'rgba(0, 0, 0, 0)');
    expect(g[3], 0.25);
    expect(g[4], '#2563eb');
    // Pecahan ekstrem dihad dalam (0, 1) supaya hentian tidak sama dengan titik hujung.
    expect(trimGradient(0, '#fff')[3], greaterThan(0));
    expect(trimGradient(5, '#fff')[3], lessThan(1));
    final solid = solidGradient('#2563eb');
    expect(solid.first, 'interpolate');
    expect(solid[3], 0);
    expect(solid[5], 1);
    expect(math.pi, isNotNull);
  });
}
