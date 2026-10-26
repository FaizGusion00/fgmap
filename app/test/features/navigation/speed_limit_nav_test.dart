import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/navigation/data/navigation_settings.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:fgmap/features/speed_limits/domain/speed_limits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';
import 'navigation_controller_test.dart' show ScriptedSource;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeClock clock;
  late FakeVoice voice;
  late FakeSpeedLimitService limits;
  late ScriptedSource source;
  late ProviderContainer container;
  late RouteOption routeOption;
  late NavRoute navRoute;

  Future<void> setUpContainer({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    clock = FakeClock();
    voice = FakeVoice();
    limits = FakeSpeedLimitService(uniformLimit(50, 4000));
    source = ScriptedSource(clock);
    routeOption = lShapedRoute(legM: 2000);
    navRoute = NavRoute(routeOption);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        voiceGuideProvider.overrideWithValue(voice),
        screenAwakeProvider.overrideWithValue(FakeAwake()),
        navClockProvider.overrideWithValue(clock.call),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => [routeOption]),
        ),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        speedLimitServiceProvider.overrideWithValue(limits),
      ],
    );
    addTearDown(container.dispose);
    container.listen(navigationControllerProvider, (_, _) {});
    await container
        .read(navigationControllerProvider.notifier)
        .start(
          routeOption,
          RouteQuery(
            origin: navRoute.points.first,
            destination: navRoute.points.last,
          ),
          uiLanguage: VoiceLanguage.ms,
          source: source,
        );
    await pumpEventQueue();
  }

  NavigationState state() => container.read(navigationControllerProvider);
  int warnings() =>
      voice.said.where((s) => s.$1.kind == AnnouncementKind.speeding).length;

  group('had laju dalam navigasi', () {
    test(
      'dimuat sekali semasa mula dan dipaparkan mengikut kedudukan',
      () async {
        await setUpContainer();
        expect(limits.calls, 1);
        expect(state().speedLimits.isEmpty, isFalse);
        await source.emitAll(driveFixes(navRoute, speedMps: 10, endM: 200));
        expect(state().currentLimitKmh, 50);
        expect(state().overspeed, isFalse);
      },
    );

    test(
      'melebihi had + toleransi: bendera dan bunyi amaran sekali sahaja',
      () async {
        await setUpContainer();
        // 18 m/s = 65 km/j, had 50 + toleransi lalai 5 = 55.
        await source.emitAll(driveFixes(navRoute, speedMps: 18, endM: 600));
        expect(state().overspeed, isTrue);
        expect(warnings(), 1);
        expect(
          voice.said
              .firstWhere((s) => s.$1.kind == AnnouncementKind.speeding)
              .$1
              .chime,
          ChimeKind.warning,
        );
      },
    );

    test(
      'perlahan semula: bendera dibuang; melebihi lagi dalam 20 s tidak berbunyi lagi',
      () async {
        await setUpContainer();
        final base = DateTime.utc(2026, 1, 1, 12);
        Future<void> at(int sec, double speed, double along) => source.emit(
          LocationFix(
            point: navRoute.pointAt(along),
            headingDegrees: 90,
            accuracyMeters: 5,
            speedMps: speed,
            timestamp: base.add(Duration(seconds: sec)),
          ),
        );
        await at(0, 18, 100);
        await at(1, 18, 118);
        expect(state().overspeed, isTrue);
        await at(2, 10, 128);
        await at(3, 10, 138);
        expect(state().overspeed, isFalse);
        await at(4, 18, 156);
        await at(5, 18, 174);
        expect(state().overspeed, isTrue);
        expect(warnings(), 1, reason: 'cooldown 20 s');
        await at(30, 10, 300);
        await at(31, 18, 318);
        await at(32, 18, 336);
        expect(warnings(), 2, reason: 'selepas cooldown');
      },
    );

    test('dalam toleransi: tiada amaran', () async {
      await setUpContainer();
      // 15 m/s = 54 km/j <= 55.
      await source.emitAll(driveFixes(navRoute, speedMps: 15, endM: 400));
      expect(state().overspeed, isFalse);
      expect(warnings(), 0);
    });

    test('amaran dimatikan (toleransi -1)', () async {
      await setUpContainer(prefs: {'nav.overspeedTolerance': -1});
      await source.emitAll(driveFixes(navRoute, speedMps: 25, endM: 600));
      expect(state().overspeed, isFalse);
      expect(warnings(), 0);
    });

    test('tiada data had: tidak pernah menuduh melebihi', () async {
      await setUpContainer();
      limits.limits = SpeedLimits.empty;
      // Muat semula melalui sesi baharu.
      await container.read(navigationControllerProvider.notifier).stop();
      source = ScriptedSource(clock);
      await container
          .read(navigationControllerProvider.notifier)
          .start(
            routeOption,
            RouteQuery(
              origin: navRoute.points.first,
              destination: navRoute.points.last,
            ),
            uiLanguage: VoiceLanguage.ms,
            source: source,
          );
      await pumpEventQueue();
      await source.emitAll(driveFixes(navRoute, speedMps: 30, endM: 600));
      expect(state().currentLimitKmh, isNull);
      expect(state().overspeed, isFalse);
    });

    test('tetapan toleransi disimpan', () async {
      await setUpContainer();
      await container
          .read(navigationSettingsProvider.notifier)
          .setOverspeedTolerance(10);
      expect(
        container.read(navigationSettingsProvider).overspeedToleranceKmh,
        10,
      );
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getInt('nav.overspeedTolerance'), 10);
    });
  });

  group('SpeedBubble', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      usePhoneSurface(tester);
      reduceMotion(tester);
      await pumpApp(tester, Scaffold(body: Center(child: child)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('tanda had dipaparkan hanya bila had diketahui', (
      tester,
    ) async {
      await pump(tester, const SpeedBubble(speedMps: 13.9, limitKmh: 60));
      expect(find.byKey(const ValueKey('speed-limit-sign')), findsOneWidget);
      expect(find.text('60'), findsOneWidget); // tanda had
      expect(find.text('50'), findsOneWidget); // kelajuan 13.9 m/s
    });

    testWidgets('tanpa had: hanya bulatan kelajuan', (tester) async {
      await pump(tester, const SpeedBubble(speedMps: 13.9));
      expect(find.byKey(const ValueKey('speed-limit-sign')), findsNothing);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('melebihi had: bulatan kelajuan berwarna ralat', (
      tester,
    ) async {
      await pump(
        tester,
        const SpeedBubble(speedMps: 20, limitKmh: 60, overspeed: true),
      );
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppThemeError.color(tester));
    });
  });
}

class AppThemeError {
  static Color color(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SpeedBubble))).colorScheme.error;
}
