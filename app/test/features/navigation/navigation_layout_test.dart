import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/map/presentation/map_screen.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/presentation/car/vehicle_overlay.dart';
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

/// HUD navigasi pada pelbagai saiz skrin. Kad manuver yang besar dan tiada susun atur mendatar ialah
/// punca kereta tidak kelihatan; ujian ini memastikan tiada elemen HUD menutup tempat kereta dilukis,
/// dan HUD tidak melimpah pada skrin kecil atau teks sistem besar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapHarness map;
  late SharedPreferences prefs;

  setUp(() async {
    map = FakeMapHarness();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpNavigating(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    usePhoneSurface(tester, size: size);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const MapScreen(),
      overrides: [
        map.override,
        locationServiceProvider.overrideWithValue(
          FakeLocationService(fix: const LocationFix(point: klcc)),
        ),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => [lShapedRoute(legM: 1500)]),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        voiceGuideProvider.overrideWithValue(FakeVoice()),
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        screenAwakeProvider.overrideWithValue(FakeAwake()),
      ],
    );
    await tester.pumpAndSettle();
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-simulate')));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    // Teks sistem dibesarkan SELEPAS navigasi bermula (lembaran laluan sudah hilang): yang diuji ialah HUD navigasi, bukan lembaran laluan.
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
  }

  Future<void> finish(WidgetTester tester, ProviderContainer container) async {
    await container.read(navigationControllerProvider.notifier).stop();
    await tester.pump(const Duration(seconds: 3));
  }

  /// Segi empat semua elemen HUD yang mesti tidak menutup kereta.
  Map<String, Rect> hudRects(WidgetTester tester) => {
    'banner': tester.getRect(find.byType(ManeuverBanner)),
    'panel': tester.getRect(find.byType(NavBottomPanel)),
    'speed': tester.getRect(find.byType(SpeedBubble)),
    'side': tester.getRect(find.byType(NavSideButtons)),
  };

  /// Tapak kereta di skrin: tengah mendatar, [carScreenOffsetFor] di bawah tengah menegak.
  Offset carAnchor(Size size) =>
      Offset(size.width / 2, size.height * (0.5 + carScreenOffsetFor(size)));

  void expectCarClear(WidgetTester tester, Size size) {
    final anchor = carAnchor(size);
    // Kawasan yang diduduki kereta (panjang ~64 px) dan sedikit ruang bernafas.
    final carBox = Rect.fromCenter(center: anchor, width: 56, height: 90);
    for (final entry in hudRects(tester).entries) {
      expect(
        entry.value.overlaps(carBox),
        isFalse,
        reason: '${entry.key} ${entry.value} menutup kereta $carBox',
      );
    }
  }

  testWidgets('potret: kad manuver padat dan kereta tidak tertutup', (
    tester,
  ) async {
    const size = Size(390, 844);
    final container = await pumpNavigating(tester, size);

    expect(find.byType(VehicleOverlay), findsOneWidget);
    final banner = tester.getRect(find.byType(ManeuverBanner));
    expect(banner.height, lessThan(110), reason: 'kad terlalu besar');
    expect(banner.width, lessThanOrEqualTo(440));
    expect(banner.top, lessThan(60));
    expectCarClear(tester, size);
    expect(tester.takeException(), isNull);
    await finish(tester, container);
  });

  testWidgets(
    'mendatar: kad di kiri, butang di kanan, tengah dibiarkan kosong',
    (tester) async {
      const size = Size(844, 390);
      final container = await pumpNavigating(tester, size);

      final banner = tester.getRect(find.byType(ManeuverBanner));
      expect(banner.left, lessThan(40));
      expect(
        banner.width,
        lessThanOrEqualTo(340),
        reason: 'bukan sepanjang skrin',
      );
      expect(banner.height, lessThan(110));

      final panel = tester.getRect(find.byType(NavBottomPanel));
      expect(panel.left, lessThan(100));
      expect(panel.right, lessThan(size.width * 0.55));
      final side = tester.getRect(find.byType(NavSideButtons));
      expect(side.right, greaterThan(size.width - 40));

      expectCarClear(tester, size);
      // Tiada elemen HUD bertindih sesama sendiri.
      final rects = hudRects(tester).values.toList();
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '${rects[i]} bertindih ${rects[j]}',
          );
        }
      }
      expect(tester.takeException(), isNull);
      await finish(tester, container);
    },
  );

  testWidgets(
    'telefon kecil (320x568): tiada limpahan dan kereta tidak tertutup',
    (tester) async {
      const size = Size(320, 568);
      final container = await pumpNavigating(tester, size);

      expect(tester.takeException(), isNull);
      expectCarClear(tester, size);
      expect(
        tester.getRect(find.byType(ManeuverBanner)).width,
        lessThanOrEqualTo(size.width),
      );
      await finish(tester, container);
    },
  );

  testWidgets('teks sistem 2x: kad manuver tidak membesar tanpa had', (
    tester,
  ) async {
    const size = Size(390, 844);
    final container = await pumpNavigating(tester, size, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(ManeuverBanner)).height,
      lessThan(140),
      reason: 'penskalaan teks dihad pada HUD',
    );
    expectCarClear(tester, size);
    await finish(tester, container);
  });

  testWidgets(
    'putar telefon ke mendatar (640x360) semasa navigasi dengan teks besar: tiada limpahan',
    (tester) async {
      // Lembaran laluan (pratonton) tidak muat pada tinggi 360 px; ia bukan sebahagian daripada HUD
      // navigasi, jadi laluan dipilih dalam potret dan telefon diputar selepas navigasi bermula.
      final container = await pumpNavigating(tester, const Size(390, 844));
      const size = Size(640, 360);
      tester.view.physicalSize = size * 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(ManeuverBanner)).left,
        lessThan(40),
        reason: 'susun atur mendatar digunakan selepas putaran',
      );
      expectCarClear(tester, size);
      await finish(tester, container);
    },
  );

  testWidgets('tamat navigasi: kereta 3D dibuang', (tester) async {
    final container = await pumpNavigating(tester, const Size(390, 844));
    expect(find.byType(VehicleOverlay), findsOneWidget);
    await container.read(navigationControllerProvider.notifier).stop();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(VehicleOverlay), findsNothing);
  });

  group('NavHudMetrics', () {
    test('mendatar lebih kecil daripada potret', () {
      final portrait = NavHudMetrics.forSize(const Size(390, 844));
      final landscape = NavHudMetrics.forSize(const Size(844, 390));
      expect(portrait.landscape, isFalse);
      expect(landscape.landscape, isTrue);
      expect(landscape.bannerIcon, lessThan(portrait.bannerIcon));
      expect(landscape.distanceSize, lessThan(portrait.distanceSize));
      expect(landscape.button, lessThanOrEqualTo(portrait.button));
      expect(landscape.bannerMaxWidth, lessThan(portrait.bannerMaxWidth));
    });

    test('telefon sempit mengecilkan ikon dan jarak', () {
      final narrow = NavHudMetrics.forSize(const Size(320, 568));
      final normal = NavHudMetrics.forSize(const Size(390, 844));
      expect(narrow.bannerIcon, lessThan(normal.bannerIcon));
      expect(narrow.distanceSize, lessThan(normal.distanceSize));
    });

    test('butang sentuh tidak terlalu kecil', () {
      for (final size in const [
        Size(390, 844),
        Size(844, 390),
        Size(320, 568),
      ]) {
        expect(NavHudMetrics.forSize(size).button, greaterThanOrEqualTo(40));
      }
    });
  });
}
