import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/theme_controller.dart';
import 'package:fgmap/features/map/presentation/map_screen.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeMapHarness map;
  late FakeLocationService location;
  late FakeRoutePlanner repo;
  late SharedPreferences prefs;

  setUp(() async {
    map = FakeMapHarness();
    location = FakeLocationService(fix: const LocationFix(point: klcc));
    repo = FakeRoutePlanner(
      (_) async => [
        sampleOption(),
        // Titik berbeza: laluan alternatif bukan laluan yang sama.
        sampleOption(
          durationS: 3722,
          distanceM: 72447,
          points: const [klcc, batuCaves, klia],
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const MapScreen(),
      overrides: [
        map.override,
        locationServiceProvider.overrideWithValue(location),
        routePlannerProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
  }

  testWidgets(
    'keadaan awal: petunjuk long-press, atribusi OSM dan butang lokasi kelihatan',
    (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
      expect(
        find.text('Tekan lama pada peta untuk pilih destinasi'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('© penyumbang OpenStreetMap · OpenFreeMap'),
        findsOneWidget,
        reason: 'atribusi ODbL mesti boleh dicapai',
      );
      expect(find.byTooltip('Lokasi saya'), findsOneWidget);
      expect(find.byTooltip('Paparan'), findsOneWidget);
      expect(find.text('Mengira laluan…'), findsNothing);
      // Regresi: chip petunjuk pernah berada di tengah skrin (Center dalam Row setinggi skrin).
      expect(
        tester
            .getTopLeft(find.text('Tekan lama pada peta untuk pilih destinasi'))
            .dy,
        lessThan(150),
        reason: 'petunjuk mesti di bahagian atas skrin',
      );
      expect(map.config!.routes, isEmpty);
      expect(map.config!.destination, isNull);
    },
  );

  testWidgets(
    'long-press -> laluan dikira, lembaran dipaparkan, peta menerima laluan dan destinasi',
    (tester) async {
      await pumpScreen(tester);

      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();

      expect(
        find.text('58 min'),
        findsWidgets,
      ); // tajuk lembaran + chip laluan 1
      expect(find.text('67.0 km'), findsOneWidget);
      expect(find.text('Ada tol'), findsOneWidget);
      expect(find.text('Laluan 1 · 58 min'), findsOneWidget);
      expect(find.text('Laluan 2 · 1 j 2 min'), findsOneWidget);

      final cfg = map.config!;
      expect(cfg.destination, klia);
      expect(cfg.routes, hasLength(2));
      expect(cfg.routes.where((r) => r.isMain), hasLength(1));
      // Laluan utama dilukis terakhir (paling atas).
      expect(cfg.routes.last.isMain, isTrue);

      // Asal ialah lokasi pengguna (fix), bukan pusat peta.
      expect(repo.queries.single.origin, klcc);
      expect(repo.queries.single.originIsMapCenter, isFalse);

      // Kamera memuatkan laluan dalam pandangan dengan ruang untuk lembaran bawah.
      expect(map.camera.fitToCalls, hasLength(1));
      expect(map.camera.fitToCalls.single.$2.bottom, greaterThan(200));

      // Petunjuk tekan-lama disorok selepas pengguna mencuba; pil carian kekal.
      expect(
        find.text('Tekan lama pada peta untuk pilih destinasi'),
        findsNothing,
      );
      expect(find.text('Cari destinasi'), findsOneWidget);
    },
  );

  testWidgets(
    'memilih Laluan 2 menukar laluan utama tanpa menyesuaikan semula kamera',
    (tester) async {
      await pumpScreen(tester);
      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();
      final mainBefore = map.config!.routes.last.points;

      await tester.tap(find.text('Laluan 2 · 1 j 2 min'));
      await tester.pumpAndSettle();

      expect(
        find.text('1 j 2 min'),
        findsOneWidget,
      ); // 3722 s -> 62 min -> 1 j 2 min
      expect(map.config!.routes.last.points, isNot(same(mainBefore)));
      expect(
        map.camera.fitToCalls,
        hasLength(1),
        reason: 'bertukar laluan tidak menggerakkan kamera',
      );
    },
  );

  testWidgets('Elak tol mengira semula dengan pilihan baharu', (tester) async {
    await pumpScreen(tester);
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elak tol'));
    await tester.pumpAndSettle();

    expect(repo.queries, hasLength(2));
    expect(repo.queries.last.avoidTolls, isTrue);
  });

  testWidgets('padam laluan menutup lembaran dan mengosongkan peta', (
    tester,
  ) async {
    await pumpScreen(tester);
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Padam laluan'), findsOneWidget);

    await tester.tap(find.byTooltip('Padam laluan'));
    await tester.pumpAndSettle();

    expect(find.text('Ada tol'), findsNothing);
    expect(map.config!.routes, isEmpty);
    expect(map.config!.destination, isNull);
  });

  testWidgets('tiada laluan: mesej mesra tanpa butang Cuba lagi', (
    tester,
  ) async {
    repo.handler = (_) async =>
        throw const RoutingFailure(RoutingFailureKind.noRoute);
    await pumpScreen(tester);

    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiada laluan ditemui'), findsOneWidget);
    expect(find.text('Cuba lagi'), findsNothing);
    expect(find.text('Padam laluan'), findsOneWidget);
    expect(
      map.config!.destination,
      klia,
      reason: 'penanda destinasi kekal supaya pengguna nampak apa yang gagal',
    );
  });

  testWidgets('server tidak tersedia: butang Cuba lagi memulihkan', (
    tester,
  ) async {
    var attempts = 0;
    repo.handler = (_) async {
      attempts++;
      if (attempts == 1) {
        throw const RoutingFailure(RoutingFailureKind.unavailable);
      }
      return [sampleOption()];
    };
    await pumpScreen(tester);

    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
    expect(find.textContaining('tidak tersedia'), findsOneWidget);

    await tester.tap(find.text('Cuba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('58 min'), findsWidgets);
    expect(attempts, 2);
  });

  testWidgets(
    'tanpa lokasi: laluan dikira dari pusat peta dan pengguna diberitahu',
    (tester) async {
      location.accessValue = LocationAccess.deniedForever;
      await pumpScreen(tester);

      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();

      expect(repo.queries.single.origin, map.camera.center);
      expect(find.textContaining('pusat peta'), findsOneWidget);
    },
  );

  group('kebenaran lokasi', () {
    testWidgets('sudah diberi: tiada dialog, kamera terus ke lokasi pengguna', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(map.camera.flyToCalls, [(klcc, 15.0)]);
      expect(map.config!.showUserLocation, isTrue);
    });

    testWidgets(
      'kebenaran ditangguh sehingga pengguna minta lokasi; penjelasan mendahului dialog sistem',
      (tester) async {
        location
          ..accessValue = LocationAccess.askable
          ..requestResult = LocationAccess.granted;
        await pumpScreen(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(
          location.requestCalls,
          0,
          reason: 'jangan minta lokasi sebelum pengguna memilih fungsinya',
        );
        expect(map.config!.showUserLocation, isFalse);

        await tester.tap(find.byTooltip('Lokasi saya'));
        await tester.pumpAndSettle();
        expect(find.text('Benarkan akses lokasi?'), findsOneWidget);
        expect(
          location.requestCalls,
          0,
          reason: 'dialog sistem belum boleh muncul sebelum pengguna bersetuju',
        );
        expect(map.config!.showUserLocation, isFalse);

        await tester.tap(find.text('Benarkan'));
        await tester.pumpAndSettle();

        expect(location.requestCalls, 1);
        expect(map.config!.showUserLocation, isTrue);
        expect(map.camera.flyToCalls, [(klcc, 15.0)]);
      },
    );

    testWidgets(
      'Bukan sekarang: tidak meminta kebenaran sistem dan app kekal berfungsi',
      (tester) async {
        location.accessValue = LocationAccess.askable;
        await pumpScreen(tester);

        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(find.byTooltip('Lokasi saya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bukan sekarang'));
        await tester.pumpAndSettle();

        expect(location.requestCalls, 0);
        expect(map.camera.flyToCalls, isEmpty);
        expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
      },
    );

    testWidgets(
      'ditolak kekal: tiada dialog semasa pelancaran; butang lokasi menawarkan Tetapan',
      (tester) async {
        location.accessValue = LocationAccess.deniedForever;
        await pumpScreen(tester);
        expect(
          find.byType(AlertDialog),
          findsNothing,
          reason: 'jangan ganggu pengguna yang telah menolak',
        );

        await tester.tap(find.byTooltip('Lokasi saya'));
        await tester.pumpAndSettle();
        expect(find.textContaining('dimatikan'), findsOneWidget);

        await tester.tap(find.text('Buka Tetapan'));
        await tester.pumpAndSettle();
        expect(location.openAppSettingsCalls, 1);
        expect(location.requestCalls, 0);
      },
    );

    testWidgets('GPS dimatikan: butang lokasi menawarkan Tetapan lokasi', (
      tester,
    ) async {
      location.accessValue = LocationAccess.serviceDisabled;
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Lokasi saya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka Tetapan'));
      await tester.pumpAndSettle();

      expect(location.openLocationSettingsCalls, 1);
    });

    testWidgets(
      'butang lokasi apabila sudah diberi menerbangkan kamera ke fix terkini',
      (tester) async {
        await pumpScreen(tester);
        map.camera.flyToCalls.clear();
        location.fix = LocationFix(
          point: batuCaves,
          accuracyMeters: 8,
          timestamp: DateTime.now(),
        );

        await tester.tap(find.byTooltip('Lokasi saya'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(map.camera.flyToCalls, [(batuCaves, 15.0)]);
        expect(find.text('Anggaran ketepatan lokasi ±8 m'), findsOneWidget);
      },
    );

    testWidgets('lokasi tiada fix: butang memaklumkan dan boleh dicuba semula', (
      tester,
    ) async {
      location.fix = null;
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Lokasi saya'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'GPS belum dapat lokasi yang cukup tepat. Pergi ke kawasan terbuka dan cuba lagi.',
        ),
        findsOneWidget,
      );
      expect(map.camera.flyToCalls, isEmpty);
      expect(find.byTooltip('Lokasi saya'), findsOneWidget);
    });
  });

  group('tetapan paparan', () {
    testWidgets('memilih Gelap dan AMOLED menukar dan menyimpan tetapan', (
      tester,
    ) async {
      final container = await pumpScreen(tester);

      await tester.tap(find.byTooltip('Paparan'));
      await tester.pumpAndSettle();
      expect(find.text('Hitam AMOLED'), findsOneWidget);

      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        container.read(themeControllerProvider),
        const ThemeSettings(mode: ThemeMode.dark, amoled: true),
      );
      expect(prefs.getString('theme.mode'), 'dark');
      expect(prefs.getBool('theme.amoled'), isTrue);
    });
  });

  testWidgets(
    'dengan animasi penuh, keadaan memuatkan tidak menimbulkan pengecualian',
    (tester) async {
      usePhoneSurface(tester);
      final pending = Future<List<RouteOption>>.delayed(
        const Duration(milliseconds: 400),
        () => [sampleOption()],
      );
      repo.handler = (_) => pending;
      await pumpApp(
        tester,
        const MapScreen(),
        overrides: [
          map.override,
          locationServiceProvider.overrideWithValue(location),
          routePlannerProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await tester.pump(const Duration(milliseconds: 50));

      map.config!.onLongPress(klia);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mengira laluan…'), findsOneWidget);

      await tester.pump(
        const Duration(milliseconds: 150),
      ); // kilau skeleton bergerak
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('58 min'), findsWidgets);
    },
  );
}
