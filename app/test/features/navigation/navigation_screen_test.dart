import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/map/presentation/map_screen.dart';
import 'package:fgmap/features/navigation/data/navigation_settings.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapHarness map;
  late FakeVoice voice;
  late FakeAwake awake;
  late FakeLocationService location;
  late SharedPreferences prefs;

  setUp(() async {
    map = FakeMapHarness();
    voice = FakeVoice();
    awake = FakeAwake();
    location = FakeLocationService(fix: const LocationFix(point: klcc));
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
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => [lShapedRoute(legM: 800)]),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        voiceGuideProvider.overrideWithValue(voice),
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        screenAwakeProvider.overrideWithValue(awake),
      ],
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    );
    return container;
  }

  /// Simulasi menjadualkan pemasa; hentikan dan biarkan pemasa terakhir selesai supaya tiada
  /// pemasa tergantung selepas ujian.
  Future<void> finish(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    );
    await container.read(navigationControllerProvider.notifier).stop();
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> planRoute(WidgetTester tester) async {
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
  }

  testWidgets('laluan siap: butang Mula dan Simulasi dipaparkan', (
    tester,
  ) async {
    await pumpScreen(tester);
    await planRoute(tester);
    expect(find.byKey(const ValueKey('nav-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-simulate')), findsOneWidget);
    expect(find.text('Mula'), findsOneWidget);
    expect(find.text('Simulasi'), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'Simulasi: HUD navigasi muncul, kamera dan kenderaan dipacu, pratonton disembunyikan',
    (tester) async {
      final container = await pumpScreen(tester);
      await planRoute(tester);

      await tester.tap(find.byKey(const ValueKey('nav-simulate')));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      final state = container.read(navigationControllerProvider);
      expect(state.phase, NavPhase.active);
      expect(state.simulated, isTrue);
      expect(awake.enabled, isTrue);

      expect(find.byType(ManeuverBanner), findsOneWidget);
      expect(find.byType(NavBottomPanel), findsOneWidget);
      expect(find.byType(SpeedBubble), findsOneWidget);
      expect(find.text('Belok kanan'), findsOneWidget);
      expect(find.text('Jalan Dua'), findsOneWidget);
      expect(find.text('Simulasi'), findsOneWidget); // lencana
      expect(find.byKey(const ValueKey('search-pill')), findsNothing);
      expect(find.byKey(const ValueKey('nav-start')), findsNothing);

      // Kamera ikut kenderaan dengan condongan dan arah ke timur (laluan menghala timur).
      expect(map.camera.moveToCalls, isNotEmpty);
      expect(map.camera.vehicleCalls, isNotEmpty);
      final cam = map.camera.moveToCalls.last;
      expect(cam.tilt, greaterThan(20));
      expect(cam.bearing, closeTo(90, 25));
      // Lapisan laluan peta hanya laluan baki (satu garisan utama), tiada alternatif.
      final lines = map.config!.routes;
      expect(lines.length, 1);
      expect(lines.single.isMain, isTrue);
      expect(map.config!.showUserLocation, isFalse);

      // Pengumuman suara pembukaan disebut.
      expect(voice.said.first.$1.text, 'Navigasi bermula.');
      await finish(tester);
    },
  );

  testWidgets(
    'tamatkan: pengesahan, kemudian kembali ke peta 2D menghadap utara',
    (tester) async {
      final container = await pumpScreen(tester);
      await planRoute(tester);
      await tester.tap(find.byKey(const ValueKey('nav-simulate')));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      await tester.tap(find.byTooltip('Tamat'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tamatkan navigasi?'), findsOneWidget);

      // Teruskan: navigasi kekal.
      await tester.tap(find.text('Teruskan'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(navigationControllerProvider).isActive, isTrue);

      await tester.tap(find.byTooltip('Tamat'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(FilledButton, 'Tamat'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(navigationControllerProvider).isActive, isFalse);
      expect(find.byType(ManeuverBanner), findsNothing);
      expect(find.byKey(const ValueKey('search-pill')), findsOneWidget);
      expect(awake.enabled, isFalse);
      expect(map.camera.vehicleCalls.last, isNull);
      expect(map.camera.animateToCalls.last.tilt, 0);
      expect(map.camera.animateToCalls.last.bearing, 0);
      await finish(tester);
    },
  );

  testWidgets('butang mute dan kamera menukar tetapan dan disimpan', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    await planRoute(tester);
    await tester.tap(find.byKey(const ValueKey('nav-simulate')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byTooltip('Senyapkan suara'));
    await tester.pump();
    expect(container.read(navigationSettingsProvider).voiceEnabled, isFalse);
    expect(prefs.getBool('nav.voice'), isFalse);
    expect(find.byTooltip('Hidupkan suara'), findsOneWidget);

    await tester.tap(find.byTooltip('Kamera auto 3D/2D'));
    await tester.pump();
    expect(
      container.read(navigationSettingsProvider).cameraMode,
      NavCameraMode.tilted,
    );
    await tester.tap(find.byTooltip('Kamera 3D'));
    await tester.pump();
    expect(
      container.read(navigationSettingsProvider).cameraMode,
      NavCameraMode.flat,
    );
    expect(prefs.getString('nav.cameraMode'), 'flat');
    await finish(tester);
  });

  testWidgets(
    'pengguna menggerakkan peta: butang Pusatkan muncul dan memulihkan',
    (tester) async {
      await pumpScreen(tester);
      await planRoute(tester);
      await tester.tap(find.byKey(const ValueKey('nav-simulate')));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(RecenterButton), findsNothing);

      map.config!.onUserGesture!.call();
      await tester.pump();
      expect(find.byType(RecenterButton), findsOneWidget);
      final frozen = map.camera.moveToCalls.length;
      await tester.pump(const Duration(seconds: 1));
      expect(map.camera.moveToCalls.length, frozen);

      await tester.tap(find.byType(RecenterButton));
      await tester.pump();
      expect(find.byType(RecenterButton), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(map.camera.moveToCalls.length, greaterThan(frozen));
      await finish(tester);
    },
  );

  testWidgets('sampai: kad ketibaan, kemudian Selesai menutup navigasi', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    await planRoute(tester);
    await tester.tap(find.byKey(const ValueKey('nav-simulate')));
    await tester.pump();
    // Laluan 1.6 km pada kelajuan simulasi: cukup lama untuk tiba.
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (container.read(navigationControllerProvider).phase ==
          NavPhase.arrived) {
        break;
      }
    }
    expect(
      container.read(navigationControllerProvider).phase,
      NavPhase.arrived,
    );
    await tester.pump();
    expect(find.byType(ArrivalCard), findsOneWidget);
    expect(find.text('Anda telah sampai'), findsOneWidget);
    expect(voice.said.last.$1.text, 'Anda telah sampai.');

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(container.read(navigationControllerProvider).isActive, isFalse);
    expect(find.byType(ArrivalCard), findsNothing);
    await finish(tester);
  });

  testWidgets(
    'navigasi menggantung ikutan idle (satu sahaja pemilik kamera); tamat navigasi menyambungnya',
    (tester) async {
      final container = await pumpScreen(tester);
      expect(
        location.trackingController.hasListener,
        isTrue,
        reason: 'idle: kamera mengikut pengguna',
      );

      await planRoute(tester);
      await tester.tap(find.byKey(const ValueKey('nav-simulate')));
      await tester.pump();
      expect(container.read(navigationControllerProvider).isActive, isTrue);
      expect(
        location.trackingController.hasListener,
        isFalse,
        reason: 'navigasi memandu kamera; strim GPS kedua membazir bateri',
      );

      await container.read(navigationControllerProvider.notifier).stop();
      await tester.pumpAndSettle();
      expect(location.trackingController.hasListener, isTrue);
      await finish(tester);
    },
  );

  testWidgets('tema gelap dan English: HUD dipaparkan tanpa overflow', (
    tester,
  ) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const MapScreen(),
      locale: const Locale('en'),
      overrides: [
        map.override,
        locationServiceProvider.overrideWithValue(
          FakeLocationService(fix: const LocationFix(point: klcc)),
        ),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => [lShapedRoute(legM: 800)]),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        voiceGuideProvider.overrideWithValue(voice),
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        screenAwakeProvider.overrideWithValue(awake),
      ],
    );
    await tester.pumpAndSettle();
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-simulate')));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Turn right'), findsOneWidget);
    expect(find.byTooltip('End'), findsOneWidget);
    await finish(tester);
  });
}
