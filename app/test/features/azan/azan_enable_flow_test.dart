import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/platform/system_settings.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/azan/data/azan_player.dart';
import 'package:fgmap/features/azan/data/azan_scheduler.dart';
import 'package:fgmap/features/azan/data/azan_settings.dart';
import 'package:fgmap/features/azan/data/official_prayer_times.dart';
import 'package:fgmap/features/azan/data/adhan_prayer_calculator.dart';
import 'package:fgmap/features/azan/presentation/azan_controller.dart';
import 'package:fgmap/features/azan/presentation/azan_settings_section.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../navigation/nav_test_support.dart';
import 'azan_test_support.dart';

class _FakeSystemSettings implements SystemSettings {
  int notificationCalls = 0;
  int batteryCalls = 0;
  bool ignoringBattery = true;

  @override
  Future<bool> openNotificationSettings() async {
    notificationCalls++;
    return true;
  }

  @override
  Future<bool> openBatterySettings() async {
    batteryCalls++;
    return true;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => ignoringBattery;
}

void main() {
  late SharedPreferences prefs;
  late FakeAzanScheduler scheduler;
  late _FakeSystemSettings system;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    scheduler = FakeAzanScheduler();
    system = _FakeSystemSettings();
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: AzanSettingsSection())),
      locale: const Locale('ms'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        azanSchedulerProvider.overrideWithValue(scheduler),
        azanPlayerProvider.overrideWithValue(FakeAzanPlayer()),
        prayerCalculatorProvider.overrideWithValue(FakePrayerCalculator()),
        officialTimesClientProvider.overrideWithValue(FakeOfficialClient()),
        systemSettingsProvider.overrideWithValue(system),
        azanClockProvider.overrideWithValue(() => DateTime(2026, 10, 31, 14)),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => []),
        ),
        voiceGuideProvider.overrideWithValue(FakeVoice()),
      ],
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(AzanSettingsSection)),
    );
  }

  Future<void> tapSwitch(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('azan-enable')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'kebenaran ditolak: dialog jelas dengan butang ke tetapan notifikasi',
    (tester) async {
      scheduler.permissionGranted = false;
      final c = await pump(tester);
      await tapSwitch(tester);
      expect(find.byKey(const ValueKey('azan-dialog')), findsOneWidget);
      expect(find.text('Notifikasi dimatikan'), findsWidgets);
      expect(c.read(azanSettingsProvider).enabled, isFalse);
      await tester.tap(find.byKey(const ValueKey('azan-dialog-action')));
      await tester.pumpAndSettle();
      expect(system.notificationCalls, 1);
      // Kad amaran kekal di bawah suis supaya pengguna tidak buntu.
      expect(
        find.byKey(const ValueKey('azan-permission-denied')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'dibenarkan: suis hidup, jadual dibuat, snackbar menyebut sumber waktu',
    (tester) async {
      final c = await pump(tester);
      await tapSwitch(tester);
      expect(c.read(azanSettingsProvider).enabled, isTrue);
      expect(scheduler.pending, isNotEmpty);
      expect(
        scheduler.lastTexts,
        isNotNull,
        reason: 'teks dipasang sebelum menjadualkan',
      );
      expect(find.byKey(const ValueKey('azan-dialog')), findsNothing);
      expect(find.textContaining('Azan dihidupkan'), findsOneWidget);
      expect(
        find.textContaining('Azan dihidupkan. Dikira pada telefon'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'penggera tepat belum dibenarkan: terangkan dan buka tetapannya',
    (tester) async {
      scheduler.exact = false;
      await pump(tester);
      await tapSwitch(tester);
      expect(find.byKey(const ValueKey('azan-dialog')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('azan-dialog')),
          matching: find.text('Benarkan penggera tepat'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('azan-dialog-action')));
      await tester.pumpAndSettle();
      expect(scheduler.openExactCalls, 1);
    },
  );

  testWidgets('notifikasi ditarik balik kemudian: kad amaran dipaparkan', (
    tester,
  ) async {
    await prefs.setBool('azan.enabled', true);
    scheduler.notifications = false;
    final c = await pump(tester);
    await c.read(azanControllerProvider.notifier).refreshPermissionState();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('azan-permission-denied')),
      findsOneWidget,
    );
    await tester.tap(find.text('Buka tetapan').first);
    expect(system.notificationCalls, 1);
  });

  testWidgets('petua bateri dipaparkan apabila app tidak dikecualikan', (
    tester,
  ) async {
    await prefs.setBool('azan.enabled', true);
    system.ignoringBattery = false;
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('azan-battery-card')), findsOneWidget);
    await tester.tap(find.text('Buka tetapan bateri'));
    expect(system.batteryCalls, 1);
  });

  testWidgets('lokasi belum diketahui: petunjuk jujur dipaparkan', (
    tester,
  ) async {
    await prefs.setBool('azan.enabled', true);
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('azan-location-unknown')), findsOneWidget);
  });

  testWidgets('suis waktu rasmi JAKIM disimpan', (tester) async {
    await prefs.setBool('azan.enabled', true);
    final c = await pump(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('azan-official')));
    await tester.tap(find.byKey(const ValueKey('azan-official')));
    await tester.pumpAndSettle();
    expect(c.read(azanSettingsProvider).useOfficial, isFalse);
    expect(prefs.getBool('azan.official'), isFalse);
  });
}
