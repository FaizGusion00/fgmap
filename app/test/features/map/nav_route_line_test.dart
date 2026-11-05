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
      // Monoton: setiap titik lebih jauh dari permulaan daripada yang sebelumnya.
      final origin = short.points.first;
      for (var k = 1; k < cut.length; k++) {
        expect(
          distanceMeters(origin, cut[k]),
          greaterThan(distanceMeters(origin, cut[k - 1])),
        );
      }
      expect(short.slice(0, short.totalM).length, short.points.length);
    },
  );

  test('slice dihad pada laluan; julat kosong = tiada titik', () {
    expect(short.slice(-50, 1e9).length, short.points.length);
    expect(short.slice(300, 300), isEmpty);
    expect(short.slice(short.totalM, short.totalM + 10), isEmpty);
    expect(short.slice(700, 200), isEmpty);
  });

  test('chunkEndM: sempadan keping, hujung laluan pada keping terakhir', () {
    expect(long.chunkEndM(0), NavRouteLine.chunkM);
    expect(long.chunkEndM(4), 5 * NavRouteLine.chunkM);
    expect(long.chunkEndM(long.chunks.length - 1), long.totalM);
    expect(long.chunkEndM(long.chunks.length + 3), long.totalM);
    expect(short.chunkEndM(0), short.totalM);
  });

  // Peta melukis potongan [along, hujung keping k+1] (lapisan dekat) dan keping > k+1 (lapisan jauh),
  // seperti MapLibreView._sendNear. Tiada jurang di depan kereta pada mana-mana kedudukan.
  group('potongan kereta + keping jauh meliputi seluruh baki laluan', () {
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
          for (final a in [along, (along / 1000).floor() * 1000.0]) {
            final after = line.chunkIndexAt(a) + 1;
            final near = line.slice(a, line.chunkEndM(after));
            final far = [
              for (var i = after + 1; i < line.chunks.length; i++)
                line.chunks[i],
            ];
            if (line.totalM - a < 0.01) continue;
            expect(near.length, greaterThanOrEqualTo(2), reason: 'along $a');
            // Bermula di bawah kereta.
            expect(
              distanceMeters(near.first, line.pointAt(a)),
              lessThan(0.01),
              reason: 'along $a',
            );
            // Keping jauh pertama bersambung dengan hujung potongan, atau potongan sampai ke hujung.
            final end = far.isEmpty ? line.points.last : far.first.points.first;
            expect(
              distanceMeters(near.last, end),
              lessThan(0.01),
              reason: 'jurang selepas potongan, along $a',
            );
            // Potongan kecil (<= dua keping) supaya murah dihantar semula.
            var len = 0.0;
            for (var k = 1; k < near.length; k++) {
              len += distanceMeters(near[k - 1], near[k]);
            }
            expect(len, lessThanOrEqualTo(2 * NavRouteLine.chunkM + 60));
          }
        }
      });
    }
  });

  group('keping laluan', () {
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

    test('laluan pendek (< 1 km): satu keping', () {
      expect(short.chunks, hasLength(1));
    });
  });
}
