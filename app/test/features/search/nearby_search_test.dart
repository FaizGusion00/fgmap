import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/nearby_cache.dart';
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

/// Pertanyaan Overpass sebenar daripada badan borang POST (`data=<pertanyaan>`).
String _queryOf(StubAdapter adapter) =>
    Uri.decodeQueryComponent(adapter.lastBodyText!.substring('data='.length));

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

    test('radius berperingkat menaik; setiap kategori ada ambang cukup', () {
      for (final c in NearbyCategory.values) {
        expect(c.radiiM, isNotEmpty);
        expect([...c.radiiM]..sort(), c.radiiM, reason: c.name);
        expect(c.radiiM.last, lessThanOrEqualTo(30000));
        expect(c.enoughResults, greaterThan(0));
      }
    });

    test(
      'peringkat pantas tanpa penapis nama mahal, had hasil dan timeout kecil',
      () {
        final fast = NearbyCategory.mosque.overpassQuery(
          3.2,
          101.4,
          1200,
          fast: true,
        );
        expect(fast, isNot(contains('"name"~')));
        expect(fast, contains('[timeout:5]'));
        expect(fast, contains('out tags center 60;'));
        final full = NearbyCategory.mosque.overpassQuery(3.2, 101.4, 3500);
        expect(full, contains('"name"~'));
        expect(full, contains('[timeout:10]'));
      },
    );

    test('surau tanpa tag agama dipadankan melalui nama; hospital dua tag', () {
      final mosque = NearbyCategory.mosque.overpassQuery(3.2, 101.4, 2000);
      expect(
        mosque,
        contains('"name"~"surau|masjid|mosque|musolla|musalla",i'),
      );
      expect(mosque, contains('["amenity"="prayer_room"]'));
      final hospital = NearbyCategory.hospital.overpassQuery(3.2, 101.4, 5000);
      expect(hospital, contains('["healthcare"="hospital"]'));
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

    final many = _overpass([
      _petronas,
      _shellWay,
      for (var i = 0; i < 4; i++)
        {
          'type': 'node',
          'id': 100 + i,
          'lat': 3.2290 + i * 0.0003,
          'lon': 101.4260,
          'tags': {'amenity': 'fuel', 'name': 'Stesen $i'},
        },
    ]);

    test('menghantar data Overpass dengan radius pertama kategori', () async {
      final adapter = StubAdapter((_) => StubAdapter.json(many));
      final search = OverpassNearbySearch(Dio()..httpClientAdapter = adapter, [
        'https://m1.example/api/interpreter',
      ]);
      final result = await search.search(
        NearbyCategory.fuel,
        _center,
        fallbackName: 'Stesen minyak',
      );
      expect(result.places, hasLength(6));
      expect(result.fromCache, isFalse);
      expect(
        adapter.lastRequest!.method,
        'POST',
        reason: 'koordinat bukan dalam URL',
      );
      expect(adapter.lastRequest!.uri.query, isEmpty);
      final data = _queryOf(adapter);
      expect(data, contains('around:1200,3.229,101.426'));
      expect(data, contains('[timeout:5]'), reason: 'peringkat pertama pantas');
    });

    test('hasil belum cukup: radius diperluas berperingkat', () async {
      final requests = <String>[];
      late StubAdapter adapter;
      adapter = StubAdapter((_) {
        requests.add(_queryOf(adapter));
        return StubAdapter.json(_overpass([_petronas]));
      });
      final search = OverpassNearbySearch(Dio()..httpClientAdapter = adapter, [
        'https://m1.example/api/interpreter',
      ]);
      await search.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      expect(requests, hasLength(4));
      expect(requests[0], contains('around:1200'));
      expect(requests[1], contains('around:3500'));
      expect(requests[2], contains('around:10000'));
      expect(requests[3], contains('around:20000'));
      expect(requests[0], contains('[timeout:5]'));
      expect(requests[1], contains('[timeout:10]'));
    });

    test('watch: hasil sementara dihantar dahulu, muktamad terakhir', () async {
      final search = OverpassNearbySearch(
        dioWith((_) => StubAdapter.json(_overpass([_petronas]))),
        ['https://m1.example/api/interpreter'],
      );
      final events = await search
          .watch(NearbyCategory.fuel, _center, fallbackName: 'x')
          .toList();
      expect(events.map((e) => e.refreshing), [true, true, true, false]);
      expect(events.first.places.single.name, 'Petronas');
    });

    test(
      'watch: cukup di peringkat pertama = satu peristiwa muktamad',
      () async {
        final search = OverpassNearbySearch(
          dioWith((_) => StubAdapter.json(many)),
          ['https://m1.example/api/interpreter'],
        );
        final events = await search
            .watch(NearbyCategory.fuel, _center, fallbackName: 'x')
            .toList();
        expect(events, hasLength(1));
        expect(events.single.refreshing, isFalse);
      },
    );

    test(
      'watch: peringkat lebih luas gagal -> ditutup sebagai muktamad',
      () async {
        var n = 0;
        final search = OverpassNearbySearch(
          dioWith((_) {
            n++;
            return n == 1
                ? StubAdapter.json(_overpass([_petronas]))
                : StubAdapter.text('busy', status: 503);
          }),
          ['https://m1.example/api/interpreter'],
        );
        final events = await search
            .watch(NearbyCategory.fuel, _center, fallbackName: 'x')
            .toList();
        expect(events.map((e) => e.refreshing), [true, false]);
        expect(events.last.places.single.name, 'Petronas');
      },
    );

    test('hedge: cermin lambat tidak ditunggu; cermin kedua menang', () async {
      final hosts = <String>[];
      final adapter = _DelayedAdapter((o) {
        hosts.add(o.uri.host);
        return o.uri.host == 'm1.example'
            ? (const Duration(milliseconds: 600), StubAdapter.json(many))
            : (Duration.zero, StubAdapter.json(many));
      });
      final search = OverpassNearbySearch(Dio()..httpClientAdapter = adapter, [
        'https://m1.example/api/interpreter',
        'https://m2.example/api/interpreter',
      ], hedgeAfter: const Duration(milliseconds: 40));
      final watch = Stopwatch()..start();
      final result = await search.search(
        NearbyCategory.fuel,
        _center,
        fallbackName: 'x',
      );
      expect(result.places, hasLength(6));
      expect(hosts, ['m1.example', 'm2.example']);
      expect(watch.elapsedMilliseconds, lessThan(400));
      // Cermin pemenang diingati.
      hosts.clear();
      await search.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      expect(hosts.first, 'm2.example');
    });

    test('pembatalan oleh pemanggil menghentikan carian', () async {
      final adapter = _DelayedAdapter(
        (_) => (const Duration(seconds: 5), StubAdapter.json(many)),
      );
      final search = OverpassNearbySearch(Dio()..httpClientAdapter = adapter, [
        'https://m1.example/api/interpreter',
      ]);
      final cancel = CancelToken();
      final future = search.search(
        NearbyCategory.fuel,
        _center,
        fallbackName: 'x',
        cancel: cancel,
      );
      final expectation = expectLater(
        future,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cancel.cancel('baharu');
      await expectation;
    });

    test('respons besar dihuraikan dalam isolate dengan hasil sama', () async {
      final big = _overpass([
        for (var i = 0; i < 600; i++)
          {
            'type': 'node',
            'id': 1000 + i,
            'lat': 3.2290 + (i % 50) * 0.0004,
            'lon': 101.4260 + (i ~/ 50) * 0.0004,
            'tags': {
              'amenity': 'fuel',
              'name': 'Stesen $i',
              'addr:street':
                  'Jalan nombor $i yang agak panjang untuk besarkan badan',
            },
          },
      ]);
      expect(jsonEncode(big).length, greaterThan(20000));
      final body = jsonEncode(big);
      final direct = parseOverpassResponse(
        body,
        center: _center,
        fallbackName: 'x',
      );
      final viaSearch = await OverpassNearbySearch(
        dioWith((_) => StubAdapter.json(big)),
        ['https://m1.example/api/interpreter'],
      ).search(NearbyCategory.fuel, _center, fallbackName: 'x');
      expect(viaSearch.places.map((p) => p.name), direct.map((p) => p.name));
    });

    test('cukup hasil: satu permintaan sahaja', () async {
      final requests = <String>[];
      final search = OverpassNearbySearch(
        dioWith((o) {
          requests.add(o.uri.toString());
          return StubAdapter.json(many);
        }),
        ['https://m1.example/api/interpreter'],
      );
      await search.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      expect(requests, hasLength(1));
    });

    test(
      'peringkat lebih luas gagal: kekalkan hasil peringkat pertama',
      () async {
        var n = 0;
        final search = OverpassNearbySearch(
          dioWith((_) {
            n++;
            return n == 1
                ? StubAdapter.json(_overpass([_petronas]))
                : StubAdapter.text('busy', status: 503);
          }),
          ['https://m1.example/api/interpreter'],
        );
        final result = await search.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(result.places.single.name, 'Petronas');
      },
    );

    test(
      'cermin pertama gagal -> cermin kedua; cermin baik diingati',
      () async {
        final hosts = <String>[];
        final search = OverpassNearbySearch(
          dioWith((o) {
            hosts.add(o.uri.host);
            return o.uri.host == 'm1.example'
                ? StubAdapter.text('busy', status: 504)
                : StubAdapter.json(many);
          }),
          [
            'https://m1.example/api/interpreter',
            'https://m2.example/api/interpreter',
          ],
        );
        final first = await search.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(hosts, ['m1.example', 'm2.example']);
        expect(first.places, isNotEmpty);

        hosts.clear();
        await search.search(NearbyCategory.fuel, _center, fallbackName: 'x');
        expect(hosts, [
          'm2.example',
        ], reason: 'cermin yang berjaya dicuba dahulu');
      },
    );

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

    test('tamat masa keseluruhan: cermin seterusnya tidak dicuba', () async {
      final hosts = <String>[];
      final search = OverpassNearbySearch(
        dioWith((o) {
          hosts.add(o.uri.host);
          return StubAdapter.text('x', status: 503);
        }),
        [
          'https://m1.example/api/interpreter',
          'https://m2.example/api/interpreter',
          'https://m3.example/api/interpreter',
        ],
        deadline: Duration.zero,
      );
      await expectLater(
        search.search(NearbyCategory.fuel, _center, fallbackName: 'x'),
        throwsA(isA<GeocodeFailure>()),
      );
      expect(hosts, ['m1.example']);
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
        final result = await search.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(result.places.map((p) => p.name), ['Dekat', 'Jauh']);
        final q = adapter.lastRequest!.uri.queryParameters;
        expect(q['q'], 'petrol station');
        expect(q['bounded'], '1');
      },
    );

    test(
      'Nominatim: hasil bukan jenis kategori (nama jalan) dibuang, jadi "toilets" tidak memulangkan jalan',
      () async {
        Map<String, Object?> item(
          int id,
          String key,
          String type,
          String name,
          String lat,
        ) => {
          'osm_type': 'node',
          'osm_id': id,
          'lat': lat,
          'lon': '101.4262',
          'category': key,
          'type': type,
          'name': name,
          'display_name': '$name, Selangor',
        };
        final adapter = StubAdapter(
          (_) => StubAdapter.json([
            item(1, 'highway', 'residential', 'Jalan Tandas 1', '3.2291'),
            item(2, 'amenity', 'toilets', 'Tandas Awam', '3.2295'),
            item(3, 'amenity', 'parking', 'Parkir', '3.2292'),
          ]),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final result = await NominatimNearbySearch(
          dio,
          'https://nominatim.example/search',
        ).search(NearbyCategory.toilets, _center, fallbackName: 'Tandas');
        expect(result.places.map((p) => p.name), ['Tandas Awam']);
      },
    );

    test(
      'Nominatim masjid: frasa Inggeris "mosque" dan "surau" (tidak bergantung bahasa app), hasil digabung',
      () async {
        final phrases = <String>[];
        final adapter = StubAdapter((o) {
          final q = o.uri.queryParameters['q']!;
          phrases.add(q);
          return StubAdapter.json([
            {
              'osm_type': 'node',
              'osm_id': q == 'surau' ? 11 : 10,
              'lat': q == 'surau' ? '3.2300' : '3.2310',
              'lon': '101.4262',
              'category': 'amenity',
              'type': 'place_of_worship',
              'name': q == 'surau' ? 'Surau An-Nur' : 'Masjid Besar',
              'display_name': 'x, Selangor',
            },
          ]);
        });
        final dio = Dio()..httpClientAdapter = adapter;
        final result = await NominatimNearbySearch(
          dio,
          'https://nominatim.example/search',
        ).search(NearbyCategory.mosque, _center, fallbackName: 'Masjid');
        expect(phrases, ['mosque', 'surau']);
        expect(result.places.map((p) => p.name), [
          'Surau An-Nur',
          'Masjid Besar',
        ]);
      },
    );

    test('kategori sama untuk semua bahasa: frasa dan jenis tetap', () {
      for (final c in NearbyCategory.values) {
        expect(c.nominatimPhrases, isNotEmpty);
        expect(c.nominatimTypes, isNotEmpty);
        for (final phrase in c.nominatimPhrases) {
          expect(phrase, matches(RegExp(r'^[a-z ]+$')));
        }
      }
    });

    test('Overpass kosong: kekal kosong, Nominatim tidak dipanggil', () async {
      final secondary = _AlwaysFails();
      final search = FallbackNearbySearch(_Empty(), secondary);
      final result = await search.search(
        NearbyCategory.fuel,
        _center,
        fallbackName: 'x',
      );
      expect(result.places, isEmpty);
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

  group('FallbackNearbySearch.watch', () {
    test(
      'hasil sementara sudah dipaparkan lalu primer gagal: tidak jatuh ke Nominatim',
      () async {
        final secondary = _AlwaysFails();
        final primary = _StreamScripted([
          [
            [_one('A')],
            const GeocodeFailure(GeocodeFailureKind.unavailable),
          ],
        ]);
        final search = FallbackNearbySearch(primary, secondary);
        final events = await search
            .watch(NearbyCategory.fuel, _center, fallbackName: 'x')
            .toList();
        expect(events, hasLength(1));
        expect(events.single.places.single.name, 'A');
        expect(secondary.calls, 0);
      },
    );
  });

  group('CachedNearbySearch', () {
    late SharedPreferences prefs;
    var now = DateTime(2026, 10, 26, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 10, 26, 10);
    });

    CachedNearbySearch build(NearbySearch inner) =>
        CachedNearbySearch(inner, prefs, clock: () => now);

    const live = NearbyResult([
      Place(
        name: 'Petronas',
        subtitle: 'Puncak Alam',
        point: GeoPoint(3.2300, 101.4270),
        category: 'fuel',
        osmKey: 'amenity',
        osmType: 'N',
        osmId: 1,
      ),
    ]);

    test(
      'berjaya: disimpan; dalam 30 minit dipulangkan tanpa rangkaian',
      () async {
        final inner = _Scripted([live]);
        final cache = build(inner);
        final first = await cache.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(first.fromCache, isFalse);
        expect(inner.calls, 1);

        now = now.add(const Duration(minutes: 10));
        final second = await cache.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(inner.calls, 1);
        expect(
          second.fromCache,
          isFalse,
          reason: 'masih segar, bukan "simpanan lama"',
        );
        expect(second.places.single.name, 'Petronas');
        expect(second.places.single.osmId, 1);
      },
    );

    test(
      'pelayan gagal selepas tempoh segar: simpanan lama ditandakan',
      () async {
        final inner = _Scripted([
          live,
          const GeocodeFailure(GeocodeFailureKind.unavailable),
        ]);
        final cache = build(inner);
        await cache.search(NearbyCategory.fuel, _center, fallbackName: 'x');

        final savedAt = now;
        now = now.add(const Duration(hours: 5));
        final result = await cache.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(result.fromCache, isTrue);
        expect(result.cachedAt, savedAt);
        expect(result.places.single.name, 'Petronas');
      },
    );

    test('simpanan terlalu lama (>30 hari) tidak digunakan', () async {
      final inner = _Scripted([
        live,
        const GeocodeFailure(GeocodeFailureKind.network),
      ]);
      final cache = build(inner);
      await cache.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      now = now.add(const Duration(days: 31));
      await expectLater(
        cache.search(NearbyCategory.fuel, _center, fallbackName: 'x'),
        throwsA(isA<GeocodeFailure>()),
      );
    });

    test('kategori atau kawasan lain tidak berkongsi simpanan', () async {
      final inner = _Scripted([
        live,
        const GeocodeFailure(GeocodeFailureKind.network),
      ]);
      final cache = build(inner);
      await cache.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      now = now.add(const Duration(hours: 5));
      await expectLater(
        cache.search(NearbyCategory.food, _center, fallbackName: 'x'),
        throwsA(isA<GeocodeFailure>()),
      );
    });

    test('hasil kosong tidak menimpa simpanan yang baik', () async {
      final inner = _Scripted([
        live,
        const NearbyResult([]),
        const GeocodeFailure(GeocodeFailureKind.network),
      ]);
      final cache = build(inner);
      await cache.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      now = now.add(const Duration(hours: 2));
      await cache.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      now = now.add(const Duration(hours: 2));
      final result = await cache.search(
        NearbyCategory.fuel,
        _center,
        fallbackName: 'x',
      );
      expect(result.fromCache, isTrue);
      expect(result.places, isNotEmpty);
    });

    test(
      'lama tetapi ada: simpanan serta-merta (refreshing), kemudian segar',
      () async {
        final inner = _StreamScripted([
          [live],
          [
            [_one('Sementara')],
            [_one('Segar A'), _one('Segar B')],
          ],
        ]);
        final cache = build(inner);
        await cache.search(NearbyCategory.fuel, _center, fallbackName: 'x');

        now = now.add(const Duration(hours: 5));
        final events = await cache
            .watch(NearbyCategory.fuel, _center, fallbackName: 'x')
            .toList();
        // Simpanan dahulu; hasil sementara pelayan diabaikan kerana simpanan sudah di skrin.
        expect(events.map((e) => e.refreshing), [true, false]);
        expect(events.first.places.single.name, 'Petronas');
        expect(events.last.places.map((p) => p.name), ['Segar A', 'Segar B']);
        expect(events.last.fromCache, isFalse);
      },
    );

    test('segar (<30 min): satu peristiwa, tiada rangkaian', () async {
      final inner = _StreamScripted([
        [live],
      ]);
      final cache = build(inner);
      await cache.search(NearbyCategory.fuel, _center, fallbackName: 'x');
      now = now.add(const Duration(minutes: 5));
      final events = await cache
          .watch(NearbyCategory.fuel, _center, fallbackName: 'x')
          .toList();
      expect(events, hasLength(1));
      expect(events.single.refreshing, isFalse);
      expect(inner.calls, 1);
    });

    test(
      'tiada simpanan: hasil sementara pelayan diteruskan, hanya muktamad disimpan',
      () async {
        final inner = _StreamScripted([
          [
            [_one('Sementara')],
            [_one('Sementara'), _one('Lengkap')],
          ],
        ]);
        final cache = build(inner);
        final events = await cache
            .watch(NearbyCategory.fuel, _center, fallbackName: 'x')
            .toList();
        expect(events.map((e) => e.refreshing), [true, false]);
        // Selepas itu, simpanan segar mengandungi hasil muktamad.
        final again = await cache.search(
          NearbyCategory.fuel,
          _center,
          fallbackName: 'x',
        );
        expect(again.places, hasLength(2));
        expect(inner.calls, 1);
      },
    );

    test('data simpanan rosak diabaikan', () async {
      await prefs.setString('nearby.v1.fuel.323.10143', '{bukan json');
      final inner = _Scripted([live]);
      final result = await build(
        inner,
      ).search(NearbyCategory.fuel, _center, fallbackName: 'x');
      expect(result.places, isNotEmpty);
    });
  });
}

class _Scripted implements NearbySearch {
  _Scripted(this.script);

  final List<Object> script;
  int calls = 0;

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    final next = script[calls < script.length ? calls : script.length - 1];
    calls++;
    if (next is GeocodeFailure) throw next;
    return next as NearbyResult;
  }
}

class _AlwaysFails implements NearbySearch {
  _AlwaysFails([this.kind = GeocodeFailureKind.unavailable]);

  final GeocodeFailureKind kind;
  int calls = 0;

  @override
  Future<NearbyResult> search(
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
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async => const NearbyResult([]);
}

Place _one(String name) => Place(
  name: name,
  subtitle: '',
  point: const GeoPoint(3.2300, 101.4270),
  category: 'fuel',
  osmKey: 'amenity',
  osmType: 'N',
);

/// Skrip: setiap panggilan `watch` ialah satu senarai; unsur `List<Place>` = hasil sementara
/// (`refreshing` kecuali yang terakhir), `NearbyResult` = hantar apa adanya, `GeocodeFailure` = ralat.
class _StreamScripted implements ProgressiveNearbySearch {
  _StreamScripted(this.script);

  final List<List<Object>> script;
  int calls = 0;

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) => watch(category, center, fallbackName: fallbackName).last;

  @override
  Stream<NearbyResult> watch(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async* {
    final steps = script[calls < script.length ? calls : script.length - 1];
    calls++;
    for (final (i, step) in steps.indexed) {
      if (step is GeocodeFailure) throw step;
      if (step is NearbyResult) {
        yield step;
      } else {
        yield NearbyResult(
          (step as List).cast<Place>(),
          refreshing: i < steps.length - 1,
        );
      }
    }
  }
}

/// Adapter dengan kelewatan setiap permintaan; menghormati pembatalan seperti adapter sebenar.
class _DelayedAdapter implements HttpClientAdapter {
  _DelayedAdapter(this.plan);

  final (Duration, ResponseBody) Function(RequestOptions options) plan;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (delay, body) = plan(options);
    final cancelled = Completer<void>();
    unawaited(cancelFuture?.then((_) => cancelled.complete()));
    await Future.any([Future<void>.delayed(delay), cancelled.future]);
    if (cancelled.isCompleted) {
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'dibatalkan',
      );
    }
    return body;
  }

  @override
  void close({bool force = false}) {}
}
