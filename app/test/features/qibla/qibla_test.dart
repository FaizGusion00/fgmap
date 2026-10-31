import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/qibla/domain/qibla.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('geodesik WGS84 (Vincenty)', () {
    test('kes penanda aras Flinders Peak → Buninyong', () {
      // Rujukan klasik Geoscience Australia: s = 54 972.271 m, azimut awal 306°52′05.37″.
      const flinders = GeoPoint(
        -(37 + 57 / 60 + 3.72030 / 3600),
        144 + 25 / 60 + 29.52440 / 3600,
      );
      const buninyong = GeoPoint(
        -(37 + 39 / 60 + 10.15610 / 3600),
        143 + 55 / 60 + 35.38390 / 3600,
      );
      final g = geodesicInverse(flinders, buninyong);
      expect(g.distanceM, closeTo(54972.271, 0.01));
      expect(g.initialBearingDeg, closeTo(306 + 52 / 60 + 5.37 / 3600, 1e-4));
    });

    test('titik sama: jarak sifar', () {
      expect(geodesicInverse(kaaba, kaaba).distanceM, 0);
    });

    test('hampir antipod jatuh semula kepada sfera tanpa ranap', () {
      const a = GeoPoint(0, 0);
      const b = GeoPoint(0.5, 179.7);
      final g = geodesicInverse(a, b);
      expect(g.distanceM, greaterThan(19e6));
      expect(g.initialBearingDeg, inInclusiveRange(0, 360));
    });
  });

  group('arah kiblat', () {
    // Nilai yang diterbitkan JAKIM / IslamicFinder; had 0.3° meliputi beza sfera-vs-elipsoid.
    const cases = <String, (GeoPoint, double)>{
      'Kuala Lumpur': (GeoPoint(3.139, 101.6869), 292.5),
      'Kota Kinabalu': (GeoPoint(5.9804, 116.0735), 290.6),
      'Jakarta': (GeoPoint(-6.2088, 106.8456), 295.1),
      'London': (GeoPoint(51.5074, -0.1278), 119.0),
      'New York': (GeoPoint(40.7128, -74.0060), 58.5),
      'Sydney': (GeoPoint(-33.8688, 151.2093), 277.5),
    };
    for (final e in cases.entries) {
      test('${e.key} ≈ ${e.value.$2}°', () {
        expect(qiblaBearingDegrees(e.value.$1), closeTo(e.value.$2, 0.4));
      });
    }

    test('geodesik dan sfera berbeza kurang 0.3° dari Malaysia', () {
      const kl = GeoPoint(3.139, 101.6869);
      expect(
        (qiblaBearingDegrees(kl) - bearingDegrees(kl, kaaba)).abs(),
        lessThan(0.3),
      );
    });

    test('jarak KL–Makkah ~6 980 km (geodesik)', () {
      const kl = GeoPoint(3.139, 101.6869);
      expect(qiblaDistanceKm(kl), closeTo(6979.2, 1));
    });

    test('sudut relatif kepada heading', () {
      const kl = GeoPoint(3.139, 101.687);
      final q = qiblaBearingDegrees(kl);
      expect(qiblaRelativeDegrees(kl, q), closeTo(0, 0.01));
      expect(qiblaRelativeDegrees(kl, null), isNull);
      final rel = qiblaRelativeDegrees(kl, (q + 90) % 360)!;
      expect(rel, closeTo(270, 0.5));
    });
  });

  group('arah pusing', () {
    test('normalizeDeltaDegrees', () {
      expect(normalizeDeltaDegrees(370), closeTo(10, 1e-9));
      expect(normalizeDeltaDegrees(-190), closeTo(170, 1e-9));
    });

    test('positif = kanan, negatif = kiri, ikut laluan terpendek', () {
      expect(qiblaTurnDegrees(qibla: 292, heading: 270), closeTo(22, 1e-9));
      expect(qiblaTurnDegrees(qibla: 292, heading: 310), closeTo(-18, 1e-9));
      // Melintasi utara: dari 350° ke 10° ialah +20° (kanan), bukan −340°.
      expect(qiblaTurnDegrees(qibla: 10, heading: 350), closeTo(20, 1e-9));
      expect(qiblaTurnDegrees(qibla: 350, heading: 10), closeTo(-20, 1e-9));
    });

    test('mata angin 8-arah', () {
      expect(compassOctant(0), 0);
      expect(compassOctant(359), 0);
      expect(compassOctant(44), 1);
      expect(compassOctant(90), 2);
      expect(compassOctant(290), 6);
      expect(compassOctant(300), 7);
      expect(compassOctant(315), 7);
    });
  });

  group('QiblaAlignment (histeresis)', () {
    test('masuk dalam 3°, kekal sehingga 6°, baru keluar', () {
      final a = QiblaAlignment();
      expect(a.update(5), isFalse);
      expect(a.update(2.9), isTrue);
      expect(a.update(5.5), isTrue, reason: 'masih dalam zon keluar');
      expect(a.update(-5.9), isTrue);
      expect(a.update(6.1), isFalse);
      expect(
        a.update(4),
        isFalse,
        reason: 'mesti kembali dalam 3° untuk masuk',
      );
    });
  });

  group('HeadingSmoother', () {
    test('bacaan pertama diterima terus', () {
      final s = HeadingSmoother();
      expect(s.step(123, 0.016), 123);
    });

    test('merentasi 359°→0° melalui laluan terpendek, tidak berpusing balik', () {
      final s = HeadingSmoother()..step(350, 0.016);
      var shown = 350.0;
      for (var i = 0; i < 60; i++) {
        final next = s.step(10, 0.016);
        // Sentiasa bergerak ke hadapan (kanan) pada setiap langkah, tidak melompat melalui 180°.
        expect(normalizeDeltaDegrees(next - shown), greaterThanOrEqualTo(0));
        shown = next;
      }
      expect(normalizeDeltaDegrees(shown - 10).abs(), lessThan(1));
    });

    test('getaran kecil diabaikan (jarum tidak menggeletar)', () {
      final s = HeadingSmoother()..step(100, 0.016);
      expect(s.step(100.2, 0.016), 100);
    });

    test('lompatan besar dikejar dengan cepat', () {
      final s = HeadingSmoother()..step(0, 0.016);
      var shown = 0.0;
      for (var i = 0; i < 30; i++) {
        shown = s.step(90, 0.016);
      }
      expect(shown, greaterThan(80));
    });
  });
}
