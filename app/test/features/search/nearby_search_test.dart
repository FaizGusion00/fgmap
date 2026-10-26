import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/nearby_search.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:fgmap/features/search/domain/place.dart';

import '../../helpers/fakes.dart';

// Badan SINTETIK dalam bentuk Overpass `out tags center` (container pembangunan tidak boleh
// mencapai Overpass). Koordinat sekitar Puncak Alam.
const _center = GeoPoint(3.2290, 101.4260);

Map<String, Object?> _overpass(List<Map<String, Object?>> elements) => {
  'version': 0.6,
  'elements': elements,
};

const _petronas = {
  'type': 'node',
  'id': 1,
  'lat': 3.2300,
  'lon': 101.4270,
  'tags': {
    'amenity': 'fuel',
    'name': 'Petronas',
    'brand': 'Petronas',
    'addr:street': 'Persiaran Puncak Alam',
  },
};
const _shellWay = {
  'type': 'way',
  'id': 2,
  'center': {'lat': 3.2320, 'lon': 101.4280},
  'tags': {'amenity': 'fuel', 'brand': 'Shell'},
};
const _unnamed = {
  'type': 'node',
  'id': 3,
  'lat': 3.2291,
  'lon': 101.4261,
  'tags': {'amenity': 'fuel'},
};
const _noCoords = {
  'type': 'way',
  'id': 4,
  'tags': {'amenity': 'fuel', 'name': 'Tiada koordinat'},
};

void main() {
  group('NearbyCategory', () {
    test('pertanyaan Overpass: around, penapis tag, out center', () {
      final q = NearbyCategory.fuel.overpassQuery(3.229, 101.426, 3000);
      expect(q, contains('["amenity"="fuel"](around:3000,3.229,101.426)'));
      expect(q, contains('out tags center'));
      expect(q, startsWith('[out:json]'));
    });

    test(
      'masjid termasuk surau (place_of_worship muslim) dan bangunan masjid',
      () {
        final q = NearbyCategory.mosque.overpassQuery(3.2, 101.4, 3000);
        expect(
          q,
          contains('["amenity"="place_of_worship"]["religion"="muslim"]'),
        );
        expect(q, contains('["building"="mosque"]'));
      },
    );

    test('radius diperluas tiga kali ganda, dihadkan 15 km', () {
      expect(NearbyCategory.fuel.widenedRadiusM, 9000);
      expect(NearbyCategory.hospital.widenedRadiusM, 15000);
    });
  });

  group('parseOverpassResponse', () {
    test('menghurai nod dan bangunan (center), nama sandaran dan alamat', () {
      final places = parseOverpassResponse(
        jsonEncode(_overpass([_shellWay, _petronas, _noCoords, _unnamed])),
        center: _center,
        fallbackName: 'Stesen minyak',
      );
      // _noCoords dibuang; yang tidak bernama (15 m, +600 m penalti) kekal selepas Shell yang bernama (~400 m).
      expect(places.map((p) => p.name), ['Petronas', 'Shell', 'Stesen minyak']);
      final petronas = places.first;
      expect(petronas.osmType, 'N');
      expect(petronas.category, 'fuel');
      expect(petronas.subtitle, 'Persiaran Puncak Alam');
      final shell = places[1];
      expect(shell.osmType, 'W');
      expect(shell.point, const GeoPoint(3.2320, 101.4280));
    });

    test('entri bernama sama dalam 60 m digabung', () {
      final dup = {..._petronas, 'id': 9, 'lat': 3.23005, 'lon': 101.42705};
      final places = parseOverpassResponse(
        jsonEncode(_overpass([_petronas, dup])),
        center: _center,
        fallbackName: 'x',
      );
      expect(places, hasLength(1));
    });

    test('remark runtime error -> unavailable, HTML -> unavailable', () {
      expect(
        () => parseOverpassResponse(
          jsonEncode({'elements': [], 'remark': 'runtime error: timeout'}),
          center: _center,
          fallbackName: 'x',
        ),
        throwsA(
          isA<GeocodeFailure>().having(
            (f) => f.kind,
            'kind',
            GeocodeFailureKind.unavailable,
          ),
        ),
      );
      expect(
        () => parseOverpassResponse(
          '<html>busy</html>',
          center: _center,
          fallbackName: 'x',
        ),
        throwsA(isA<GeocodeFailure>()),
      );
    });

    test('tiada elemen -> kosong (jawapan sah)', () {
      expect(
        parseOverpassResponse(
          jsonEncode(_overpass([])),
          center: _center,
          fallbackName: 'x',
        ),
        isEmpty,
      );
    });
  });

  group('OverpassNearbySearch', () {
    Dio dioWith(ResponseBody Function(RequestOptions) respond) =>
        Dio()..httpClientAdapter = StubAdapter(respond);

    test('menghantar data Overpass dengan radius kategori', () async {
      final adapter = StubAdapter(
        (_) => StubAdapter.json(_overpass([_petronas, _shellWay, _unnamed])),
      );
      final search = OverpassNearbySearch(Dio()..httpClientAdapter = adapter, [
        'https://m1.example/api/interpreter',
      ]);
      final places = await search.search(
        NearbyCategory.fuel,
        _center,
        fallbackName: 'Stesen minyak',
      );
      expect(places, hasLength(3));
      final data = adapter.lastRequest!.uri.queryParameters['data']!;
      expect(data, contains('around:3000,3.229,101.426'));
    });

    test('hasil terlalu sedikit: radius diperluas sekali', () async {
      final requests = <String>[];
      final search = OverpassNearbySearch(
        dioWith((o) {
          requests.add(o.uri.queryParameters['data']!);
          return StubAdapter.json(_overpass([_petronas]));
        }),
        ['https://m1.example/api/interpreter'],
      );
      await search.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      expect(requests, hasLength(2));
      expect(requests[0], contains('around:3000'));
      expect(requests[1], contains('around:9000'));
    });

    test('cukup hasil: satu permintaan sahaja', () async {
      final requests = <String>[];
      final search = OverpassNearbySearch(
        dioWith((o) {
          requests.add(o.uri.toString());
          return StubAdapter.json(
            _overpass([
              _petronas,
              _shellWay,
              {
                ..._unnamed,
                'tags': {'amenity': 'fuel', 'name': 'Caltex'},
              },
            ]),
          );
        }),
        ['https://m1.example/api/interpreter'],
      );
      await search.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      expect(requests, hasLength(1));
    });

    test('cermin pertama gagal -> cermin kedua digunakan', () async {
      final hosts = <String>[];
      final search = OverpassNearbySearch(
        dioWith((o) {
          hosts.add(o.uri.host);
          if (o.uri.host == 'm1.example') {
            return StubAdapter.text('busy', status: 504);
          }
          return StubAdapter.json(
            _overpass([
              _petronas,
              _shellWay,
              {
                ..._unnamed,
                'tags': {'amenity': 'fuel', 'name': 'Caltex'},
              },
            ]),
          );
        }),
        [
          'https://m1.example/api/interpreter',
          'https://m2.example/api/interpreter',
        ],
      );
      final places = await search.search(
        NearbyCategory.fuel,
        _center,
        fallbackName: 'x',
      );
      expect(hosts, ['m1.example', 'm2.example']);
      expect(places, isNotEmpty);
    });

    test('semua cermin gagal -> GeocodeFailure', () async {
      final search = OverpassNearbySearch(
        dioWith((_) => StubAdapter.text('x', status: 503)),
        [
          'https://m1.example/api/interpreter',
          'https://m2.example/api/interpreter',
        ],
      );
      await expectLater(
        search.search(NearbyCategory.fuel, _center, fallbackName: 'x'),
        throwsA(
          isA<GeocodeFailure>().having(
            (f) => f.kind,
            'kind',
            GeocodeFailureKind.unavailable,
          ),
        ),
      );
    });
  });

  group('FallbackNearbySearch', () {
    test(
      'Overpass gagal -> Nominatim (frasa khas, bounded, disusun ikut jarak)',
      () async {
        final nominatim = [
          {
            'osm_type': 'node',
            'osm_id': 5,
            'lat': '3.2400',
            'lon': '101.4300',
            'category': 'amenity',
            'type': 'fuel',
            'name': 'Jauh',
            'display_name': 'Jauh, Selangor',
          },
          {
            'osm_type': 'node',
            'osm_id': 6,
            'lat': '3.2295',
            'lon': '101.4262',
            'category': 'amenity',
            'type': 'fuel',
            'name': 'Dekat',
            'display_name': 'Dekat, Selangor',
          },
        ];
        final adapter = StubAdapter((_) => StubAdapter.json(nominatim));
        final dio = Dio()..httpClientAdapter = adapter;
        final search = FallbackNearbySearch(
          _AlwaysFails(),
          NominatimNearbySearch(dio, 'https://nominatim.example/search'),
        );
        final places = await search.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(places.map((p) => p.name), ['Dekat', 'Jauh']);
        final q = adapter.lastRequest!.uri.queryParameters;
        expect(q['q'], 'petrol station');
        expect(q['bounded'], '1');
      },
    );

    test('Overpass kosong: kekal kosong, Nominatim tidak dipanggil', () async {
      final secondary = _AlwaysFails();
      final search = FallbackNearbySearch(_Empty(), secondary);
      expect(
        await search.search(NearbyCategory.fuel, _center, fallbackName: 'x'),
        isEmpty,
      );
      expect(secondary.calls, 0);
    });

    test('kedua-duanya gagal: kegagalan Overpass dilaporkan', () async {
      final search = FallbackNearbySearch(
        _AlwaysFails(GeocodeFailureKind.rateLimited),
        _AlwaysFails(GeocodeFailureKind.network),
      );
      await expectLater(
        search.search(NearbyCategory.fuel, _center, fallbackName: 'x'),
        throwsA(
          isA<GeocodeFailure>().having(
            (f) => f.kind,
            'kind',
            GeocodeFailureKind.rateLimited,
          ),
        ),
      );
    });
  });
}

class _AlwaysFails implements NearbySearch {
  _AlwaysFails([this.kind = GeocodeFailureKind.unavailable]);

  final GeocodeFailureKind kind;
  int calls = 0;

  @override
  Future<List<Place>> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    calls++;
    throw GeocodeFailure(kind);
  }
}

class _Empty implements NearbySearch {
  @override
  Future<List<Place>> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async => const [];
}
