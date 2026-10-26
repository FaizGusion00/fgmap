import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

Future<GeocodeFailure> _failureOf(Future<Object?> Function() action) async {
  try {
    await action();
  } on GeocodeFailure catch (f) {
    return f;
  }
  fail('dijangka GeocodeFailure');
}

Map<String, Object?> _feature({
  Object? coords = const [101.7, 3.1],
  Map<String, Object?> props = const {'name': 'Tempat'},
}) => {
  'type': 'Feature',
  'geometry': {'type': 'Point', 'coordinates': coords},
  'properties': props,
};

String _collection(List<Object?> features) =>
    jsonEncode({'type': 'FeatureCollection', 'features': features});

void main() {
  group('parsePhotonResponse (respons sebenar)', () {
    test(
      'Petronas: nama, alamat, koordinat (lng,lat dibalikkan) dan jenis',
      () {
        final places = parsePhotonResponse(_fixture('photon_petronas.json'));
        expect(places, isNotEmpty);
        final first = places.first;
        expect(first.name, 'Petronas');
        expect(first.subtitle, contains('Kuala Lumpur'));
        // GeoJSON ialah [lng, lat]; Malaysia: lat ~1-7, lng ~99-119.
        expect(first.point.lat, inInclusiveRange(0.8, 7.4));
        expect(first.point.lng, inInclusiveRange(99.6, 119.3));
        expect(first.category, 'fuel');
      },
    );

    test('KLIA ditemui', () {
      final places = parsePhotonResponse(_fixture('photon_klia.json'));
      expect(places.first.name, 'KLIA');
    });

    test('tiada hasil -> senarai kosong (bukan ralat)', () {
      expect(parsePhotonResponse(_fixture('photon_empty.json')), isEmpty);
      expect(parsePhotonResponse(_fixture('photon_outside.json')), isEmpty);
    });

    test('tiada hasil berganda', () {
      final places = parsePhotonResponse(_fixture('photon_petronas.json'));
      expect(places.toSet().length, places.length);
    });
  });

  group('parsePhotonResponse (kes tepi)', () {
    test('nama jalan jika tiada nama; nombor rumah disertakan', () {
      final places = parsePhotonResponse(
        _collection([
          _feature(
            props: {
              'street': 'Jalan Ampang',
              'housenumber': '12',
              'city': 'Kuala Lumpur',
            },
          ),
        ]),
      );
      expect(places.single.name, '12 Jalan Ampang');
      expect(places.single.subtitle, 'Kuala Lumpur');
    });

    test(
      'jalan dipaparkan dalam subtajuk hanya jika bernama tempat; tiada pengulangan',
      () {
        final places = parsePhotonResponse(
          _collection([
            _feature(
              props: {
                'name': 'KLCC',
                'street': 'Jalan Ampang',
                'city': 'Kuala Lumpur',
                'state': 'Kuala Lumpur',
              },
            ),
          ]),
        );
        expect(
          places.single.subtitle,
          'Jalan Ampang, Kuala Lumpur',
          reason: 'bandar dan negeri sama tidak diulang',
        );
      },
    );

    test('nama kawasan digunakan apabila tiada nama atau alamat jalan', () {
      final places = parsePhotonResponse(
        _collection([
          _feature(props: {'city': 'Kuala Lumpur'}),
        ]),
      );
      expect(places.single.name, 'Kuala Lumpur');
    });

    test('butiran alamat penuh termasuk suburb, postcode dan negara', () {
      final places = parsePhotonResponse(
        _collection([
          _feature(
            props: {
              'name': 'FG Tower',
              'street': 'Jalan Ampang',
              'housenumber': '12',
              'suburb': 'Kampung Baru',
              'city': 'Kuala Lumpur',
              'postcode': '50450',
              'country': 'Malaysia',
            },
          ),
        ]),
      );

      expect(
        places.single.subtitle,
        '12 Jalan Ampang, Kampung Baru, Kuala Lumpur, 50450, Malaysia',
      );
    });

    test('locality boleh menjadi nama hasil', () {
      final places = parsePhotonResponse(
        _collection([
          _feature(props: {'locality': 'Alam Perdana', 'state': 'Selangor'}),
        ]),
      );

      expect(places.single.name, 'Alam Perdana');
      expect(places.single.subtitle, 'Selangor');
    });

    final bad = <String, Object?>{
      'koordinat hilang': null,
      'koordinat terlalu pendek': [101.7],
      'koordinat bukan nombor': ['a', 'b'],
      'latitud di luar julat': [101.7, 95.0],
      'longitud di luar julat': [190.0, 3.1],
    };
    bad.forEach((name, coords) {
      test('$name -> hasil dibuang, hasil lain kekal', () {
        final places = parsePhotonResponse(
          _collection([
            _feature(coords: coords),
            _feature(props: {'name': 'Sah'}),
          ]),
        );
        expect(places.map((p) => p.name), ['Sah']);
      });
    });

    test('nilai bukan objek dalam features diabaikan', () {
      expect(
        parsePhotonResponse(_collection([1, 'x', null, _feature()])).length,
        1,
      );
    });

    test('badan kosong -> kosong; bukan JSON -> GeocodeFailure', () {
      expect(parsePhotonResponse(''), isEmpty);
      expect(parsePhotonResponse(null), isEmpty);
      expect(
        () => parsePhotonResponse('<html>'),
        throwsA(isA<GeocodeFailure>()),
      );
      expect(() => parsePhotonResponse('[1]'), throwsA(isA<GeocodeFailure>()));
    });

    test('features bukan senarai -> kosong', () {
      expect(parsePhotonResponse('{"features": 5}'), isEmpty);
    });
  });

  group('PhotonGeocoder', () {
    Dio dioWith(HttpClientAdapter a) => Dio()..httpClientAdapter = a;

    test(
      'menghantar q, carian global, lang dan kecenderungan lokasi; menghurai hasil',
      () async {
        final adapter = StubAdapter(
          (_) => StubAdapter.text(
            _fixture('photon_petronas.json'),
            status: 200,
            contentType: 'application/json',
          ),
        );
        final geocoder = PhotonGeocoder(
          dioWith(adapter),
          'https://photon.test/api/',
        );

        final places = await geocoder.search(
          '  petronas ',
          near: const GeoPoint(3.14, 101.69),
        );

        expect(places.first.name, 'Petronas');
        final uri = adapter.lastRequest!.uri;
        expect(uri.host, 'photon.test');
        expect(uri.queryParameters['q'], 'petronas', reason: 'dipangkas');
        expect(uri.queryParameters.containsKey('bbox'), isFalse);
        expect(uri.queryParameters['lang'], 'en');
        expect(uri.queryParameters['lat'], '3.14');
        expect(uri.queryParameters['lon'], '101.69');
        expect(uri.queryParameters['limit'], '12');
      },
    );

    test('tanpa kecenderungan lokasi tiada lat/lon', () async {
      final adapter = StubAdapter(
        (_) => StubAdapter.text(
          '{"features":[]}',
          status: 200,
          contentType: 'application/json',
        ),
      );
      await PhotonGeocoder(
        dioWith(adapter),
        'https://photon.test/api/',
      ).search('klia');
      expect(
        adapter.lastRequest!.uri.queryParameters.containsKey('lat'),
        isFalse,
      );
    });

    test('kurang 2 aksara -> tiada permintaan', () async {
      final adapter = StubAdapter((_) => StubAdapter.text('{}', status: 200));
      final geocoder = PhotonGeocoder(
        dioWith(adapter),
        'https://photon.test/api/',
      );
      expect(await geocoder.search('k'), isEmpty);
      expect(await geocoder.search('  '), isEmpty);
      expect(adapter.lastRequest, isNull);
    });

    final statusCases = {
      429: GeocodeFailureKind.rateLimited,
      500: GeocodeFailureKind.unavailable,
      503: GeocodeFailureKind.unavailable,
      400: GeocodeFailureKind.generic,
      404: GeocodeFailureKind.generic,
    };
    statusCases.forEach((status, kind) {
      test('HTTP $status -> $kind', () async {
        final adapter = StubAdapter(
          (_) => StubAdapter.text('err', status: status),
        );
        final failure = await _failureOf(
          () => PhotonGeocoder(
            dioWith(adapter),
            'https://photon.test/api/',
          ).search('klia'),
        );
        expect(failure.kind, kind);
      });
    });

    test('ralat sambungan -> network', () async {
      final failure = await _failureOf(
        () => PhotonGeocoder(
          dioWith(FailingAdapter(DioExceptionType.connectionError)),
          'https://photon.test/api/',
        ).search('klia'),
      );
      expect(failure.kind, GeocodeFailureKind.network);
    });
  });
}
