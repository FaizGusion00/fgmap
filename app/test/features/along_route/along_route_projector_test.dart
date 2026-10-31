import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/along_route/domain/along_route_projector.dart';
import 'package:flutter_test/flutter_test.dart';

// Garis lurus di khatulistiwa: 0.01 darjah longitud ~ 1.11 km.
const _a = GeoPoint(0, 0);
const _b = GeoPoint(0, 0.05);
const _c = GeoPoint(0, 0.10);
final _route = [_a, _b, _c];

void main() {
  group('cumulativeMeters', () {
    test('kosong dan satu titik', () {
      expect(cumulativeMeters(const []), isEmpty);
      expect(cumulativeMeters(const [_a]), [0]);
    });

    test('menaik dan panjang sama dengan titik', () {
      final m = cumulativeMeters(_route);
      expect(m.length, 3);
      expect(m.first, 0);
      expect(m[1], closeTo(distanceMeters(_a, _b), 0.01));
      expect(m[2], closeTo(distanceMeters(_a, _c), 1));
    });
  });

  group('samplePolyline', () {
    test('asal dan akhir sentiasa ada', () {
      final s = samplePolyline(_route, everyM: 1500);
      expect(s.first, _a);
      expect(s.last, _c);
    });

    test('jarak antara sampel kira-kira everyM', () {
      final s = samplePolyline(_route, everyM: 2000);
      for (var i = 1; i < s.length - 1; i++) {
        expect(distanceMeters(s[i - 1], s[i]), closeTo(2000, 5));
      }
    });

    test('bilangan sampel munasabah (~11.1 km / 1.5 km)', () {
      final s = samplePolyline(_route, everyM: 1500);
      // 1 asal + 7 antara (1.5..10.5 km) + 1 akhir (baki > 50 m).
      expect(s.length, 9);
    });

    test('titik akhir tidak digandakan jika sudah dekat (<50 m)', () {
      // Panjang ~ 3000.0 m tepat pada kelipatan; baki < 50 m tidak menambah akhir.
      const end = GeoPoint(0, 3000 / 111194.9266);
      final s = samplePolyline([_a, end], everyM: 1000);
      expect(distanceMeters(s.last, end), lessThan(50));
      expect(s.length, lessThanOrEqualTo(4));
    });

    test('kes tepi: kosong, satu titik, panjang sifar', () {
      expect(samplePolyline(const []), isEmpty);
      expect(samplePolyline(const [_a]), [_a]);
      expect(samplePolyline(const [_a, _a]), [_a]);
    });

    test('laluan pendek memberi asal + akhir', () {
      final s = samplePolyline([_a, const GeoPoint(0, 0.005)]);
      expect(s, [_a, const GeoPoint(0, 0.005)]);
    });
  });

  group('projectOntoPolyline', () {
    test('kurang daripada 2 titik memberi null', () {
      expect(projectOntoPolyline(const [_a], _a), isNull);
      expect(projectOntoPolyline(const [], _a), isNull);
    });

    test('titik di tepi laluan: alongM dan crossTrackM', () {
      const p = GeoPoint(0.001, 0.05); // ~111 m utara titik tengah
      final r = projectOntoPolyline(_route, p)!;
      expect(r.alongM, closeTo(distanceMeters(_a, _b), 5));
      expect(r.crossTrackM, closeTo(111, 3));
      expect(r.snapped.lat, closeTo(0, 1e-6));
      expect(r.snapped.lng, closeTo(0.05, 1e-4));
    });

    test('memilih segmen paling hampir (segmen kedua)', () {
      const p = GeoPoint(-0.0005, 0.08);
      final r = projectOntoPolyline(_route, p)!;
      expect(r.alongM, closeTo(distanceMeters(_a, const GeoPoint(0, 0.08)), 5));
      expect(r.alongM, greaterThan(distanceMeters(_a, _b)));
      expect(r.crossTrackM, closeTo(55.6, 3));
    });

    test('sebelum permulaan dan selepas penghujung dikepit', () {
      final before = projectOntoPolyline(_route, const GeoPoint(0, -0.01))!;
      expect(before.alongM, closeTo(0, 0.5));
      final after = projectOntoPolyline(_route, const GeoPoint(0, 0.12))!;
      expect(after.alongM, closeTo(distanceMeters(_a, _c), 1));
    });
  });

  group('dedupeByProximity', () {
    GeoPoint pt(({GeoPoint p, double x}) i) => i.p;
    double xt(({GeoPoint p, double x}) i) => i.x;

    test(
      'buang pendua dalam maxM dan kekalkan yang lebih hampir ke laluan',
      () {
        const far = (p: GeoPoint(0, 0.01), x: 60.0);
        const near = (p: GeoPoint(0.0002, 0.01), x: 10.0); // ~22 m
        final out = dedupeByProximity(
          items: [far, near],
          pointOf: pt,
          crossTrackOf: xt,
        );
        expect(out, [near]);
      },
    );

    test('kekalkan yang pertama jika pendua lebih jauh dari laluan', () {
      const first = (p: GeoPoint(0, 0.01), x: 10.0);
      const dup = (p: GeoPoint(0.0002, 0.01), x: 60.0);
      final out = dedupeByProximity(
        items: [first, dup],
        pointOf: pt,
        crossTrackOf: xt,
      );
      expect(out, [first]);
    });

    test('titik berjauhan kekal semua', () {
      final items = [
        (p: const GeoPoint(0, 0.01), x: 1.0),
        (p: const GeoPoint(0, 0.02), x: 1.0), // ~1.1 km
        (p: const GeoPoint(0, 0.03), x: 1.0),
      ];
      final out = dedupeByProximity(
        items: items,
        pointOf: pt,
        crossTrackOf: xt,
      );
      expect(out.length, 3);
    });

    test('maxM boleh dilaraskan', () {
      final items = [
        (p: const GeoPoint(0, 0.01), x: 5.0),
        (p: const GeoPoint(0, 0.0115), x: 5.0), // ~167 m
      ];
      expect(
        dedupeByProximity(items: items, pointOf: pt, crossTrackOf: xt).length,
        2,
      );
      expect(
        dedupeByProximity(
          items: items,
          pointOf: pt,
          crossTrackOf: xt,
          maxM: 300,
        ).length,
        1,
      );
    });

    test('senarai kosong', () {
      expect(
        dedupeByProximity<({GeoPoint p, double x})>(
          items: const [],
          pointOf: pt,
          crossTrackOf: xt,
        ),
        isEmpty,
      );
    });
  });
}
