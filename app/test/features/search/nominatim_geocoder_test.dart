import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/fallback_geocoder.dart';
import 'package:fgmap/features/search/data/nominatim_geocoder.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';

import '../../helpers/fakes.dart';

// Badan SINTETIK dalam bentuk jsonv2 Nominatim (container pembangunan tidak boleh mencapainya).
const _sample = [
  {
    'place_id': 1,
    'osm_type': 'way',
    'osm_id': 123456,
    'lat': '3.2262',
    'lon': '101.4278',
    'category': 'shop',
    'type': 'supermarket',
    'name': "Lotus's Puncak Alam",
    'display_name':
        "Lotus's Puncak Alam, Persiaran Puncak Alam, Puncak Alam, Selangor, Malaysia",
    'address': {
      'road': 'Persiaran Puncak Alam',
      'suburb': 'Puncak Alam',
      'state': 'Selangor',
      'postcode': '42300',
      'country': 'Malaysia',
      'country_code': 'my',
    },
    'boundingbox': ['3.2252', '3.2272', '101.4268', '101.4288'],
  },
  {
    'place_id': 2,
    'osm_type': 'node',
    'osm_id': 99,
    'lat': '3.2268',
    'lon': '101.4270',
    'category': 'highway',
    'type': 'bus_stop',
    'name': '',
    'display_name':
        'Lotus Puncak Alam, Persiaran Puncak Alam, Selangor, Malaysia',
  },
  {'place_id': 3, 'lat': 'x', 'lon': '101.4'},
];

void main() {
  group('parseNominatimResponse', () {
    test('memetakan medan OSM, alamat dan kotak sempadan', () {
      final places = parseNominatimResponse(jsonEncode(_sample));
      expect(places, hasLength(2));

      final store = places.first;
      expect(store.name, "Lotus's Puncak Alam");
      expect(store.osmKey, 'shop');
      expect(store.category, 'supermarket');
      expect(store.osmType, 'W');
      expect(store.osmId, 123456);
      expect(store.countryCode, 'MY');
      expect(store.isArea, isTrue);
      expect(store.extentDiagonalM, inInclusiveRange(250, 350));
      expect(store.subtitle, startsWith('Persiaran Puncak Alam, Puncak Alam'));
      expect(store.point, const GeoPoint(3.2262, 101.4278));
    });

    test('nama kosong jatuh ke bahagian pertama display_name', () {
      final stop = parseNominatimResponse(jsonEncode(_sample))[1];
      expect(stop.name, 'Lotus Puncak Alam');
      expect(stop.osmType, 'N');
      expect(stop.isArea, isFalse);
      expect(stop.subtitle, 'Persiaran Puncak Alam, Selangor, Malaysia');
    });

    test('badan kosong/bukan senarai', () {
      expect(parseNominatimResponse(null), isEmpty);
      expect(parseNominatimResponse('[]'), isEmpty);
      expect(
        () => parseNominatimResponse('{}'),
        throwsA(isA<GeocodeFailure>()),
      );
      expect(
        () => parseNominatimResponse('bukan json'),
        throwsA(isA<GeocodeFailure>()),
      );
    });
  });

  group('NominatimGeocoder permintaan', () {
    test('menghantar viewbox sebagai keutamaan tanpa bounded', () async {
      final adapter = StubAdapter((_) => StubAdapter.json(_sample));
      final geocoder = NominatimGeocoder(
        Dio()..httpClientAdapter = adapter,
        'https://nominatim.example/search',
      );
      final places = await geocoder.search(
        'lotus puncak alam',
        near: const GeoPoint(3.2, 101.4),
      );
      expect(places, isNotEmpty);
      final q = adapter.lastRequest!.uri.queryParameters;
      expect(q['format'], 'jsonv2');
      expect(q['viewbox'], isNotNull);
      expect(q.containsKey('bounded'), isFalse);
    });

    test('pertanyaan pendek tidak menghantar permintaan', () async {
      final adapter = StubAdapter((_) => StubAdapter.json(_sample));
      final geocoder = NominatimGeocoder(
        Dio()..httpClientAdapter = adapter,
        'https://nominatim.example/search',
      );
      expect(await geocoder.search('lo'), isEmpty);
      expect(adapter.lastRequest, isNull);
    });
  });

  group('FallbackGeocoder', () {
    const placeA = Place(name: 'A', subtitle: '', point: GeoPoint(3, 101));
    const placeB = Place(name: 'B', subtitle: '', point: GeoPoint(3.1, 101.1));

    FallbackGeocoder build(
      _Fake primary,
      _Fake secondary, {
      List<Duration>? delays,
      DateTime Function()? clock,
    }) => FallbackGeocoder(
      primary,
      secondary,
      clock: clock,
      delay: (d) async => delays?.add(d),
    );

    test('Photon cukup hasil: fallback tidak dipanggil', () async {
      final many = [
        for (var i = 0; i < 5; i++)
          Place(name: 'P$i', subtitle: '', point: GeoPoint(3, 101 + i * 0.01)),
      ];
      final p = _Fake(results: many);
      final s = _Fake(results: [placeB]);
      expect(await build(p, s).search('petronas'), many);
      expect(s.calls, 0);
    });

    test('Photon sedikit hasil: gabung Nominatim', () async {
      final p = _Fake(results: [placeA]);
      final s = _Fake(results: [placeB]);
      expect(await build(p, s).search('petronas'), [placeA, placeB]);
      expect(s.calls, 1);
    });

    test('Photon kosong: Nominatim dipanggil', () async {
      final p = _Fake(results: const []);
      final s = _Fake(results: [placeB]);
      expect(await build(p, s).search('lotus puncak'), [placeB]);
      expect(s.calls, 1);
    });

    test('Photon gagal: Nominatim dipanggil', () async {
      final p = _Fake(failure: GeocodeFailureKind.unavailable);
      final s = _Fake(results: [placeB]);
      expect(await build(p, s).search('lotus puncak'), [placeB]);
    });

    test('kedua-duanya gagal: kegagalan Photon dilaporkan', () async {
      final p = _Fake(failure: GeocodeFailureKind.rateLimited);
      final s = _Fake(failure: GeocodeFailureKind.network);
      await expectLater(
        build(p, s).search('lotus puncak'),
        throwsA(
          isA<GeocodeFailure>().having(
            (f) => f.kind,
            'kind',
            GeocodeFailureKind.rateLimited,
          ),
        ),
      );
    });

    test(
      'Photon kosong dan Nominatim gagal: jawapan kosong, bukan ralat',
      () async {
        final p = _Fake(results: const []);
        final s = _Fake(failure: GeocodeFailureKind.unavailable);
        expect(await build(p, s).search('lotus puncak'), isEmpty);
      },
    );

    test('pertanyaan 2 aksara tidak layak fallback', () async {
      final p = _Fake(results: const []);
      final s = _Fake(results: [placeB]);
      expect(await build(p, s).search('lo'), isEmpty);
      expect(s.calls, 0);
    });

    test('menunggu settle dan menjarakkan permintaan 1.1 s', () async {
      var now = DateTime(2026, 1, 1, 12);
      final delays = <Duration>[];
      final p = _Fake(results: const []);
      final s = _Fake(results: [placeB]);
      final g = FallbackGeocoder(
        p,
        s,
        clock: () => now,
        delay: (d) async {
          delays.add(d);
          now = now.add(d);
        },
      );
      await g.search('lotus puncak');
      expect(delays, [const Duration(milliseconds: 700)]);
      delays.clear();

      // Permintaan kedua 0.3 s kemudian: perlu tunggu baki 0.8 s selepas settle.
      now = now.add(const Duration(milliseconds: 300));
      await g.search('lotus puncak alam');
      expect(delays.first, const Duration(milliseconds: 700));
      expect(
        delays.last,
        const Duration(milliseconds: 1100) - const Duration(milliseconds: 1000),
      );
      expect(s.calls, 2);
    });

    test('dibatalkan semasa menunggu: tiada permintaan Nominatim', () async {
      final cancel = CancelToken();
      final p = _Fake(results: const []);
      final s = _Fake(results: [placeB]);
      final g = FallbackGeocoder(
        p,
        s,
        delay: (_) async => cancel.cancel('baharu'),
      );
      await expectLater(
        g.search('lotus puncak', cancel: cancel),
        throwsA(isA<DioException>()),
      );
      expect(s.calls, 0);
    });
  });
}

class _Fake implements Geocoder {
  _Fake({this.results = const [], this.failure});

  final List<Place> results;
  final GeocodeFailureKind? failure;
  int calls = 0;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    calls++;
    if (failure != null) throw GeocodeFailure(failure!);
    return results;
  }
}
