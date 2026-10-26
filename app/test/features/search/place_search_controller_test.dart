import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/place_search_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGeocoder implements Geocoder {
  final List<String> queries = [];
  final List<GeoPoint?> nears = [];
  final List<CancelToken?> tokens = [];
  Future<List<Place>> Function(String q)? handler;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) {
    queries.add(query);
    nears.add(near);
    tokens.add(cancel);
    return handler!(query);
  }
}

Place _place(String name, [double lat = 3.1]) =>
    Place(name: name, subtitle: 'Kuala Lumpur', point: GeoPoint(lat, 101.7));

const _debounce = Duration(milliseconds: 20);

void main() {
  late _FakeGeocoder geocoder;
  late ProviderContainer container;

  setUp(() {
    geocoder = _FakeGeocoder()..handler = (q) async => [_place(q)];
    container = ProviderContainer(
      overrides: [
        geocoderProvider.overrideWithValue(geocoder),
        searchDebounceProvider.overrideWithValue(_debounce),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      placeSearchControllerProvider,
      (_, _) {},
    ); // kekalkan autoDispose
  });

  PlaceSearchController ctl() =>
      container.read(placeSearchControllerProvider.notifier);
  PlaceSearchState state() => container.read(placeSearchControllerProvider);
  Future<void> wait([int ms = 80]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('mula idle', () => expect(state().status, SearchStatus.idle));

  test('kurang 2 aksara kekal idle tanpa permintaan', () async {
    ctl().onQueryChanged('k');
    await wait();
    expect(state().status, SearchStatus.idle);
    expect(geocoder.queries, isEmpty);
  });

  test('loading serta-merta, kemudian hasil selepas debounce', () async {
    ctl().onQueryChanged('klia');
    expect(state().status, SearchStatus.loading);
    expect(
      geocoder.queries,
      isEmpty,
      reason: 'belum dihantar sebelum debounce tamat',
    );

    await wait();
    expect(state().status, SearchStatus.results);
    expect(state().results.single.name, 'klia');
    expect(geocoder.queries, ['klia']);
  });

  test('menaip pantas: hanya carian terakhir dihantar (debounce)', () async {
    for (final t in ['kl', 'kli', 'klia']) {
      ctl().onQueryChanged(t);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await wait();
    expect(geocoder.queries, ['klia']);
  });

  test(
    'perlumbaan: jawapan lewat untuk teks lama tidak menimpa teks baharu',
    () async {
      final slow = Completer<List<Place>>();
      geocoder.handler = (q) =>
          q == 'lama' ? slow.future : Future.value([_place('baharu')]);

      ctl().onQueryChanged('lama');
      await wait(); // "lama" sudah dihantar dan menunggu
      ctl().onQueryChanged('baharu');
      await wait();
      expect(state().results.single.name, 'baharu');

      slow.complete([_place('lama')]);
      await wait();
      expect(state().results.single.name, 'baharu');
      expect(state().query, 'baharu');
    },
  );

  test('permintaan lapuk dibatalkan', () async {
    geocoder.handler = (q) =>
        Completer<List<Place>>().future; // tidak pernah selesai
    ctl().onQueryChanged('lama');
    await wait();
    ctl().onQueryChanged('baharu');
    expect(geocoder.tokens.first!.isCancelled, isTrue);
  });

  test('tiada hasil -> empty dengan teks carian', () async {
    geocoder.handler = (_) async => [];
    ctl().onQueryChanged('zzzz');
    await wait();
    expect(state().status, SearchStatus.empty);
    expect(state().query, 'zzzz');
  });

  group('kegagalan', () {
    for (final kind in GeocodeFailureKind.values) {
      test('$kind dilaporkan', () async {
        geocoder.handler = (_) async => throw GeocodeFailure(kind);
        ctl().onQueryChanged('klia');
        await wait();
        expect(state().status, SearchStatus.failed);
        expect(state().failure, kind);
      });
    }

    test(
      'retry berjaya selepas kegagalan, dan tidak menggunakan cache kegagalan',
      () async {
        var attempts = 0;
        geocoder.handler = (q) async {
          if (++attempts == 1) {
            throw const GeocodeFailure(GeocodeFailureKind.network);
          }
          return [_place('klia')];
        };
        ctl().onQueryChanged('klia');
        await wait();
        expect(state().status, SearchStatus.failed);

        ctl().retry();
        await wait();
        expect(state().status, SearchStatus.results);
        expect(attempts, 2);
      },
    );

    test('DioException pembatalan bukan kegagalan', () async {
      geocoder.handler = (_) async => throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.cancel,
      );
      ctl().onQueryChanged('klia');
      await wait();
      expect(
        state().status,
        SearchStatus.loading,
        reason: 'tiada keadaan ralat untuk pembatalan',
      );
    });
  });

  group('cache', () {
    test(
      'teks sama (huruf berbeza) tidak diulang; jawapan serta-merta',
      () async {
        ctl().onQueryChanged('klia');
        await wait();
        ctl().onQueryChanged('KLIA');
        expect(
          state().status,
          SearchStatus.results,
          reason: 'daripada cache, tanpa loading',
        );
        await wait();
        expect(geocoder.queries, ['klia']);
      },
    );

    test('kawasan berbeza (>1 km) tidak berkongsi cache', () async {
      ctl().onQueryChanged('klia', near: const GeoPoint(3.10, 101.60));
      await wait();
      ctl().onQueryChanged('klia', near: const GeoPoint(5.40, 100.30));
      await wait();
      expect(geocoder.queries, ['klia', 'klia']);
    });

    test('pergerakan kecil kekal dalam cache', () async {
      ctl().onQueryChanged('klia', near: const GeoPoint(3.1401, 101.6901));
      await wait();
      ctl().onQueryChanged('klia', near: const GeoPoint(3.1403, 101.6902));
      expect(geocoder.queries, ['klia']);
    });

    test('kegagalan tidak dicache', () async {
      var n = 0;
      geocoder.handler = (_) async => ++n == 1
          ? throw const GeocodeFailure(GeocodeFailureKind.network)
          : [_place('x')];
      ctl().onQueryChanged('klia');
      await wait();
      ctl().onQueryChanged('klia');
      await wait();
      expect(state().status, SearchStatus.results);
    });
  });

  test(
    'clear membatalkan carian yang sedang berjalan dan kembali idle',
    () async {
      final pending = Completer<List<Place>>();
      geocoder.handler = (_) => pending.future;
      ctl().onQueryChanged('klia');
      await wait();
      ctl().clear();
      pending.complete([_place('klia')]);
      await wait();
      expect(state().status, SearchStatus.idle);
    },
  );

  test('near diteruskan kepada geocoder', () async {
    ctl().onQueryChanged('klia', near: const GeoPoint(3.1, 101.7));
    await wait();
    expect(geocoder.nears.single, const GeoPoint(3.1, 101.7));
  });
}
