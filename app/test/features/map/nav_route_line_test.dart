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

  test(
    'slice bermula dan berakhir tepat pada kedudukan, dengan titik asal di antaranya',
    () {
      final cut = short.slice(450, 820);
      expect(
        distanceMeters(
          cut.first,
          destinationPoint(const GeoPoint(3.1, 101.7), 90, 450),
        ),
        lessThan(0.5),
      );
      expect(
        distanceMeters(
          cut.last,
          destinationPoint(const GeoPoint(3.1, 101.7), 90, 820),
        ),
        lessThan(0.5),
      );
      // Titik asal 500, 600, 700 dan 800 m di antaranya.
      expect(cut, hasLength(6));
      expect(short.slice(0, short.totalM).length, short.points.length);
      expect(short.slice(-50, 1e9).length, short.points.length);
      expect(short.slice(300, 300), isEmpty);
      expect(short.slice(short.totalM, short.totalM + 10), isEmpty);
      expect(short.slice(700, 200), isEmpty);
    },
  );

  test('chunkEndM: sempadan keping, hujung laluan pada keping terakhir', () {
    expect(long.chunkEndM(0), NavRouteLine.chunkM);
    expect(long.chunkEndM(4), 5 * NavRouteLine.chunkM);
    expect(long.chunkEndM(long.chunks.length - 1), long.totalM);
    expect(long.chunkEndM(long.chunks.length + 3), long.totalM);
    expect(short.chunkEndM(0), short.totalM);
  });

  // Lapisan sandaran peta (MapLibreView._updateAhead) melukis [along + lead, hujung keping semasa] dan
  // lapisan jauh melukis keping > semasa: jika gradient tidak dilukis, tiada jurang selepas permulaan
  // sandaran.
  group('sandaran di depan kereta + keping jauh bersambung', () {
    NavRouteLine straight(double km) => lineFrom([
      for (var d = 0.0; d <= km * 1000; d += 37)
        destinationPoint(const GeoPoint(3.0, 101.6), 30, d),
      destinationPoint(const GeoPoint(3.0, 101.6), 30, km * 1000),
    ]);

    for (final km in [0.6, 1.0, 17.5, 55.0]) {
      test('$km km', () {
        final line = straight(km);
        final step = km < 2 ? 7.3 : 97.3;
        for (var along = 0.0; along < line.totalM; along += step) {
          for (final lead in [12.0, 60.0, 150.0]) {
            final chunk = line.chunkIndexAt(along);
            final ahead = line.slice(along + lead, line.chunkEndM(chunk));
            if (ahead.length < 2) continue;
            expect(
              distanceMeters(ahead.first, line.pointAt(along + lead)),
              lessThan(0.01),
            );
            final end = chunk + 1 < line.chunks.length
                ? line.chunks[chunk + 1].points.first
                : line.points.last;
            expect(
              distanceMeters(ahead.last, end),
              lessThan(0.01),
              reason: 'jurang selepas sandaran, along $along',
            );
          }
        }
      });
    }
  });

  group('keping laluan (ketepatan pangkas pada laluan panjang)', () {
    test('keping bersambung tanpa jurang dan jumlah panjang sama', () {
      final n = long.chunks.length;
      expect(n, (long.totalM / NavRouteLine.chunkM - 0.05).ceil());
      var sum = 0.0;
      for (var i = 0; i < n; i++) {
        final pts = long.chunks[i].points;
        expect(pts.length, greaterThanOrEqualTo(2));
        for (var k = 1; k < pts.length; k++) {
          sum += distanceMeters(pts[k - 1], pts[k]);
        }
        if (i > 0) {
          expect(
            distanceMeters(long.chunks[i - 1].points.last, pts.first),
            lessThan(0.01),
            reason: 'jurang antara keping ${i - 1} dan $i',
          );
        }
      }
      expect(sum, closeTo(long.totalM, 1));
    });

    test('indeks keping mengikut jarak, dihad pada hujung', () {
      expect(long.chunkIndexAt(0), 0);
      expect(long.chunkIndexAt(999), 0);
      expect(long.chunkIndexAt(1000), 1);
      expect(long.chunkIndexAt(2500), 2);
      expect(long.chunkIndexAt(-5), 0);
      expect(long.chunkIndexAt(1e12), long.chunks.length - 1);
    });

    test(
      'ralat kedudukan pangkas < 5 m walaupun laluan 330 km (satu gradient penuh ~1.3 km/piksel)',
      () {
        // Gradient dirender ke 256 piksel merentas panjang garisan yang dihantar.
        for (final along in [0.0, 1234.5, 55555.0, 160000.0, long.totalM - 3]) {
          final i = long.chunkIndexAt(along);
          final chunk = long.chunks[i];
          final f = long.chunkFractionAt(along);
          final chunkLen = chunk.points.length < 2
              ? 0.0
              : [
                  for (var k = 1; k < chunk.points.length; k++)
                    distanceMeters(chunk.points[k - 1], chunk.points[k]),
                ].reduce((a, b) => a + b);
          final texelM = chunkLen / 256;
          expect(texelM, lessThan(5), reason: 'resolusi gradient');
          expect(f * chunkLen, closeTo(along - i * NavRouteLine.chunkM, 1));
        }
      },
    );

    test('laluan pendek (< 1 km): satu keping', () {
      expect(short.chunks, hasLength(1));
      expect(short.chunkFractionAt(500), closeTo(0.5, 0.001));
    });
  });
}
