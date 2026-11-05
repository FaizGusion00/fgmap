import 'dart:convert';
import 'dart:io';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/toll_finder.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'package:flutter_test/flutter_test.dart';

/// Laluan sebenar Valhalla Setia Alam -> Johor Bahru (test/fixtures/routes/setia_alam_jb.json).
RouteOption _setiaAlamJb() {
  final doc =
      jsonDecode(
            File('test/fixtures/routes/setia_alam_jb.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return RouteOption(
    distanceM: doc['distanceM'] as int,
    durationS: doc['durationS'] as int,
    hasTolls: true,
    points: [
      for (final p in doc['points'] as List)
        GeoPoint(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
    ],
    maneuvers: [
      for (final m in (doc['maneuvers'] as List).cast<Map<String, dynamic>>())
        Maneuver(
          type: m['type'] as int,
          streetNames: (m['streetNames'] as List).cast<String>(),
          lengthM: m['lengthM'] as int,
          timeS: m['timeS'] as int,
          beginShapeIndex: m['beginShapeIndex'] as int,
          toll: m['toll'] as bool,
        ),
    ],
  );
}

/// Sistem tertutup kecil: A dan B. Matriks 2 x 2 (A->B = 5.00).
String _closed({
  required Map<String, Object?> a,
  required Map<String, Object?> b,
}) => jsonEncode({
  'version': 2,
  'closed': [
    {
      'id': '9',
      'name': 'Ujian',
      'plazas': [a, b],
      'matrix': [null, 5.0, 5.0, null],
    },
  ],
  'open': <Object>[],
});

List<GeoPoint> _north(double fromLat, double toLat) => [
  for (var i = 0; i <= 100; i++)
    GeoPoint(fromLat + (toLat - fromLat) * i / 100, 101.7),
];

RouteOption _option(List<GeoPoint> pts, List<Maneuver> ms) => RouteOption(
  distanceM: 10000,
  durationS: 600,
  hasTolls: true,
  points: pts,
  maneuvers: ms,
);

void main() {
  final rates = TollRates.parse(
    File('assets/tolls/my_tolls.json').readAsStringSync(),
  );

  test(
    'regresi penguji: Setia Alam -> JB pada laluan sebenar = Setia Alam-Skudai RM37.15 + Kempas RM1.72',
    () async {
      final route = _setiaAlamJb();
      final plazas = await DatasetTollFinder(() async => rates).find(route);
      final e = rates.estimate(plazas, RouteVehicle.car, route: route);
      expect(e.isExact, isTrue);
      // Kadar rasmi LLM: Setia Alam -> Skudai (tertutup) + Kempas (harga tetap PLUS di JB).
      expect(e.plazaCount, 3);
      expect(e.knownRm, closeTo(37.15 + 1.72, 0.001));
    },
  );

  test('dataset: plaza persimpangan membawa titik booth sebenar', () {
    final doc =
        jsonDecode(File('assets/tolls/my_tolls.json').readAsStringSync())
            as Map<String, dynamic>;
    final plus = (doc['closed'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['id'] == '1');
    final pd = (plus['plazas'] as List).cast<Map<String, dynamic>>().firstWhere(
      (p) => p['name'] == 'PORT DICKSON (U)',
    );
    expect(pd['booths'], isA<List<dynamic>>());
    expect((pd['booths'] as List), isNotEmpty);
  });

  group('padanan booth', () {
    test('laluan utama di sebelah booth susur (60 m) tidak dikira', () async {
      // Purata plaza tepat di atas laluan (data lama yang salah), booth sebenar 60 m ke timur.
      final r = TollRates.parse(
        _closed(
          a: {
            'id': '1',
            'name': 'A',
            'lat': 3.01,
            'lng': 101.7,
            'booths': [
              [3.01, 101.70055],
            ],
          },
          b: {
            'id': '2',
            'name': 'B',
            'lat': 3.09,
            'lng': 101.7,
            'booths': [
              [3.09, 101.7],
            ],
          },
        ),
      );
      final route = _option(_north(3.0, 3.1), const [
        Maneuver(
          type: 1,
          streetNames: ['E2'],
          lengthM: 11000,
          timeS: 600,
          beginShapeIndex: 0,
          toll: true,
        ),
      ]);
      final plazas = await DatasetTollFinder(() async => r).find(route);
      expect(plazas, hasLength(1));
      expect(plazas.single.name, 'B');
    });

    test(
      'booth nod jalan: laluan utama 15 m di sebelah booth susur (SPE di Setiawangsa) tidak dikira',
      () async {
        Map<String, Object?> plaza(String id, String name, double lng) => {
          'id': id,
          'name': name,
          'lat': 3.05,
          'lng': lng,
          'booths': [
            [3.05, lng],
          ],
          'boothsOnWay': true,
        };
        // A: booth susur 15 m ke timur laluan; B: booth tepat pada laluan.
        final r = TollRates.parse(
          _closed(
            a: plaza('1', 'A', 101.70014),
            b: {
              ...plaza('2', 'B', 101.7),
              'lat': 3.09,
              'booths': [
                [3.09, 101.7],
              ],
            },
          ),
        );
        final route = _option(_north(3.0, 3.1), const []);
        final plazas = await DatasetTollFinder(() async => r).find(route);
        expect(plazas.map((p) => p.name), ['B']);
      },
    );

    test('data lama tanpa booth: titik plaza dengan toleransi lama', () async {
      final r = TollRates.parse(
        _closed(
          a: {'id': '1', 'name': 'A', 'lat': 3.01, 'lng': 101.7004},
          b: {'id': '2', 'name': 'B', 'lat': 3.09, 'lng': 101.7},
        ),
      );
      final route = _option(_north(3.0, 3.1), const []);
      final plazas = await DatasetTollFinder(() async => r).find(route);
      expect(plazas.map((p) => p.name), ['A', 'B']);
      expect(r.estimate(plazas, RouteVehicle.car).knownRm, closeTo(5.0, 0.001));
    });
  });

  group('jaring keselamatan masuk/keluar tidak dikesan', () {
    // Laluan 100 km bertol dari km 0 hingga km 100.
    final pts = _north(2.5, 3.4);
    final along = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      along.add(along.last + distanceMeters(pts[i - 1], pts[i]));
    }
    final route = _option(pts, const [
      Maneuver(
        type: 1,
        streetNames: ['E2'],
        lengthM: 100000,
        timeS: 3600,
        beginShapeIndex: 0,
        toll: true,
      ),
    ]);
    const nilaiU = GeoPoint(2.83301, 101.79784);
    const ainsdale = GeoPoint(2.73348, 101.8839);
    TollPlaza at(GeoPoint p, double alongM) =>
        TollPlaza(id: '$alongM', point: p, alongM: alongM);

    test(
      'hanya dua plaza bersebelahan di tengah 100 km jalan bertol: tidak diketahui, bukan RM1.72',
      () {
        final plazas = [at(nilaiU, 40000), at(ainsdale, 52000)];
        // Tanpa laluan: tingkah laku lama (pasangan yang dikesan).
        expect(
          rates.estimate(plazas, RouteVehicle.car).knownRm,
          closeTo(1.72, 0.001),
        );
        final e = rates.estimate(plazas, RouteVehicle.car, route: route);
        expect(e.isUnknown, isTrue);
        expect(e.knownRm, 0);
      },
    );

    test('plaza dekat hujung rentang bertol: harga biasa', () {
      final plazas = [at(nilaiU, 2000), at(ainsdale, along.last - 3000)];
      final e = rates.estimate(plazas, RouteVehicle.car, route: route);
      expect(e.isExact, isTrue);
      expect(e.knownRm, closeTo(1.72, 0.001));
    });
  });
}
