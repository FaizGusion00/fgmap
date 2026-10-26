import 'package:dio/dio.dart';
import 'package:fgmap/app/app.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/settings/app_preferences.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/haptics.dart';
import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/idle_follow.dart';
import 'package:fgmap/features/splash/data/splash_controller.dart';
import 'package:fgmap/features/map/presentation/map_screen.dart';
import 'package:fgmap/features/navigation/data/navigation_settings.dart';
import 'package:fgmap/features/onboarding/data/onboarding_controller.dart';
import 'package:fgmap/features/reports/domain/report.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:fgmap/features/saved_places/data/saved_places_controller.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/search_history_controller.dart';
import 'package:fgmap/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _lotus = Place(
  name: 'Lotus',
  subtitle: 'Puncak Alam',
  point: GeoPoint(3.2262, 101.4278),
);

void main() {
  late SharedPreferences prefs;
  late FakeLocationService location;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    location = FakeLocationService(
      accessValue: LocationAccess.granted,
      fix: const LocationFix(point: klcc),
    );
    Haptics.enabled = true;
  });

  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 1600),
  }) async {
    usePhoneSurface(tester, size: size);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const SettingsPage(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
  }

  group('AppPreferences', () {
    test('lalai, bacaan, dan nilai luar julat kembali ke lalai', () async {
      expect(readAppPreferences(prefs), const AppPreferences());
      await prefs.setDouble('app.textScale', 3.0);
      await prefs.setString('app.language', 'fr');
      final read = readAppPreferences(prefs);
      expect(read.textScale, 1.0);
      expect(read.languageCode, isNull);
      expect(read.locale, isNull);
      await prefs.setString('app.language', 'en');
      expect(readAppPreferences(prefs).locale, const Locale('en'));
    });
  });

  testWidgets('semua kumpulan dipaparkan', (tester) async {
    // Permukaan sangat tinggi supaya ListView membina setiap kumpulan.
    await pumpPage(tester, size: const Size(390, 5000));
    for (final t in [
      'Paparan',
      'Navigasi',
      'Laporan',
      'Peta',
      'Privasi',
      'Bantuan & tentang',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
  });

  testWidgets(
    'paparan: saiz teks, kurangkan animasi, getaran, bahasa disimpan',
    (tester) async {
      final c = await pumpPage(tester);

      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();
      expect(c.read(appPreferencesProvider).textScale, 1.15);
      expect(prefs.getDouble('app.textScale'), 1.15);

      await tester.tap(find.byKey(const ValueKey('reduce-motion-switch')));
      await tester.pumpAndSettle();
      expect(prefs.getBool('app.reduceMotion'), isTrue);

      await tester.tap(find.byKey(const ValueKey('haptics-switch')));
      await tester.pumpAndSettle();
      expect(prefs.getBool('app.haptics'), isFalse);
      expect(
        Haptics.enabled,
        isFalse,
        reason: 'getaran dimatikan di seluruh app',
      );

      final language = find.byKey(const ValueKey('app-language'));
      await tester.scrollUntilVisible(
        language,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(of: language, matching: find.text('English')),
      );
      await tester.pumpAndSettle();
      expect(prefs.getString('app.language'), 'en');
      await tester.tap(
        find.descendant(of: language, matching: find.text('Peranti')),
      );
      await tester.pumpAndSettle();
      expect(prefs.getString('app.language'), isNull);
    },
  );

  testWidgets('navigasi dan laporan: kelantangan, kelajuan, amaran laporan', (
    tester,
  ) async {
    final c = await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('speech-rate')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Perlahan').last);
    await tester.pumpAndSettle();
    expect(c.read(navigationSettingsProvider).speechRate, 0.42);
    expect(prefs.getDouble('nav.speechRate'), 0.42);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('voice-volume')),
        matching: find.text('Sederhana'),
      ),
    );
    await tester.pumpAndSettle();
    expect(c.read(navigationSettingsProvider).voiceVolume, 0.75);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-alerts-switch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('report-alerts-switch')));
    await tester.pumpAndSettle();
    expect(c.read(navigationSettingsProvider).reportAlerts, isFalse);
  });

  group('privasi: padam data', () {
    Future<void> openTile(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('sejarah carian: perlu pengesahan; batal tidak memadam', (
      tester,
    ) async {
      final c = await pumpPage(tester);
      await c.read(searchHistoryControllerProvider.notifier).record(_lotus);

      await openTile(tester, 'clear-history');
      expect(find.text('Padam data ini?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(c.read(searchHistoryControllerProvider), isNotEmpty);

      await openTile(tester, 'clear-history');
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      expect(c.read(searchHistoryControllerProvider), isEmpty);
      expect(find.text('Dipadam'), findsOneWidget);
    });

    testWidgets('tempat disimpan dan laporan dipadam', (tester) async {
      final c = await pumpPage(tester);
      await c.read(savedPlacesControllerProvider.notifier).setHome(_lotus);
      await c
          .read(reportsRepositoryProvider)
          .create(ReportType.police, klcc, DateTime.now());
      await c.read(reportsControllerProvider.notifier).refresh();
      expect(c.read(reportsControllerProvider), isNotEmpty);

      await openTile(tester, 'clear-saved');
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      expect(c.read(savedPlacesControllerProvider), isEmpty);

      await openTile(tester, 'clear-reports');
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      expect(c.read(reportsControllerProvider), isEmpty);
    });

    testWidgets(
      'status lokasi: dibenarkan; ditolak menunjuk pintasan tetapan telefon',
      (tester) async {
        await pumpPage(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('location-status')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Akses lokasi: dibenarkan'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('location-status')));
        await tester.pump();
        expect(location.openAppSettingsCalls, 1);
      },
    );
  });

  testWidgets(
    'bantuan: sambutan semula menetapkan semula bendera; lesen dibuka',
    (tester) async {
      await prefs.setBool('onboarding.v1', true);
      final c = await pumpPage(tester);
      expect(c.read(onboardingDoneProvider), isTrue);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('licences')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('licences')));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
      Navigator.of(tester.element(find.byType(LicensePage))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('welcome-again')));
      await tester.pumpAndSettle();
      expect(c.read(onboardingDoneProvider), isFalse);
      expect(prefs.getBool('onboarding.v1'), isNull);
    },
  );

  group('berkuat kuasa pada seluruh app', () {
    Future<void> pumpFull(WidgetTester tester) async {
      final map = FakeMapHarness();
      usePhoneSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            map.override,
            splashDoneProvider.overrideWith(SplashAlreadyDone.new),
            sharedPreferencesProvider.overrideWithValue(prefs),
            locationServiceProvider.overrideWithValue(location),
            idleRecenterAfterProvider.overrideWithValue(
              const Duration(hours: 1),
            ),
            mapStyleLoaderProvider.overrideWithValue(_UrlLoader()),
          ],
          child: const FgmapApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('bahasa pilihan mengatasi bahasa peranti', (tester) async {
      await prefs.setBool('onboarding.v1', true);
      await prefs.setString('app.language', 'en');
      await pumpFull(tester);
      expect(find.text('Search destination'), findsOneWidget);
    });

    testWidgets('saiz teks dan kurangkan animasi dikenakan pada MediaQuery', (
      tester,
    ) async {
      await prefs.setBool('onboarding.v1', true);
      await prefs.setDouble('app.textScale', 1.3);
      await prefs.setBool('app.reduceMotion', true);
      await pumpFull(tester);
      final media = MediaQuery.of(tester.element(find.byType(MapScreen)));
      expect(media.textScaler.scale(10), closeTo(13, 0.01));
      expect(media.disableAnimations, isTrue);
    });
  });
}

class _UrlLoader extends MapStyleLoader {
  _UrlLoader() : super(Dio(), null);

  @override
  Future<ResolvedMapStyle> resolve({required bool dark}) async => light();
}
