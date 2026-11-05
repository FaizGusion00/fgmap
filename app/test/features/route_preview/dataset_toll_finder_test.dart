import 'dart:io';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/toll_finder.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garisan lurus padat antara titik (cukup untuk padanan plaza di hujung-hujung).
List<GeoPoint> _line(List<GeoPoint> stops) {
  final out = <GeoPoint>[];
  for (var i = 0; i < stops.length - 1; i++) {
    final a = stops[i];
    final b = stops[i + 1];
    for (var t = 0; t < 200; t++) {
      out.add(
        GeoPoint(
          a.lat + (b.lat - a.lat) * t / 200,
          a.lng + (b.lng - a.lng) * t / 200,
        ),
      );
    }
  }
  out.add(stops.last);
  return out;
}

void main() {
  final rates = TollRates.parse(
    File('assets/tolls/my_tolls.json').readAsStringSync(),
  );

  RouteOption route(List<GeoPoint> points, {bool tolls = true}) => RouteOption(
    distanceM: 200000,
    durationS: 7200,
    hasTolls: tolls,
    points: points,
    maneuvers: [
      if (tolls)
        const Maneuver(
          type: 8,
          streetNames: ['E1'],
          lengthM: 190000,
          timeS: 6800,
          beginShapeIndex: 0,
          toll: true,
        ),
    ],
  );

  test(
    'PLUS Jalan Duta -> Ipoh (S): RM daripada dataset, tanpa rangkaian',
    () async {
      final finder = DatasetTollFinder(() async => rates);
      // Mula sebelum plaza Jalan Duta, tamat selepas Ipoh (S).
      final points = _line(const [
        GeoPoint(3.1700, 101.6600),
        GeoPoint(3.17576, 101.65576),
        GeoPoint(4.58424, 101.14421),
        GeoPoint(4.5900, 101.1400),
      ]);
      final plazas = await finder.find(route(points));
      expect(plazas.length, greaterThanOrEqualTo(2));
      final estimate = rates.estimate(plazas, RouteVehicle.car);
      expect(estimate.isExact, isTrue);
      expect(estimate.knownRm, closeTo(21.73, 0.001));
    },
  );

  test('laluan tanpa plaza berdekatan: tiada plaza', () async {
    final finder = DatasetTollFinder(() async => rates);
    final plazas = await finder.find(
      route(_line(const [GeoPoint(5.9, 116.0), GeoPoint(5.95, 116.1)])),
    );
    expect(plazas, isEmpty);
  });

  test(
    'hibrid: Overpass hanya bila dataset kosong dan jalan bertol panjang',
    () async {
      var fallbackCalls = 0;
      final hybrid = HybridTollFinder(
        DatasetTollFinder(() async => rates),
        _CountingFinder(() => fallbackCalls++),
      );
      await hybrid.find(
        route(_line(const [GeoPoint(5.9, 116.0), GeoPoint(5.95, 116.1)])),
      );
      expect(fallbackCalls, 1);
      await hybrid.find(
        route(
          _line(const [GeoPoint(5.9, 116.0), GeoPoint(5.95, 116.1)]),
          tolls: false,
        ),
      );
      expect(fallbackCalls, 1);
    },
  );

  test(
    'SPE dan Besraya (kadar diumumkan): harga terus, bukan "tidak diketahui"',
    () async {
      final finder = DatasetTollFinder(() async => rates);
      // Setiawangsa -> Chan Sow Lin -> Loke Yew (Besraya).
      final points = _line(const [
        GeoPoint(3.1830, 101.7395),
        GeoPoint(3.18065, 101.73793),
        GeoPoint(3.12847, 101.71699),
        GeoPoint(3.12079, 101.72471),
        GeoPoint(3.1180, 101.7260),
      ]);
      final plazas = await finder.find(route(points));
      final e = rates.estimate(plazas, RouteVehicle.car);
      expect(e.plazaCount, 3);
      expect(e.isExact, isTrue);
      expect(e.knownRm, closeTo(3.50 + 3.50 + 1.85, 0.001));
    },
  );

  TollPlaza plazaAt(GeoPoint p, double alongM) =>
      TollPlaza(id: '$alongM', point: p, alongM: alongM);

  test(
    'keluar di Jalan Duta, merentas KL tanpa tol, masuk semula di Sungai Besi: dua perjalanan',
    () {
      const rawang = GeoPoint(3.30439, 101.54864);
      const duta = GeoPoint(3.17576, 101.65576);
      const sgBesi = GeoPoint(3.03919, 101.70581);
      const kajang = GeoPoint(2.98548, 101.74412);
      final pts = _line(const [rawang, duta, sgBesi, kajang]);
      // Rawang->Duta bertol, Duta->Sg Besi jalan bandar (tanpa tol), Sg Besi->Kajang bertol.
      final opt = RouteOption(
        distanceM: 60000,
        durationS: 3600,
        hasTolls: true,
        points: pts,
        maneuvers: const [
          Maneuver(
            type: 1,
            streetNames: ['E1'],
            lengthM: 20000,
            timeS: 900,
            beginShapeIndex: 0,
            toll: true,
          ),
          Maneuver(
            type: 9,
            streetNames: ['Jalan Kuching'],
            lengthM: 18000,
            timeS: 1800,
            beginShapeIndex: 205,
          ),
          Maneuver(
            type: 10,
            streetNames: ['E2'],
            lengthM: 8000,
            timeS: 400,
            beginShapeIndex: 400,
            toll: true,
          ),
        ],
      );
      double alongOf(GeoPoint p) {
        var best = 0;
        var d = double.infinity;
        for (var k = 0; k < pts.length; k++) {
          final x = distanceMeters(pts[k], p);
          if (x < d) {
            d = x;
            best = k;
          }
        }
        var a = 0.0;
        for (var k = 1; k <= best; k++) {
          a += distanceMeters(pts[k - 1], pts[k]);
        }
        return a;
      }

      final plazas = [
        for (final p in const [rawang, duta, sgBesi, kajang])
          plazaAt(p, alongOf(p)),
      ];
      final split = rates.estimate(plazas, RouteVehicle.car, route: opt);
      expect(split.isExact, isTrue);
      expect(split.knownRm, closeTo(2.95 + 0.82, 0.001));
      // Tanpa maklumat laluan: tingkah laku lama (masuk pertama, keluar terakhir).
      expect(
        rates.estimate(plazas, RouteVehicle.car).knownRm,
        closeTo(10.99, 0.001),
      );
    },
  );

  test(
    'plaza kembar (U)/(S) pada titik sama: pasangan yang ada kadar dipilih',
    () {
      const juru = GeoPoint(5.3238, 100.43656);
      const pd = GeoPoint(2.68876, 101.93213);
      final there = rates.estimate([
        plazaAt(juru, 0),
        plazaAt(pd, 400000),
      ], RouteVehicle.car);
      final back = rates.estimate([
        plazaAt(pd, 0),
        plazaAt(juru, 400000),
      ], RouteVehicle.car);
      expect(there.isExact, isTrue);
      expect(there.knownRm, closeTo(44.44, 0.001));
      expect(back.isExact, isTrue);
      expect(back.knownRm, closeTo(44.44, 0.001));
    },
  );

  test(
    'laluan tanpa tol (Valhalla): plaza jalan selari tidak dikira',
    () async {
      final finder = DatasetTollFinder(() async => rates);
      final points = _line(const [
        GeoPoint(3.1700, 101.6600),
        GeoPoint(3.17576, 101.65576),
        GeoPoint(3.1800, 101.6500),
      ]);
      expect(await finder.find(route(points, tolls: false)), isEmpty);
    },
  );
}

class _CountingFinder implements TollPlazaFinder {
  _CountingFinder(this.onFind);

  final void Function() onFind;

  @override
  Future<List<TollPlaza>> find(RouteOption route) async {
    onFind();
    return const [];
  }
}
