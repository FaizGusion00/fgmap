import 'package:dio/dio.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/map_screen.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/place_search_controller.dart';
import 'package:fgmap/features/search/presentation/trip_planner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

class _Geocoder implements Geocoder {
  final List<String> queries = [];
  Future<List<Place>> Function(String q)? handler;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) {
    queries.add(query);
    return handler!(query);
  }
}

const klia1 = Place(
  name: 'KLIA',
  subtitle: 'Sepang, Selangor',
  point: klia,
  category: 'station',
);
const klcc1 = Place(
  name: 'KLCC',
  subtitle: 'Jalan Ampang, Kuala Lumpur',
  point: klcc,
);

const _debounce = Duration(milliseconds: 10);

void main() {
  late _Geocoder geocoder;
  late SharedPreferences prefs;

  setUp(() async {
    geocoder = _Geocoder()
      ..handler = (q) async => switch (q.toLowerCase()) {
        'klia' => [klia1],
        'klcc' => [klcc1],
        'zzzz' => <Place>[],
        _ => [Place(name: q, subtitle: '', point: const GeoPoint(3.0, 101.0))],
      };
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> overrides() => [
    geocoderProvider.overrideWithValue(geocoder),
    searchDebounceProvider.overrideWithValue(_debounce),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];

  /// Memaparkan butang yang membuka perancang dan menyimpan keputusannya.
  Future<ValueNotifier<Object?>> pumpHost(
    WidgetTester tester, {
    String? initialDestinationQuery,
  }) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    final result = ValueNotifier<Object?>('belum');
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => result.value = await TripPlannerPage.open(
                context,
                initialDestinationQuery: initialDestinationQuery,
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
      overrides: overrides(),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump(_debounce * 3);
    await tester.pump();
  }

  group('TripPlannerPage', () {
    testWidgets(
      'mula: medan destinasi aktif, petunjuk carian, asal ialah Lokasi saya',
      (tester) async {
        await pumpHost(tester);
        expect(find.text('Rancang perjalanan'), findsOneWidget);
        expect(find.textContaining('Taip nama tempat'), findsOneWidget);
        expect(
          find.text('Lokasi saya'),
          findsOneWidget,
          reason: 'hint medan asal',
        );
        expect(geocoder.queries, isEmpty);
      },
    );

    testWidgets('cari destinasi, pilih -> hasil hanya membawa destinasi', (
      tester,
    ) async {
      final result = await pumpHost(tester);
      await type(tester, 'destination-field', 'klia');

      expect(find.text('KLIA'), findsOneWidget);
      expect(find.text('Sepang, Selangor'), findsOneWidget);
      await tester.tap(find.text('KLIA'));
      await tester.pumpAndSettle();

      final sel = result.value! as TripSelection;
      expect(sel.destination, klia1);
    });

    testWidgets('destinasi daripada pautan dikongsi terus dicari', (
      tester,
    ) async {
      await pumpHost(tester, initialDestinationQuery: 'klia');

      await tester.pump(_debounce * 3);
      await tester.pump();
      expect(geocoder.queries, ['klia']);
      expect(find.text('KLIA'), findsOneWidget);
    });

    testWidgets(
      'tempat pilihan muncul dalam sejarah apabila planner dibuka semula',
      (tester) async {
        await pumpHost(tester);
        await type(tester, 'destination-field', 'klia');
        await tester.tap(find.text('KLIA'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();
        expect(find.text('Tempat terkini'), findsOneWidget);
        expect(find.text('KLIA'), findsOneWidget);

        await tester.tap(find.text('Padam sejarah'));
        await tester.pump();
        expect(find.text('Tempat terkini'), findsNothing);
      },
    );

    testWidgets('asal lokasi saya tidak boleh diubah', (tester) async {
      final result = await pumpHost(tester);

      expect(find.byKey(const ValueKey('origin-field')), findsNothing);
      expect(find.text('Lokasi saya'), findsOneWidget);
      expect(geocoder.queries, isEmpty);
      expect(result.value, 'belum');
    });

    testWidgets('tiada hasil', (tester) async {
      await pumpHost(tester);
      await type(tester, 'destination-field', 'zzzz');
      expect(find.textContaining('Tiada hasil untuk “zzzz”'), findsOneWidget);
    });

    testWidgets(
      'gagal rangkaian dengan mesej jelas dan Cuba lagi yang memulihkan',
      (tester) async {
        var fail = true;
        geocoder.handler = (q) async {
          if (fail) throw const GeocodeFailure(GeocodeFailureKind.network);
          return [klia1];
        };
        await pumpHost(tester);
        await type(tester, 'destination-field', 'klia');
        expect(find.textContaining('Tiada sambungan internet'), findsOneWidget);
        expect(
          find.textContaining('tekan lama pada peta'),
          findsOneWidget,
          reason: 'beritahu jalan alternatif',
        );

        fail = false;
        await tester.tap(find.text('Cuba lagi'));
        await tester.pump(_debounce * 3);
        await tester.pump();
        expect(find.text('KLIA'), findsOneWidget);
      },
    );

    testWidgets('butang kosongkan', (tester) async {
      await pumpHost(tester);
      await type(tester, 'destination-field', 'klia');
      await tester.tap(find.byTooltip('Kosongkan'));
      await tester.pump();
      expect(find.byTooltip('Kosongkan'), findsNothing);
      expect(find.textContaining('Taip nama tempat'), findsOneWidget);
    });
  });

  group('MapScreen + carian', () {
    late FakeMapHarness map;
    late FakeRoutePlanner planner;

    setUp(() {
      map = FakeMapHarness();
      planner = FakeRoutePlanner((_) async => [sampleOption()]);
    });

    Future<void> pumpMap(WidgetTester tester, {LocationFix? fix}) async {
      usePhoneSurface(tester);
      reduceMotion(tester);
      await pumpApp(
        tester,
        const MapScreen(),
        overrides: [
          ...overrides(),
          map.override,
          locationServiceProvider.overrideWithValue(
            FakeLocationService(fix: fix ?? const LocationFix(point: klcc)),
          ),
          routePlannerProvider.overrideWithValue(planner),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'pil carian membuka perancang; destinasi dipilih -> laluan dari lokasi saya dengan nama',
      (tester) async {
        await pumpMap(tester);
        expect(find.text('Cari destinasi'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('search-pill')));
        await tester.pumpAndSettle();
        await type(tester, 'destination-field', 'klia');
        await tester.tap(find.text('KLIA'));
        await tester.pumpAndSettle();

        final q = planner.queries.single;
        expect(q.destination, klia);
        expect(q.destinationLabel, 'KLIA');
        expect(q.origin, klcc, reason: 'lokasi pengguna');
        expect(
          find.text('Lokasi saya → KLIA'),
          findsOneWidget,
          reason: 'sheet memaparkan dari/ke',
        );
        expect(map.config!.destination, klia);
      },
    );

    testWidgets('menutup perancang tanpa memilih tidak mengira laluan', (
      tester,
    ) async {
      await pumpMap(tester);
      await tester.tap(find.byKey(const ValueKey('search-pill')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(planner.queries, isEmpty);
    });

    testWidgets('Elak tol mengekalkan asal GPS dan nama destinasi', (
      tester,
    ) async {
      await pumpMap(tester);
      await tester.tap(find.byKey(const ValueKey('search-pill')));
      await tester.pumpAndSettle();
      await type(tester, 'destination-field', 'klia');
      await tester.tap(find.text('KLIA'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Elak tol'));
      await tester.pumpAndSettle();

      expect(planner.queries, hasLength(2));
      expect(planner.queries.last.avoidTolls, isTrue);
      expect(planner.queries.last.destinationLabel, 'KLIA');
    });
  });
}
