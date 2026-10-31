import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/azan/data/adhan_prayer_calculator.dart';
import 'package:fgmap/features/azan/data/azan_player.dart';
import 'package:fgmap/features/azan/data/azan_scheduler.dart';
import 'package:fgmap/features/azan/data/azan_settings.dart';
import 'package:fgmap/features/azan/data/official_prayer_times.dart';
import 'package:fgmap/features/azan/domain/prayer.dart';
import 'package:fgmap/features/azan/presentation/azan_controller.dart';
import 'package:fgmap/features/azan/presentation/azan_now_banner.dart';
import 'package:fgmap/features/azan/presentation/azan_settings_section.dart';
import 'package:fgmap/features/azan/presentation/azan_sheet.dart';
import 'package:fgmap/features/azan/presentation/azan_today_pill.dart';
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

void main() {
  late SharedPreferences prefs;
  late FakeAzanScheduler scheduler;
  late FakeAzanPlayer player;
  DateTime now = DateTime(2026, 10, 31, 14, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    scheduler = FakeAzanScheduler();
    player = FakeAzanPlayer();
    now = DateTime(2026, 10, 31, 14, 0);
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('ms'),
  }) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      Scaffold(body: SingleChildScrollView(child: child)),
      locale: locale,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        azanSchedulerProvider.overrideWithValue(scheduler),
        azanPlayerProvider.overrideWithValue(player),
        prayerCalculatorProvider.overrideWithValue(FakePrayerCalculator()),
        officialTimesClientProvider.overrideWithValue(FakeOfficialClient()),
        azanClockProvider.overrideWithValue(() => now),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => []),
        ),
        voiceGuideProvider.overrideWithValue(FakeVoice()),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  group('AzanSheet', () {
    testWidgets(
      'enam baris, seterusnya ditonjolkan, nota anggaran, lalai azan penuh',
      (tester) async {
        await pump(tester, const SizedBox(height: 1400, child: AzanSheet()));
        for (final p in Prayer.values) {
          expect(find.byKey(ValueKey('azan-row-${p.name}')), findsOneWidget);
        }
        expect(find.text('Subuh'), findsWidgets);
        expect(find.text('Asar'), findsWidgets);
        expect(find.byKey(const ValueKey('azan-next-line')), findsOneWidget);
        expect(find.textContaining('Seterusnya: Asar'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('azan-estimate-note')),
          findsOneWidget,
        );
        expect(find.textContaining('JAKIM'), findsWidgets);
        expect(find.byKey(const ValueKey('azan-enable')), findsOneWidget);
        // Mati: pilihan lanjut tersembunyi.
        expect(find.byKey(const ValueKey('azan-sound')), findsNothing);
      },
    );

    testWidgets('English', (tester) async {
      await pump(
        tester,
        const SizedBox(height: 1400, child: AzanSheet()),
        locale: const Locale('en'),
      );
      expect(find.text('Prayer times'), findsOneWidget);
      expect(find.text('Fajr'), findsWidgets);
      expect(find.textContaining('Next: Asr'), findsOneWidget);
    });
  });

  group('AzanSettingsSection', () {
    testWidgets(
      'suis hidup -> kebenaran diminta, jadual dibuat, pilihan muncul',
      (tester) async {
        final c = await pump(tester, const AzanSettingsSection());
        c.read(azanControllerProvider.notifier).setTexts(testTexts());
        await tester.tap(find.byKey(const ValueKey('azan-enable')));
        await tester.pumpAndSettle();
        expect(scheduler.permissionRequests, 1);
        expect(c.read(azanSettingsProvider).enabled, isTrue);
        expect(scheduler.pending, isNotEmpty);
        // Lalai bunyi: azan penuh dipilih.
        final seg = tester.widget<SegmentedButton<AzanSound>>(
          find.byKey(const ValueKey('azan-sound')),
        );
        expect(seg.selected, {AzanSound.full});
        expect(find.text('Azan penuh'), findsOneWidget);
        // Lima cip waktu dengan ikon + teks.
        for (final p in Prayer.fardu) {
          expect(find.byKey(ValueKey('azan-prayer-${p.name}')), findsOneWidget);
        }
      },
    );

    testWidgets('pilihan disimpan: bunyi, peringatan, waktu, semasa navigasi', (
      tester,
    ) async {
      await prefs.setBool('azan.enabled', true);
      final c = await pump(tester, const AzanSettingsSection());
      await tester.tap(find.text('Nada pendek'));
      await tester.pumpAndSettle();
      expect(c.read(azanSettingsProvider).sound, AzanSound.short);
      await tester.tap(find.text('10 min sebelum'));
      await tester.pumpAndSettle();
      expect(c.read(azanSettingsProvider).reminderMinutes, 10);
      await tester.tap(find.byKey(const ValueKey('azan-prayer-fajr')));
      await tester.pumpAndSettle();
      expect(
        c.read(azanSettingsProvider).prayers,
        isNot(contains(Prayer.fajr)),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('azan-during-nav')));
      await tester.tap(find.byKey(const ValueKey('azan-during-nav')));
      await tester.pumpAndSettle();
      expect(c.read(azanSettingsProvider).playDuringNavigation, isTrue);
    });

    testWidgets('kad penggera tepat muncul jika tidak dibenarkan', (
      tester,
    ) async {
      await prefs.setBool('azan.enabled', true);
      scheduler.exact = false;
      final c = await pump(tester, const AzanSettingsSection());
      await c.read(azanControllerProvider.notifier).refreshPermissionState();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('azan-exact-card')), findsOneWidget);
      await tester.tap(find.text('Buka tetapan'));
      expect(scheduler.openExactCalls, 1);
    });

    testWidgets(
      'Dengar azan memainkan azan penuh dan bertukar kepada Berhenti',
      (tester) async {
        await prefs.setBool('azan.enabled', true);
        await pump(tester, const AzanSettingsSection());
        await tester.tap(find.byKey(const ValueKey('azan-listen')));
        await tester.pumpAndSettle();
        expect(player.played, [AzanSound.full]);
        expect(find.text('Berhenti'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('azan-listen')));
        await tester.pumpAndSettle();
        expect(player.stops, 1);
      },
    );
  });

  group('AzanTodayPill dan sepanduk', () {
    testWidgets('pil: waktu seterusnya dan baki; ketik membuka lembaran', (
      tester,
    ) async {
      await pump(tester, const AzanTodayPill());
      expect(find.textContaining('Asar'), findsOneWidget);
      expect(find.textContaining('2 j 25 min'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('azan-pill')));
      await tester.pumpAndSettle();
      expect(find.byType(AzanSheet), findsOneWidget);
    });

    testWidgets(
      'selepas Isyak pil menunjukkan Subuh esok, bukan label kosong',
      (tester) async {
        now = DateTime(2026, 10, 31, 22, 0);
        await pump(tester, const AzanTodayPill());
        expect(find.text('Waktu solat'), findsNothing);
        // Subuh 05:50 esok, tinggal 7 j 50 min.
        expect(find.textContaining('Subuh'), findsOneWidget);
        expect(find.textContaining('7 j 50 min'), findsOneWidget);
      },
    );

    testWidgets('sepanduk: Berhenti menghentikan azan', (tester) async {
      final c = await pump(tester, const AzanNowBanner(prayer: Prayer.dhuhr));
      expect(find.text('Waktu Zohor'), findsOneWidget);
      await c.read(azanControllerProvider.notifier).preview();
      await tester.tap(find.byKey(const ValueKey('azan-stop')));
      await tester.pumpAndSettle();
      expect(player.stops, 1);
    });

    testWidgets('cip navigasi dipaparkan dengan nama waktu', (tester) async {
      await pump(tester, const AzanNavChip(prayer: Prayer.maghrib));
      expect(find.text('Waktu Maghrib'), findsOneWidget);
      expect(find.byKey(const ValueKey('azan-nav-chip')), findsOneWidget);
    });
  });
}
