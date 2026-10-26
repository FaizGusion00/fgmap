import 'dart:async';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
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
}
