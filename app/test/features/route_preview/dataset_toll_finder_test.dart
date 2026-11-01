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

  test('PLUS Jalan Duta -> Ipoh (S): RM daripada dataset, tanpa rangkaian', () async {
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
  });

  test('laluan tanpa plaza berdekatan: tiada plaza', () async {
    final finder = DatasetTollFinder(() async => rates);
    final plazas = await finder.find(
      route(_line(const [GeoPoint(5.9, 116.0), GeoPoint(5.95, 116.1)])),
    );
    expect(plazas, isEmpty);
  });

  test('hibrid: Overpass hanya bila dataset kosong dan jalan bertol panjang', () async {
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
  });
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
