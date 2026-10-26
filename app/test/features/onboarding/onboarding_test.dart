import 'package:fgmap/app/app.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/map/presentation/idle_follow.dart';
import 'package:fgmap/features/splash/data/splash_controller.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/onboarding/data/onboarding_controller.dart';
import 'package:fgmap/features/onboarding/presentation/onboarding_page.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/navigation/data/navigation_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/legal_override.dart';
import '../../helpers/pump_app.dart';

void main() {
  late SharedPreferences prefs;
  late FakeLocationService location;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    location = FakeLocationService(
      accessValue: LocationAccess.askable,
      fix: const LocationFix(point: klcc),
    );
  });

  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    Size size = phoneSize,
    Locale locale = const Locale('ms'),
  }) async {
    usePhoneSurface(tester, size: size);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const OnboardingPage(),
      locale: locale,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(location),
        legalTextOverride(),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(OnboardingPage)),
    );
  }

  testWidgets(
    'tiga halaman: sambutan, privasi (jujur tentang pelayan), persediaan',
    (tester) async {
      await pumpPage(tester);
      expect(find.text('Navigasi untuk Malaysia'), findsOneWidget);
      expect(find.text('Seterusnya'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Privasi anda'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      expect(find.textContaining('Tiada akaun'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Sediakan dalam 10 saat'), findsOneWidget);
      expect(find.text('Mula'), findsOneWidget);
    },
  );

  testWidgets('langkau menandakan selesai', (tester) async {
    final container = await pumpPage(tester);
    expect(container.read(onboardingDoneProvider), isFalse);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(container.read(onboardingDoneProvider), isTrue);
    expect(prefs.getBool('onboarding.v1'), isTrue);
  });

  testWidgets(
    'persediaan: kenderaan, bahasa suara dan kebenaran lokasi disimpan',
    (tester) async {
      final container = await pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Motosikal'));
      await tester.pumpAndSettle();
      expect(container.read(routeVehicleProvider), RouteVehicle.motorcycle);
      expect(prefs.getString('route.vehicle'), 'motorcycle');

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(
        container.read(navigationSettingsProvider).voiceLanguage,
        VoiceLanguage.en,
      );

      // Kebenaran: penjelasan kita dahulu, kemudian dialog sistem (tiada dialog tanpa "Benarkan").
      await tester.tap(find.byKey(const ValueKey('onboarding-location')));
      await tester.pumpAndSettle();
      expect(location.requestCalls, 0);
      await tester.tap(find.text('Benarkan'));
      await tester.pumpAndSettle();
      expect(location.requestCalls, 1);
      expect(find.text('Lokasi dibenarkan'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      expect(container.read(onboardingDoneProvider), isTrue);
    },
  );

  testWidgets('tiada limpahan pada teks sistem 2x dan skrin mendatar kecil', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPage(tester, size: const Size(844, 390));
    for (var i = 0; i < 3; i++) {
      expect(tester.takeException(), isNull, reason: 'halaman $i');
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('English', (tester) async {
    await pumpPage(tester, locale: const Locale('en'));
    expect(find.text('Navigation for Malaysia'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  group('gate router', () {
    Future<void> pumpApp0(WidgetTester tester) async {
      final map = FakeMapHarness();
      usePhoneSurface(tester);
      reduceMotion(tester);
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
          ],
          child: const FgmapApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'kali pertama: sambutan; selepas selesai: peta; berikutnya terus peta',
      (tester) async {
        await pumpApp0(tester);
        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.byKey(const ValueKey('fake-map')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
      },
    );

    testWidgets('sudah selesai: terus ke peta', (tester) async {
      await prefs.setBool('onboarding.v1', true);
      await pumpApp0(tester);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
    });
  });

  testWidgets(
    'halaman privasi: persetujuan dengan pautan ke Terma dan Dasar Privasi',
    (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal-consent')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('onb-privacy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb-privacy')));
      await tester.pumpAndSettle();
      expect(find.text('Dasar Privasi'), findsWidgets);
      expect(find.byKey(const ValueKey('legal-scroll')), findsOneWidget);
    },
  );
}
