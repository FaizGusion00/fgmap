import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/toll_finder.dart';
import 'package:fgmap/features/route_preview/data/valhalla_codec.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Laluan lurus ~11 km ke utara di Kuala Lumpur (0.1 darjah latitud).
List<GeoPoint> _route() => [
  for (var i = 0; i <= 100; i++) GeoPoint(3.0 + i * 0.001, 101.7),
];

({String id, GeoPoint point, String? name}) _node(
  String id,
  double lat,
  double lng, [
  String? name,
]) => (id: id, point: GeoPoint(lat, lng), name: name);

String _rates(List<Map<String, Object?>> plazas, {int version = 1}) =>
    jsonEncode({
      'version': version,
      'lastVerified': '2026-10-01',
      'plazas': plazas,
    });

Map<String, Object?> _plaza({
  double lat = 3.05,
  double lng = 101.7,
  Object? rates = const {'1': 2.5, '4': 1.0},
  String type = 'open',
  bool withSource = true,
}) => {
  'id': 'p',
  'lat': lat,
  'lng': lng,
  'type': type,
  'ratesRm': rates,
  if (withSource) ...{
    'source': 'https://contoh.example/kadar',
    'verifiedOn': '2026-10-01',
  },
};

void main() {
  group('matchTollPlazas', () {
    test(
      'nod dalam 40 m dipadankan; yang jauh dibuang; disusun sepanjang laluan',
      () {
        final plazas = matchTollPlazas(_route(), [
          _node('far', 3.05, 101.71), // ~1.1 km dari laluan
          _node('b', 3.08, 101.7003, 'Plaza B'), // ~33 m
          _node('a', 3.02, 101.7),
        ]);
        expect(plazas.map((p) => p.id), ['a', 'b']);
        expect(plazas.first.alongM, lessThan(plazas.last.alongM));
        expect(plazas.last.name, 'Plaza B');
      },
    );

    test('palang berdekatan (<=150 m) dikelompokkan sebagai satu plaza', () {
      final plazas = matchTollPlazas(_route(), [
        _node('1', 3.050, 101.70005),
        _node('2', 3.0505, 101.69995),
        _node('3', 3.0510, 101.70005),
        _node('4', 3.0700, 101.7), // plaza lain, ~2 km
      ]);
      expect(plazas, hasLength(2));
      expect(plazas.first.id, '1');
    });

    test('tiada laluan atau tiada nod: kosong', () {
      expect(matchTollPlazas(const [], [_node('x', 3, 101)]), isEmpty);
      expect(matchTollPlazas(_route(), const []), isEmpty);
    });
  });

  group('TollRates.parse', () {
    test('entri sah dihuraikan; sumber dan tarikh pengesahan wajib', () {
      final rates = TollRates.parse(
        _rates([_plaza(), _plaza(withSource: false, lat: 3.06)]),
      );
      expect(rates.isEmpty, isFalse);
      expect(rates.lastVerified, '2026-10-01');
      final est = rates.estimate([
        const TollPlaza(id: '1', point: GeoPoint(3.05, 101.7), alongM: 0),
        const TollPlaza(id: '2', point: GeoPoint(3.06, 101.7), alongM: 1),
      ], RouteVehicle.car);
      expect(est.knownRm, 2.5);
      expect(
        est.unknownCount,
        1,
        reason: 'entri tanpa sumber tidak dipercayai',
      );
    });

    test(
      'fail rosak, versi lain, bukan objek, null: kosong (app tidak rosak)',
      () {
        for (final bad in [
          '{bukan json',
          _rates([_plaza()], version: 2),
          '[]',
          null,
          jsonEncode({'version': 1, 'plazas': 'x'}),
        ]) {
          expect(TollRates.parse(bad).isEmpty, isTrue, reason: '$bad');
        }
      },
    );

    test('sistem tertutup, kadar negatif atau tiada kadar: dilangkau', () {
      final rates = TollRates.parse(
        _rates([
          _plaza(type: 'closed'),
          _plaza(rates: {'1': -3}, lat: 3.06),
          _plaza(rates: <String, Object?>{}, lat: 3.07),
          _plaza(rates: 'x', lat: 3.08),
        ]),
      );
      expect(rates.isEmpty, isTrue);
    });

    test('aset yang dihantar sah dan kosong (tiada angka direka)', () {
      final file = File('assets/tolls/my_tolls.json').readAsStringSync();
      final json = jsonDecode(file) as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['plazas'], isEmpty);
      expect(TollRates.parse(file).isEmpty, isTrue);
    });
  });

  group('TollRates.estimate', () {
    final rates = TollRates.parse(
      _rates([
        _plaza(lat: 3.02, rates: {'1': 2.0, '4': 0.0}),
        _plaza(lat: 3.05, rates: {'1': 3.5}),
      ]),
    );
    TollPlaza at(double lat) =>
        TollPlaza(id: '$lat', point: GeoPoint(lat, 101.7), alongM: lat);

    test('semua plaza diketahui: jumlah tepat', () {
      final e = rates.estimate([at(3.02), at(3.05)], RouteVehicle.car);
      expect(e.isExact, isTrue);
      expect(e.knownRm, 5.5);
    });

    test('sebahagian diketahui: had bawah', () {
      final e = rates.estimate([at(3.02), at(3.09)], RouteVehicle.car);
      expect(e.isPartial, isTrue);
      expect(e.knownRm, 2.0);
      expect(e.unknownCount, 1);
    });

    test('tiada yang diketahui: tidak diketahui, bukan RM 0', () {
      final e = rates.estimate([at(3.09)], RouteVehicle.car);
      expect(e.isUnknown, isTrue);
      expect(e.knownRm, 0);
    });

    test(
      'motosikal (kelas 4) hanya jika kadar wujud; tidak dianggap percuma',
      () {
        final bike = rates.estimate([
          at(3.02),
          at(3.05),
        ], RouteVehicle.motorcycle);
        expect(bike.knownRm, 0.0);
        expect(bike.unknownCount, 1, reason: 'plaza kedua tiada kadar kelas 4');
        expect(bike.isPartial, isTrue);
      },
    );

    test('padanan plaza dalam 250 m sahaja', () {
      final near = rates.estimate([at(3.0215)], RouteVehicle.car); // ~165 m
      expect(near.isExact, isTrue);
      final far = rates.estimate([at(3.0230)], RouteVehicle.car); // ~330 m
      expect(far.isUnknown, isTrue);
    });

    test('tiada plaza: tiada anggaran', () {
      final e = rates.estimate(const [], RouteVehicle.car);
      expect(e.plazaCount, 0);
      expect(e.isExact, isFalse);
      expect(e.isUnknown, isFalse);
    });
  });

  group('parseTollNodes', () {
    test('menghuraikan nod; mengabaikan yang tiada koordinat', () {
      final nodes = parseTollNodes(
        jsonEncode({
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 3.05,
              'lon': 101.7,
              'tags': {'name': ' Sungai Besi '},
            },
            {'type': 'node', 'id': 2},
            {'type': 'node', 'id': 3, 'lat': 999, 'lon': 101.7},
          ],
        }),
      );
      expect(nodes, hasLength(1));
      expect(nodes.single.name, 'Sungai Besi');
    });

    test('badan kosong, HTML, atau runtime error: TollLookupFailure', () {
      for (final bad in [
        null,
        '',
        '<html>',
        jsonEncode({'remark': 'runtime error: x', 'elements': []}),
      ]) {
        expect(
          () => parseTollNodes(bad),
          throwsA(isA<TollLookupFailure>()),
          reason: '$bad',
        );
      }
    });
  });

  group('OverpassTollFinder', () {
    final option = RouteOption(
      distanceM: 11000,
      durationS: 600,
      hasTolls: true,
      points: _route(),
    );
    final body = jsonEncode({
      'elements': [
        {
          'type': 'node',
          'id': 7,
          'lat': 3.05,
          'lon': 101.7,
          'tags': {'barrier': 'toll_booth'},
        },
      ],
    });

    test(
      'POST kotak sempadan laluan; plaza dipadankan; hasil dicache',
      () async {
        final adapter = StubAdapter((_) => StubAdapter.json(jsonDecode(body)));
        final finder = OverpassTollFinder(Dio()..httpClientAdapter = adapter, [
          'https://m1.example/api/interpreter',
        ]);
        final plazas = await finder.find(option);
        expect(plazas.single.id, '7');
        expect(adapter.lastRequest!.method, 'POST');
        final query = Uri.decodeQueryComponent(
          adapter.lastBodyText!.substring(5),
        );
        expect(query, contains('"barrier"="toll_booth"'));
        expect(query, contains('"highway"="toll_gantry"'));
        expect(query, contains('2.99800,101.69800,3.10200,101.70200'));

        adapter.lastRequest = null;
        await finder.find(option);
        expect(
          adapter.lastRequest,
          isNull,
          reason: 'dari cache, tiada rangkaian',
        );
      },
    );

    test('cermin pertama gagal -> cermin kedua', () async {
      final hosts = <String>[];
      final finder = OverpassTollFinder(
        Dio()
          ..httpClientAdapter = StubAdapter((o) {
            hosts.add(o.uri.host);
            return o.uri.host == 'm1.example'
                ? StubAdapter.text('x', status: 503)
                : StubAdapter.json(jsonDecode(body));
          }),
        ['https://m1.example/i', 'https://m2.example/i'],
      );
      expect(await finder.find(option), isNotEmpty);
      expect(hosts, ['m1.example', 'm2.example']);
    });

    test('semua cermin gagal: TollLookupFailure', () async {
      final finder = OverpassTollFinder(
        Dio()
          ..httpClientAdapter = StubAdapter(
            (_) => StubAdapter.text('x', status: 503),
          ),
        ['https://m1.example/i'],
      );
      expect(() => finder.find(option), throwsA(isA<TollLookupFailure>()));
    });
  });

  group('jalan bertol daripada Valhalla', () {
    test(
      'respons sebenar KLCC-KLIA: nama dan rujukan jalan bertol mengikut susunan',
      () {
        final route = parseRouteResponse(
          File(
            'test/fixtures/valhalla_public_klcc_klia.json',
          ).readAsStringSync(),
          source: RouteSource.online,
        ).first;
        final roads = route.tollRoads;
        expect(roads, isNotEmpty);
        expect(roads.first.label, 'Lebuhraya Maju (E20)');
        expect(roads.map((r) => r.ref), contains('E6'));
        // Jarak di jalan bertol kurang daripada jumlah jarak laluan.
        expect(route.tollLengthM, greaterThan(20000));
        expect(route.tollLengthM, lessThan(route.distanceM));
      },
    );

    test('laluan tanpa manuver bertol: tiada jalan bertol', () {
      expect(sampleOption().tollRoads, isEmpty);
      expect(sampleOption().tollLengthM, 0);
    });
  });

  test('routeKey stabil untuk laluan yang sama', () {
    final a = sampleOption();
    expect(routeKey(a), routeKey(a.withLabel(RouteLabel.noTolls)));
  });
}
