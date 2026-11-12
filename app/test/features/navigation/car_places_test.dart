import 'package:dio/dio.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/presentation/car_places.dart';
import 'package:fgmap/features/saved_places/data/saved_places_controller.dart';
import 'package:fgmap/features/search/data/nearby_search.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

/// Skrin kereta (Android Auto dan CarPlay) memahami ayat biasa dan menawarkan "Berdekatan", melalui
/// penghala arahan yang sama dengan FG AI.
void main() {
  const here = GeoPoint(3.1390, 101.6869);
  const caltex = Place(
    name: 'Caltex',
    subtitle: 'Sungai Buloh, Selangor',
    point: GeoPoint(3.1390 + 0.00423, 101.6869),
  );
  const shell = Place(
    name: 'Shell',
    subtitle: 'Jalan Eco Grandeur 1/9, Selangor',
    point: GeoPoint(3.1390 + 0.0234, 101.6869),
  );

  late _Nearby nearby;
  late _Geocoder geocoder;
  late ProviderContainer container;
  GeoPoint? live;

  Future<CarPlaces> setUp0({
    bool gps = true,
    Locale locale = const Locale('ms'),
    Object? nearbyError,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = locale;
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    nearby = _Nearby([caltex, shell], error: nearbyError);
    geocoder = _Geocoder([caltex]);
    live = null;
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            accessValue: LocationAccess.granted,
            fix: gps ? const LocationFix(point: here) : null,
          ),
        ),
        nearbySearchProvider.overrideWithValue(nearby),
        geocoderProvider.overrideWithValue(geocoder),
      ],
    );
    addTearDown(container.dispose);
    return container.read(Provider((ref) => CarPlaces(ref, live: () => live)));
  }

  group('Berdekatan', () {
    test(
      'setiap kategori boleh dicapai dari skrin kereta, tanpa pendua',
      () async {
        final places = await setUp0();
        final rows = places.categories();
        final ids = [for (final r in rows) r['id']];
        expect(ids.toSet(), hasLength(ids.length));
        expect(ids.toSet(), {
          for (final c in NearbyCategory.values) c.name,
        }, reason: 'kategori baharu tidak boleh tertinggal daripada kereta');
      },
    );

    test(
      'enam yang pertama ialah keperluan pemandu (had hos ketika memandu)',
      () async {
        final places = await setUp0();
        final first = places.categories().take(6).map((r) => r['id']).toList();
        expect(first, ['fuel', 'food', 'mosque', 'toilets', 'atm', 'pharmacy']);
      },
    );

    test('nama kategori mengikut bahasa peranti', () async {
      final ms = await setUp0();
      expect(ms.categories().first['label'], 'Stesen minyak');
      expect(
        ms.categories().firstWhere((r) => r['id'] == 'barber')['label'],
        'Kedai gunting',
      );
      final en = await setUp0(locale: const Locale('en'));
      expect(en.categories().first['label'], 'Fuel');
      // Bahasa lain jatuh ke Inggeris, bukan ranap.
      final fr = await setUp0(locale: const Locale('fr'));
      expect(fr.categories().first['label'], 'Fuel');
    });

    test(
      'tempat terdekat: jarak dan kawasan sudah digabung dalam subtitle',
      () async {
        final places = await setUp0();
        final rows = await places.nearby('fuel');
        expect(nearby.categories, [NearbyCategory.fuel]);
        expect(rows, hasLength(2));
        expect(rows.first['name'], 'Caltex');
        expect(rows.first['subtitle'], '470 m · Sungai Buloh');
        expect(rows.last['subtitle'], '2.6 km · Jalan Eco Grandeur 1/9');
        expect(rows.first['lat'], caltex.point.lat);
        expect(rows.first['lng'], caltex.point.lng);
      },
    );

    test('id tidak dikenali: senarai kosong', () async {
      expect(await (await setUp0()).nearby('bukan-kategori'), isEmpty);
    });

    // Dahulu kedua-duanya senarai kosong, dan skrin kereta berkata "semak internet" walaupun
    // masalahnya GPS (atau sebaliknya).
    test('ralat carian dan tiada GPS dibezakan untuk skrin kereta', () async {
      await expectLater(
        (await setUp0(nearbyError: StateError('offline'))).nearby('fuel'),
        throwsA(
          isA<CarPlacesFailure>().having(
            (e) => e.code,
            'code',
            CarPlacesFailure.failed,
          ),
        ),
      );
      await expectLater(
        (await setUp0(gps: false)).nearby('fuel'),
        throwsA(
          isA<CarPlacesFailure>().having(
            (e) => e.code,
            'code',
            CarPlacesFailure.noLocation,
          ),
        ),
      );
    });
  });

  group('carian suara dan teks', () {
    test(
      '"kedai gunting terdekat" ialah kategori, bukan nama tempat',
      () async {
        final places = await setUp0();
        final rows = await places.search('kedai gunting terdekat');
        expect(nearby.categories, [NearbyCategory.barber]);
        expect(geocoder.queries, isEmpty);
        expect(rows, isNotEmpty);
      },
    );

    test('ayat sebenar penguji dengan kata sopan', () async {
      final places = await setUp0();
      await places.search(
        'Ok boleh bagi tahu saya dimana kedai gunting terdekat?',
      );
      expect(nearby.categories, [NearbyCategory.barber]);
    });

    test('kategori sahaja ("farmasi") terus difahami', () async {
      final places = await setUp0();
      await places.search('farmasi');
      expect(nearby.categories, [NearbyCategory.pharmacy]);
    });

    test(
      '"bawa saya ke klcc": hanya destinasi dicari, bukan keseluruhan ayat',
      () async {
        final places = await setUp0();
        await places.search('bawa saya ke klcc');
        expect(geocoder.queries, ['klcc']);
        expect(nearby.categories, isEmpty);
      },
    );

    test('nama tempat biasa dicari mengikut nama, dengan jarak', () async {
      final places = await setUp0();
      final rows = await places.search('Caltex Sungai Buloh');
      expect(geocoder.queries, isNotEmpty);
      expect(rows.single['subtitle'], '470 m · Sungai Buloh');
    });

    test('destinasi tanpa hasil: cuba semula dengan teks asal', () async {
      final places = await setUp0();
      geocoder.byQuery = {
        'bawa saya ke kedai pak ali': [shell],
      };
      final rows = await places.search('bawa saya ke kedai pak ali');
      expect(rows.single['name'], 'Shell');
      expect(geocoder.queries.length, greaterThanOrEqualTo(2));
    });

    test(
      '"balik rumah" memberi satu baris Rumah daripada tempat tersimpan',
      () async {
        final places = await setUp0();
        await container
            .read(savedPlacesControllerProvider.notifier)
            .setHome(
              const Place(
                name: 'Taman Melawati',
                subtitle: 'Kuala Lumpur',
                point: GeoPoint(3.2, 101.75),
              ),
            );
        final rows = await places.search('balik rumah');
        expect(rows, hasLength(1));
        expect(rows.single['name'], 'Rumah');
        expect(rows.single['lat'], 3.2);
        expect(geocoder.queries, isEmpty);
      },
    );

    test('Rumah belum ditetapkan: jatuh ke carian nama, tidak ranap', () async {
      final places = await setUp0();
      final rows = await places.search('balik rumah');
      expect(rows, isA<List>());
      expect(geocoder.queries, isNotEmpty);
    });

    test(
      'teks kosong: senarai kosong; ralat geocoder: gagal (bukan "tiada hasil")',
      () async {
        final places = await setUp0();
        expect(await places.search('   '), isEmpty);
        geocoder.error = DioException(
          requestOptions: RequestOptions(path: '/'),
        );
        await expectLater(
          places.search('klcc'),
          throwsA(
            isA<CarPlacesFailure>().having(
              (e) => e.code,
              'code',
              CarPlacesFailure.failed,
            ),
          ),
        );
      },
    );

    test('baris dihadkan supaya hos kereta tidak terlebih muatan', () async {
      final places = await setUp0();
      geocoder.byQuery = {
        'klcc': [for (var i = 0; i < 30; i++) caltex],
      };
      expect(
        (await places.search('klcc')).length,
        lessThanOrEqualTo(CarPlaces.maxRows),
      );
    });
  });

  group('titik asal', () {
    test('mengutamakan kedudukan navigasi, jika tidak GPS peranti', () async {
      final places = await setUp0();
      expect(await places.origin(), here);
      live = const GeoPoint(5.0, 100.0);
      expect(await places.origin(), const GeoPoint(5.0, 100.0));
    });

    test(
      'tiada GPS langsung: null (skrin kereta beritahu, tidak meneka)',
      () async {
        final places = await setUp0(gps: false);
        expect(await places.origin(), isNull);
      },
    );
  });
}

class _Nearby implements NearbySearch {
  _Nearby(this.places, {this.error});

  final List<Place> places;
  final Object? error;
  final List<NearbyCategory> categories = [];

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    cancel,
  }) async {
    categories.add(category);
    final e = error;
    if (e != null) throw e;
    return NearbyResult(places);
  }
}

class _Geocoder implements Geocoder {
  _Geocoder(this.defaultResults);

  final List<Place> defaultResults;
  Map<String, List<Place>>? byQuery;
  Object? error;
  final List<String> queries = [];

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async {
    queries.add(query);
    final e = error;
    if (e != null) throw e;
    final map = byQuery;
    if (map != null) return map[query] ?? const [];
    return defaultResults;
  }
}
