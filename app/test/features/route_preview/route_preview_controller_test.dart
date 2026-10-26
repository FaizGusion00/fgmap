import 'dart:async';
import 'dart:convert';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/data/toll_finder.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

late SharedPreferences _prefs;

ProviderContainer _container(
  FakeRoutePlanner repo,
  FakeLocationService location,
) {
  final container = ProviderContainer(
    overrides: [
      routeOptionsPlannerProvider.overrideWithValue(repo),
      locationServiceProvider.overrideWithValue(location),
      sharedPreferencesProvider.overrideWithValue(_prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

RoutePreviewController _controller(ProviderContainer c) =>
    c.read(routePreviewControllerProvider.notifier);

RoutePreviewState _state(ProviderContainer c) =>
    c.read(routePreviewControllerProvider);

void main() {
  late FakeLocationService location;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    location = FakeLocationService(
      fix: LocationFix(
        point: klcc,
        headingDegrees: 90,
        accuracyMeters: 8,
        timestamp: DateTime.now(),
      ),
    );
  });

  test('bermula Idle', () {
    final c = _container(
      FakeRoutePlanner((_) async => [sampleOption()]),
      location,
    );
    expect(_state(c), isA<RouteIdle>());
  });

  test(
    'berjaya: Loading kemudian Ready, asal daripada lokasi pengguna dengan heading',
    () async {
      final repo = FakeRoutePlanner(
        (_) async => [sampleOption(), sampleOption(durationS: 3700)],
      );
      final c = _container(repo, location);

      final states = <RoutePreviewState>[];
      c.listen(
        routePreviewControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: false,
      );

      await _controller(c).planTo(klia);

      expect(states.first, isA<RouteLoading>());
      final ready = _state(c) as RouteReady;
      expect(ready.options, hasLength(2));
      expect(ready.selectedIndex, 0);
      expect(ready.query.origin, klcc);
      expect(ready.query.headingDegrees, 90);
      expect(ready.query.destination, klia);
      expect(repo.queries, hasLength(1));
    },
  );

  test(
    'tiada fix GPS: tiada laluan dikira dan destinasi boleh dicuba semula',
    () async {
      location.accessValue = LocationAccess.deniedForever;
      final repo = FakeRoutePlanner((_) async => [sampleOption()]);
      final c = _container(repo, location);

      await _controller(c).planTo(klia);

      expect(_state(c), isA<RouteLocationUnavailable>());
      expect(repo.queries, isEmpty);

      location
        ..accessValue = LocationAccess.granted
        ..fix = LocationFix(
          point: klcc,
          accuracyMeters: 8,
          timestamp: DateTime.now(),
        );
      await _controller(c).retry();

      expect(_state(c), isA<RouteReady>());
      expect(repo.queries.single.origin, klcc);
    },
  );

  test('peranti pegun (tiada heading) tetap berjaya', () async {
    location.fix = LocationFix(
      point: klcc,
      accuracyMeters: 8,
      timestamp: DateTime.now(),
    );
    final c = _container(
      FakeRoutePlanner((_) async => [sampleOption()]),
      location,
    );

    await _controller(c).planTo(klia);

    expect((_state(c) as RouteReady).query.headingDegrees, isNull);
  });

  test('gagal: Failed membawa jenis kegagalan dan query asal', () async {
    final repo = FakeRoutePlanner(
      (_) async => throw const RoutingFailure(RoutingFailureKind.noRoute),
    );
    final c = _container(repo, location);

    await _controller(c).planTo(klia);

    final failed = _state(c) as RouteFailed;
    expect(failed.kind, RoutingFailureKind.noRoute);
    expect(failed.query.destination, klia);
  });

  test('retry mengulang query yang sama dan boleh pulih', () async {
    var attempts = 0;
    final repo = FakeRoutePlanner((_) async {
      attempts++;
      if (attempts == 1) {
        throw const RoutingFailure(RoutingFailureKind.unavailable);
      }
      return [sampleOption()];
    });
    final c = _container(repo, location);

    await _controller(c).planTo(klia);
    expect(_state(c), isA<RouteFailed>());

    await _controller(c).retry();
    expect(_state(c), isA<RouteReady>());
    expect(repo.queries, hasLength(2));
    expect(repo.queries[1].destination, repo.queries[0].destination);
    expect(repo.queries[1].origin, repo.queries[0].origin);
  });

  test('retry/setVehicle tanpa laluan aktif tidak berbuat apa-apa', () async {
    final repo = FakeRoutePlanner((_) async => [sampleOption()]);
    final c = _container(repo, location);

    await _controller(c).retry();
    await _controller(c).setVehicle(RouteVehicle.motorcycle);

    expect(_state(c), isA<RouteIdle>());
    expect(repo.queries, isEmpty);
  });

  test(
    'kegagalan tidak dijangka dari perancang tidak meninggalkan Loading',
    () async {
      final repo = FakeRoutePlanner((_) async => throw StateError('rosak'));
      final c = _container(repo, location);

      await _controller(c).planTo(klia);

      final failed = _state(c) as RouteFailed;
      expect(failed.kind, RoutingFailureKind.generic);
    },
  );

  test(
    'selectedQuery membawa pilihan laluan terpilih untuk pengiraan semula',
    () async {
      final repo = FakeRoutePlanner(
        (_) async => [
          sampleOption(),
          sampleOption(
            durationS: 4000,
            hasTolls: false,
            label: RouteLabel.noTolls,
          ),
        ],
      );
      final c = _container(repo, location);
      await _controller(c).planTo(klia, destinationLabel: 'KLIA');

      expect((_state(c) as RouteReady).selectedQuery.avoidTolls, isFalse);
      _controller(c).select(1);
      final query = (_state(c) as RouteReady).selectedQuery;
      expect(query.avoidTolls, isTrue);
      expect(query.destinationLabel, 'KLIA');
    },
  );

  test('radius destinasi diteruskan ke pertanyaan laluan', () async {
    final repo = FakeRoutePlanner(
      (_) async => [
        sampleOption(),
        sampleOption(durationS: 4000, hasTolls: false),
      ],
    );
    final c = _container(repo, location);
    await _controller(c).planTo(klia, radiusM: 42);
    expect(repo.queries.single.destinationRadiusM, 42);
    expect((_state(c) as RouteReady).selectedQuery.destinationRadiusM, 42);
    _controller(c).select(1);
    expect((_state(c) as RouteReady).selectedQuery.destinationRadiusM, 42);
  });

  test('select menukar laluan dan menolak indeks di luar julat', () async {
    final repo = FakeRoutePlanner(
      (_) async => [sampleOption(), sampleOption(durationS: 4000)],
    );
    final c = _container(repo, location);
    await _controller(c).planTo(klia);

    _controller(c).select(1);
    expect((_state(c) as RouteReady).selectedIndex, 1);
    expect((_state(c) as RouteReady).selected.durationS, 4000);

    _controller(c).select(5);
    _controller(c).select(-1);
    expect((_state(c) as RouteReady).selectedIndex, 1);
  });

  test('clear kembali ke Idle', () async {
    final c = _container(
      FakeRoutePlanner((_) async => [sampleOption()]),
      location,
    );
    await _controller(c).planTo(klia);

    _controller(c).clear();

    expect(_state(c), isA<RouteIdle>());
  });

  group('perlumbaan permintaan', () {
    test(
      'keputusan permintaan lama dibuang bila destinasi baharu dipilih',
      () async {
        final first = Completer<List<RouteOption>>();
        final second = Completer<List<RouteOption>>();
        final pending = [first, second];
        final repo = FakeRoutePlanner((_) => pending.removeAt(0).future);
        final c = _container(repo, location);

        final f1 = _controller(c).planTo(klia);
        await pumpEventQueue(); // permintaan pertama sudah sampai ke repositori
        final f2 = _controller(c).planTo(batuCaves);
        await pumpEventQueue();

        second.complete([sampleOption(durationS: 111)]);
        await f2;
        first.complete([
          sampleOption(durationS: 999),
        ]); // lewat: mesti diabaikan
        await f1;

        final ready = _state(c) as RouteReady;
        expect(ready.query.destination, batuCaves);
        expect(ready.selected.durationS, 111);
      },
    );

    test(
      'kegagalan permintaan lama tidak menimpa laluan yang sudah berjaya',
      () async {
        final first = Completer<List<RouteOption>>();
        final second = Completer<List<RouteOption>>();
        final pending = [first, second];
        final repo = FakeRoutePlanner((_) => pending.removeAt(0).future);
        final c = _container(repo, location);

        final f1 = _controller(c).planTo(klia);
        await pumpEventQueue();
        final f2 = _controller(c).planTo(batuCaves);
        await pumpEventQueue();

        second.complete([sampleOption()]);
        await f2;
        first.completeError(const RoutingFailure(RoutingFailureKind.timeout));
        await f1;

        expect(_state(c), isA<RouteReady>());
      },
    );

    test(
      'clear semasa menunggu: keputusan yang tiba kemudian tidak menghidupkan semula laluan',
      () async {
        final pending = Completer<List<RouteOption>>();
        final repo = FakeRoutePlanner((_) => pending.future);
        final c = _container(repo, location);

        final f = _controller(c).planTo(klia);
        await pumpEventQueue();
        expect(_state(c), isA<RouteLoading>());

        _controller(c).clear();
        pending.complete([sampleOption()]);
        await f;

        expect(_state(c), isA<RouteIdle>());
      },
    );

    test(
      'destinasi baharu dipilih semasa lokasi masih dicari: permintaan lama tidak dihantar',
      () async {
        final repo = FakeRoutePlanner((_) async => [sampleOption()]);
        final c = _container(repo, location);

        final f1 = _controller(c).planTo(klia);
        final f2 = _controller(c).planTo(batuCaves);
        await Future.wait([f1, f2]);

        expect(repo.queries.map((q) => q.destination), [batuCaves]);
      },
    );
  });

  group('pilihan laluan', () {
    test(
      'kenderaan: lalai kereta; motosikal dihantar, disimpan dan dipulihkan',
      () async {
        final repo = FakeRoutePlanner((_) async => [sampleOption()]);
        final c = _container(repo, location);
        await _controller(c).planTo(klia);
        expect(repo.queries.last.vehicle, RouteVehicle.car);

        await _controller(c).setVehicle(RouteVehicle.motorcycle);
        expect(repo.queries.last.vehicle, RouteVehicle.motorcycle);
        expect(_prefs.getString('route.vehicle'), 'motorcycle');

        // Sesi baharu: kenderaan dipulihkan, dan laluan baharu menggunakannya.
        final repo2 = FakeRoutePlanner((_) async => [sampleOption()]);
        final c2 = _container(repo2, location);
        await _controller(c2).planTo(klia);
        expect(repo2.queries.single.vehicle, RouteVehicle.motorcycle);
      },
    );

    test(
      'menukar kenderaan tanpa laluan aktif hanya menyimpan pilihan',
      () async {
        final repo = FakeRoutePlanner((_) async => [sampleOption()]);
        final c = _container(repo, location);
        await _controller(c).setVehicle(RouteVehicle.motorcycle);
        expect(repo.queries, isEmpty);
        expect(_state(c), isA<RouteIdle>());
      },
    );

    test(
      'nilai kenderaan tersimpan yang tidak dikenali jatuh balik kepada kereta',
      () async {
        SharedPreferences.setMockInitialValues({'route.vehicle': 'helikopter'});
        _prefs = await SharedPreferences.getInstance();
        final repo = FakeRoutePlanner((_) async => [sampleOption()]);
        final c = _container(repo, location);
        await _controller(c).planTo(klia);
        expect(repo.queries.single.vehicle, RouteVehicle.car);
      },
    );
  });

  group('pilihan laluan berperingkat', () {
    late _ProgressivePlanner planner;
    late ProviderContainer c;

    // Geometri berbeza (bukan const kongsi) supaya padanan laluan terpilih mengikut identiti berfungsi.
    RouteOption route(int n, {int? durationS}) => sampleOption(
      durationS: durationS ?? 3000 + n * 100,
      distanceM: 60000 + n * 1000,
      points: [klcc, GeoPoint(3.0 + n * 0.01, 101.7), klia],
    );

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() {
      planner = _ProgressivePlanner();
      c = ProviderContainer(
        overrides: [
          routeOptionsPlannerProvider.overrideWithValue(planner),
          locationServiceProvider.overrideWithValue(location),
          sharedPreferencesProvider.overrideWithValue(_prefs),
        ],
      );
      addTearDown(c.dispose);
      c.listen(routePreviewControllerProvider, (_, _) {});
    });

    test(
      'kumpulan pertama: Ready + loadingMore; akhir menamatkan penunjuk',
      () async {
        unawaited(_controller(c).planTo(klia));
        await settle();
        expect(_state(c), isA<RouteLoading>());

        planner.add(RouteBatch([route(0)], done: false));
        await settle();
        var ready = _state(c) as RouteReady;
        expect(ready.loadingMore, isTrue);
        expect(ready.options, hasLength(1));

        planner.add(RouteBatch([route(0), route(1)], done: false));
        await settle();
        ready = _state(c) as RouteReady;
        expect(ready.options, hasLength(2));
        expect(ready.selectedIndex, 0);

        planner.add(RouteBatch([route(0), route(1), route(2)], done: true));
        await planner.close();
        await settle();
        ready = _state(c) as RouteReady;
        expect(ready.loadingMore, isFalse);
        expect(ready.options, hasLength(3));
      },
    );

    test(
      'laluan pilihan pengguna kekal terpilih walau susunan berubah',
      () async {
        final a = route(0);
        final b = route(1);
        final cc = route(2);
        unawaited(_controller(c).planTo(klia));
        await settle();
        planner.add(RouteBatch([a, b, cc], done: false));
        await settle();

        _controller(c).select(2);
        expect((_state(c) as RouteReady).selected, same(cc));

        // Laluan utama baharu tiba di hadapan; laluan terpilih beralih ke indeks 3 tetapi kekal.
        final better = route(5, durationS: 2900);
        planner.add(RouteBatch([better, a, b, cc], done: true));
        await planner.close();
        await settle();
        final ready = _state(c) as RouteReady;
        expect(ready.selectedIndex, 3);
        expect(ready.selected.points, same(cc.points));
      },
    );

    test('tanpa pilihan pengguna: sentiasa laluan utama (indeks 0)', () async {
      unawaited(_controller(c).planTo(klia));
      await settle();
      planner.add(RouteBatch([route(1), route(2)], done: false));
      await settle();
      planner.add(RouteBatch([route(0), route(1), route(2)], done: true));
      await planner.close();
      await settle();
      expect((_state(c) as RouteReady).selectedIndex, 0);
    });

    test('hanya 6 dipaparkan; showMore membuka sehingga 10', () async {
      unawaited(_controller(c).planTo(klia));
      await settle();
      planner.add(
        RouteBatch([for (var i = 0; i < 9; i++) route(i)], done: true),
      );
      await planner.close();
      await settle();

      var ready = _state(c) as RouteReady;
      expect(ready.visibleOptions, hasLength(6));
      expect(ready.hiddenCount, 3);

      _controller(c).showMore();
      ready = _state(c) as RouteReady;
      expect(ready.visibleOptions, hasLength(9));
      expect(ready.hiddenCount, 0);
    });

    test(
      'memilih laluan di luar 6 membuka semua supaya ia kelihatan',
      () async {
        unawaited(_controller(c).planTo(klia));
        await settle();
        final options = [for (var i = 0; i < 9; i++) route(i)];
        planner.add(RouteBatch(options, done: false));
        await settle();
        _controller(c).showMore();
        _controller(c).select(8);
        // Kumpulan baharu tiba: laluan terpilih (indeks 8) kekal kelihatan.
        planner.add(RouteBatch(options, done: true));
        await planner.close();
        await settle();
        final ready = _state(c) as RouteReady;
        expect(ready.selectedIndex, 8);
        expect(ready.expanded, isTrue);
      },
    );

    test(
      'ralat selepas kumpulan pertama: kekal Ready, penunjuk dimatikan',
      () async {
        unawaited(_controller(c).planTo(klia));
        await settle();
        planner.add(RouteBatch([route(0)], done: false));
        await settle();
        planner.addError(StateError('rosak'));
        await planner.close();
        await settle();
        final ready = _state(c) as RouteReady;
        expect(ready.loadingMore, isFalse);
        expect(ready.options, hasLength(1));
      },
    );

    test('ralat sebelum kumpulan pertama: RouteFailed', () async {
      unawaited(_controller(c).planTo(klia));
      await settle();
      planner.addError(const RoutingFailure(RoutingFailureKind.noRoute));
      await planner.close();
      await settle();
      expect((_state(c) as RouteFailed).kind, RoutingFailureKind.noRoute);
    });
  });

  group('anggaran tol di latar', () {
    late _FakeTollFinder finder;
    late ProviderContainer c;

    RouteOption tolled(int n) => sampleOption(
      durationS: 3000 + n * 100,
      distanceM: 60000 + n * 1000,
      points: [klcc, GeoPoint(3.0 + n * 0.01, 101.7), klia],
    );

    ProviderContainer build(
      FakeRoutePlanner repo, {
      TollRates rates = TollRates.empty,
    }) {
      final container = ProviderContainer(
        overrides: [
          routeOptionsPlannerProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(location),
          sharedPreferencesProvider.overrideWithValue(_prefs),
          tollPlazaFinderProvider.overrideWithValue(finder),
          tollRatesProvider.overrideWith((ref) async => rates),
        ],
      );
      addTearDown(container.dispose);
      container.listen(routePreviewControllerProvider, (_, _) {});
      return container;
    }

    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() => finder = _FakeTollFinder());

    test(
      'plaza dikesan selepas laluan siap; terpilih dahulu; tanpa dataset harga tidak diketahui',
      () async {
        finder.plazas = const [
          TollPlaza(id: '1', point: GeoPoint(3.05, 101.7), alongM: 100),
          TollPlaza(id: '2', point: GeoPoint(3.06, 101.7), alongM: 900),
        ];
        c = build(FakeRoutePlanner((_) async => [tolled(0), tolled(1)]));
        await _controller(c).planTo(klia);
        await settle();

        final ready = _state(c) as RouteReady;
        expect(finder.calls, hasLength(2));
        expect(finder.calls.first, same(ready.options.first.points));
        final est = ready.tollOf(ready.options.first)!;
        expect(est.plazaCount, 2);
        expect(
          est.isUnknown,
          isTrue,
          reason: 'dataset kosong: tiada harga direka',
        );
      },
    );

    test('dengan dataset disahkan: harga dijumlahkan', () async {
      finder.plazas = const [
        TollPlaza(id: '1', point: GeoPoint(3.05, 101.7), alongM: 100),
      ];
      final rates = TollRates.parse(
        jsonEncode({
          'version': 1,
          'plazas': [
            {
              'id': 'p',
              'type': 'open',
              'lat': 3.05,
              'lng': 101.7,
              'ratesRm': {'1': 4.2},
              'source': 'https://contoh.example',
              'verifiedOn': '2026-10-01',
            },
          ],
        }),
      );
      c = build(FakeRoutePlanner((_) async => [tolled(0)]), rates: rates);
      await _controller(c).planTo(klia);
      await settle();

      final ready = _state(c) as RouteReady;
      expect(ready.tollOf(ready.selected)!.knownRm, 4.2);
      expect(ready.tollOf(ready.selected)!.isExact, isTrue);
    });

    test(
      'kegagalan carian plaza senyap: laluan kekal, tiada anggaran',
      () async {
        finder.fail = true;
        c = build(FakeRoutePlanner((_) async => [tolled(0)]));
        await _controller(c).planTo(klia);
        await settle();
        final ready = _state(c) as RouteReady;
        expect(ready.tolls, isEmpty);
        expect(ready.loadingMore, isFalse);
      },
    );

    test('laluan tanpa tol tidak menyoal plaza', () async {
      c = build(
        FakeRoutePlanner(
          (_) async => [
            sampleOption(hasTolls: false, points: [klcc, klia]),
          ],
        ),
      );
      await _controller(c).planTo(klia);
      await settle();
      expect(finder.calls, isEmpty);
    });

    test('dimatikan: tiada carian', () async {
      c = ProviderContainer(
        overrides: [
          routeOptionsPlannerProvider.overrideWithValue(
            FakeRoutePlanner((_) async => [tolled(0)]),
          ),
          locationServiceProvider.overrideWithValue(location),
          sharedPreferencesProvider.overrideWithValue(_prefs),
          tollPlazaFinderProvider.overrideWithValue(finder),
          tollLookupEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      c.listen(routePreviewControllerProvider, (_, _) {});
      await _controller(c).planTo(klia);
      await settle();
      expect(finder.calls, isEmpty);
    });
  });
}

class _ProgressivePlanner implements ProgressiveRoutePlanner {
  final _controller = StreamController<RouteBatch>();

  void add(RouteBatch batch) => _controller.add(batch);
  void addError(Object error) => _controller.addError(error);
  Future<void> close() => _controller.close();

  @override
  Stream<RouteBatch> watch(RouteQuery query) => _controller.stream;

  @override
  Future<List<RouteOption>> plan(RouteQuery query) async =>
      (await watch(query).last).options;
}

class _FakeTollFinder implements TollPlazaFinder {
  List<TollPlaza> plazas = const [];
  bool fail = false;
  final List<List<GeoPoint>> calls = [];

  @override
  Future<List<TollPlaza>> find(RouteOption route) async {
    calls.add(route.points);
    if (fail) throw const TollLookupFailure('x');
    return plazas;
  }
}
