import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/route_preview/presentation/route_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late SharedPreferences prefs;
  late FakeLocationService location;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    location = FakeLocationService(
      fix: LocationFix(
        point: klcc,
        headingDegrees: 90,
        accuracyMeters: 8,
        timestamp: DateTime.now(),
      ),
    );
  });

  ProviderContainer make(FakeRoutePlanner planner) {
    final c = ProviderContainer(
      overrides: [
        routeOptionsPlannerProvider.overrideWithValue(planner),
        routePlannerProvider.overrideWithValue(planner),
        locationServiceProvider.overrideWithValue(location),
        sharedPreferencesProvider.overrideWithValue(prefs),
        tollLookupEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  RoutePreviewController ctl(ProviderContainer c) =>
      c.read(routePreviewControllerProvider.notifier);
  RouteReady ready(ProviderContainer c) =>
      c.read(routePreviewControllerProvider) as RouteReady;

  group('titik mula pilihan', () {
    test('laluan dikira dari tempat itu tanpa GPS, tanpa heading', () async {
      location.accessValue = LocationAccess.deniedForever;
      final planner = FakeRoutePlanner((_) async => [sampleOption()]);
      final c = make(planner);

      ctl(c).setStart(batuCaves, label: 'Batu Caves');
      await ctl(c).planTo(klia, destinationLabel: 'KLIA');

      final q = ready(c).query;
      expect(q.origin, batuCaves);
      expect(q.originLabel, 'Batu Caves');
      expect(q.isCustomOrigin, isTrue);
      expect(q.headingDegrees, isNull);
    });

    test('tukar pada laluan sedia ada, kemudian kembali ke GPS', () async {
      final planner = FakeRoutePlanner((_) async => [sampleOption()]);
      final c = make(planner);
      await ctl(c).planTo(klia, destinationLabel: 'KLIA');
      expect(ready(c).query.isCustomOrigin, isFalse);

      await ctl(c).setOrigin(batuCaves, label: 'Batu Caves');
      expect(ready(c).query.origin, batuCaves);
      expect(ready(c).query.destinationLabel, 'KLIA');

      await ctl(c).setOrigin(null);
      expect(ready(c).query.origin, klcc);
      expect(ready(c).query.isCustomOrigin, isFalse);
      expect(ready(c).query.headingDegrees, 90);
    });

    test('GPS tiada: titik mula lain tetap menghasilkan laluan', () async {
      location.accessValue = LocationAccess.deniedForever;
      final planner = FakeRoutePlanner((_) async => [sampleOption()]);
      final c = make(planner);
      await ctl(c).planTo(klia, destinationLabel: 'KLIA');
      expect(
        c.read(routePreviewControllerProvider),
        isA<RouteLocationUnavailable>(),
      );

      await ctl(c).setOrigin(batuCaves, label: 'Batu Caves');
      expect(ready(c).query.origin, batuCaves);
      expect(ready(c).query.destination, klia);
    });

    test(
      'titik mula sama dengan destinasi: dinyatakan, tiada permintaan',
      () async {
        final planner = FakeRoutePlanner((_) async => [sampleOption()]);
        final c = make(planner);

        ctl(c).setStart(klia, label: 'KLIA');
        await ctl(c).planTo(klia, destinationLabel: 'KLIA');

        final state = c.read(routePreviewControllerProvider) as RouteFailed;
        expect(state.kind, RoutingFailureKind.samePoint);
        expect(planner.queries, isEmpty);
      },
    );

    test('GPS tiada: perhentian kekal selepas titik mula dipilih', () async {
      location.accessValue = LocationAccess.deniedForever;
      final planner = FakeRoutePlanner((_) async => [sampleOption()]);
      final c = make(planner);
      await ctl(c).planTo(klia, via: const [klcc]);

      await ctl(c).setOrigin(batuCaves, label: 'Batu Caves');

      expect(ready(c).query.via, const [klcc]);
    });

    test('permintaan AI sentiasa dari GPS, bukan pratonton lama', () async {
      final planner = FakeRoutePlanner((_) async => [sampleOption()]);
      final c = make(planner);
      await ctl(c).planTo(klia);
      await ctl(c).setOrigin(batuCaves, label: 'Batu Caves');

      await ctl(c).replanFromGps(klcc, label: 'KLCC');

      expect(ready(c).query.isCustomOrigin, isFalse);
      expect(ready(c).query.origin, klcc);
    });

    test(
      'kekal bila destinasi ditukar, dilupakan bila laluan dipadam',
      () async {
        final planner = FakeRoutePlanner((_) async => [sampleOption()]);
        final c = make(planner);
        await ctl(c).planTo(klia);
        await ctl(c).setOrigin(batuCaves, label: 'Batu Caves');

        await ctl(c).planTo(klcc, destinationLabel: 'KLCC');
        expect(ready(c).query.origin, batuCaves);

        ctl(c).clear();
        await ctl(c).planTo(klia);
        expect(ready(c).query.isCustomOrigin, isFalse);
      },
    );
  });

  group('pilihan tol', () {
    final tolled = sampleOption(durationS: 3000);
    final free = sampleOption(
      durationS: 4000,
      hasTolls: false,
      points: const [klcc, batuCaves, klia],
    );

    test('ditapis tanpa rangkaian, dan semua kembali', () async {
      final planner = FakeRoutePlanner((_) async => [tolled, free]);
      final c = make(planner);
      await ctl(c).planTo(klia);
      final calls = planner.queries.length;
      expect(ready(c).options, hasLength(2));
      expect(ready(c).hasTollChoice, isTrue);

      await ctl(c).setTollFilter(RouteTollFilter.noTolls);
      expect(ready(c).options.every((o) => !o.hasTolls), isTrue);
      expect(ready(c).selectedQuery.avoidTolls, isTrue);

      await ctl(c).setTollFilter(RouteTollFilter.withTolls);
      expect(ready(c).options.every((o) => o.hasTolls), isTrue);

      await ctl(c).setTollFilter(RouteTollFilter.any);
      expect(ready(c).options, hasLength(2));
      expect(planner.queries, hasLength(calls));
    });

    test(
      '"Tanpa tol" diingat dan diminta terus untuk perjalanan baharu',
      () async {
        final first = make(FakeRoutePlanner((_) async => [tolled, free]));
        await ctl(first).planTo(klia);
        await ctl(first).setTollFilter(RouteTollFilter.noTolls);

        final planner = FakeRoutePlanner((_) async => [free]);
        final c = make(planner);
        await ctl(c).planTo(klia);
        expect(planner.queries.first.avoidTolls, isTrue);
        expect(ready(c).tollFilter, RouteTollFilter.noTolls);
      },
    );

    test('"Dengan tol" tamat bila laluan dipadam; "Tanpa tol" kekal', () async {
      final c = make(FakeRoutePlanner((_) async => [tolled, free]));
      await ctl(c).planTo(klia);
      await ctl(c).setTollFilter(RouteTollFilter.withTolls);

      ctl(c).clear();
      await ctl(c).planTo(klia);
      expect(ready(c).tollFilter, RouteTollFilter.any);
      expect(ready(c).options, hasLength(2));

      await ctl(c).setTollFilter(RouteTollFilter.noTolls);
      ctl(c).clear();
      await ctl(c).planTo(klia);
      expect(ready(c).tollFilter, RouteTollFilter.noTolls);
    });

    test('"Dengan tol" tidak diingat', () async {
      final first = make(FakeRoutePlanner((_) async => [tolled, free]));
      await ctl(first).planTo(klia);
      await ctl(first).setTollFilter(RouteTollFilter.withTolls);

      final c = make(FakeRoutePlanner((_) async => [tolled, free]));
      await ctl(c).planTo(klia);
      expect(ready(c).tollFilter, RouteTollFilter.any);
      expect(ready(c).options, hasLength(2));
    });

    test('tiada laluan tanpa tol: dinyatakan, laluan yang ada kekal', () async {
      final planner = FakeRoutePlanner((_) async => [tolled]);
      final c = make(planner);
      await ctl(c).planTo(klia);

      await ctl(c).setTollFilter(RouteTollFilter.noTolls);

      expect(planner.queries.last.avoidTolls, isTrue);
      expect(ready(c).options, hasLength(1));
      expect(ready(c).tollFilterUnmet, isTrue);
    });

    test(
      'larangan mutlak menemui laluan tanpa tol sebelum kata tiada',
      () async {
        await prefs.setBool('route.avoidTolls', true);
        final planner = FakeRoutePlanner(
          (q) async => q.excludeTolls ? [free] : [tolled],
        );
        final c = make(planner);

        await ctl(c).planTo(klia);

        expect(planner.queries.last.excludeTolls, isTrue);
        expect(ready(c).tollFilterUnmet, isFalse);
        expect(ready(c).options.single.hasTolls, isFalse);
        expect(ready(c).query.excludeTolls, isFalse);
      },
    );

    test('semakan gagal: tidak mendakwa tiada laluan tanpa tol', () async {
      await prefs.setBool('route.avoidTolls', true);
      final planner = FakeRoutePlanner((q) async {
        if (q.excludeTolls) {
          throw const RoutingFailure(RoutingFailureKind.network);
        }
        return [tolled];
      });
      final c = make(planner);

      await ctl(c).planTo(klia);

      expect(ready(c).tollFilterUnmet, isTrue);
      expect(ready(c).tollFilterUnverified, isTrue);
      expect(ready(c).loadingMore, isFalse);
    });

    test('larangan mutlak tiada laluan: disahkan tiada', () async {
      await prefs.setBool('route.avoidTolls', true);
      final planner = FakeRoutePlanner((q) async {
        if (q.excludeTolls) {
          throw const RoutingFailure(RoutingFailureKind.noRoute);
        }
        return [tolled];
      });
      final c = make(planner);

      await ctl(c).planTo(klia);

      expect(ready(c).tollFilterUnmet, isTrue);
      expect(ready(c).tollFilterUnverified, isFalse);
    });

    test('keluar daripada "Tanpa tol": laluan bertol diminta semula', () async {
      await prefs.setBool('route.avoidTolls', true);
      final planner = FakeRoutePlanner(
        (q) async => q.avoidTolls ? [free] : [tolled, free],
      );
      final c = make(planner);
      await ctl(c).planTo(klia);
      expect(ready(c).options, hasLength(1));

      await ctl(c).setTollFilter(RouteTollFilter.any);

      expect(planner.queries.last.avoidTolls, isFalse);
      expect(ready(c).options.any((o) => o.hasTolls), isTrue);
    });
  });

  group('lembaran laluan', () {
    Future<void> pump(
      WidgetTester tester,
      RouteReady state, {
      VoidCallback? onStart,
      VoidCallback? onPickOrigin,
      ValueChanged<RouteTollFilter>? onToll,
      double textScale = 1,
    }) async {
      usePhoneSurface(tester);
      reduceMotion(tester);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: RouteSummarySheet(
            state: state,
            onSelect: (_) {},
            onVehicleChanged: (_) {},
            onRetry: () {},
            onClear: () {},
            onStart: onStart,
            onSimulate: () {},
            onPickOrigin: onPickOrigin ?? () {},
            onUseMyLocation: () {},
            onTollFilterChanged: onToll ?? (_) {},
            now: DateTime(2026, 11, 9, 9),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const gps = RouteQuery(
      origin: klcc,
      destination: klia,
      destinationLabel: 'KLIA',
    );
    const custom = RouteQuery(
      origin: batuCaves,
      originLabel: 'Batu Caves',
      destination: klia,
      destinationLabel: 'KLIA',
    );

    testWidgets('baris "Dari" boleh ditekan', (tester) async {
      var picks = 0;
      await pump(
        tester,
        RouteReady(query: gps, options: [sampleOption()]),
        onPickOrigin: () => picks++,
      );
      expect(find.text('Lokasi saya → KLIA'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('route-origin')));
      expect(picks, 1);
    });

    testWidgets('titik mula lain: pratonton, butang utama bukan "Mula"', (
      tester,
    ) async {
      await pump(
        tester,
        RouteReady(query: custom, options: [sampleOption()]),
        onStart: () {},
      );
      expect(find.text('Batu Caves → KLIA'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-origin-note')), findsOneWidget);
      expect(find.text('Guna lokasi saya'), findsOneWidget);
      expect(find.text('Mula'), findsNothing);
      expect(find.byKey(const ValueKey('nav-simulate')), findsOneWidget);
    });

    testWidgets('bar tol: tukar pilihan, tersembunyi bila tiada tol', (
      tester,
    ) async {
      RouteTollFilter? chosen;
      await pump(
        tester,
        RouteReady(query: gps, options: [sampleOption()], hasTollChoice: true),
        onToll: (f) => chosen = f,
      );
      await tester.tap(find.text('Tanpa tol'));
      expect(chosen, RouteTollFilter.noTolls);
      expect(find.text('Dengan tol'), findsOneWidget);

      await pump(
        tester,
        RouteReady(query: gps, options: [sampleOption(hasTolls: false)]),
      );
      expect(find.byKey(const ValueKey('route-toll-filter')), findsNothing);
    });

    testWidgets('gagal dari titik mula lain: boleh tukar atau guna lokasi', (
      tester,
    ) async {
      var picked = 0;
      usePhoneSurface(tester);
      reduceMotion(tester);
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: RouteSummarySheet(
            state: const RouteFailed(
              query: custom,
              kind: RoutingFailureKind.noRoute,
            ),
            onSelect: (_) {},
            onVehicleChanged: (_) {},
            onRetry: () {},
            onClear: () {},
            onSimulate: () {},
            onPickOrigin: () => picked++,
            onUseMyLocation: () {},
            onTollFilterChanged: (_) {},
            now: DateTime(2026, 11, 9, 9),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tiada laluan dari titik mula'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('route-failed-origin-reset')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('route-failed-origin-change')),
      );
      expect(picked, 1);
    });

    testWidgets('tiada padanan dinyatakan; teks besar tidak melimpah', (
      tester,
    ) async {
      await pump(
        tester,
        RouteReady(
          query: custom,
          options: [sampleOption()],
          hasTollChoice: true,
          tollFilter: RouteTollFilter.noTolls,
          tollFilterUnmet: true,
        ),
        onStart: () {},
        textScale: 1.6,
      );
      expect(
        find.byKey(const ValueKey('route-toll-filter-unmet')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
