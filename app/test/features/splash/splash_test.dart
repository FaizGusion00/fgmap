import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:fgmap/app/app.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/features/map/presentation/idle_follow.dart';
import 'package:fgmap/features/onboarding/presentation/onboarding_page.dart';
import 'package:fgmap/features/splash/data/splash_controller.dart';
import 'package:fgmap/features/splash/presentation/splash_page.dart';
import 'package:fgmap/features/splash/presentation/splash_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

class _CountingLoader extends MapStyleLoader {
  _CountingLoader() : super(Dio(), null);

  final List<bool> requested = [];

  @override
  Future<ResolvedMapStyle> resolve({required bool dark}) async {
    requested.add(dark);
    return light();
  }
}

/// Peralihan halaman berjalan dalam beberapa bingkai selepas redirect; maju dengan langkah kecil.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('SplashTimeline', () {
    test(
      'peringkat berurutan: laluan dilukis, kemudian penanda, kemudian nama app',
      () {
        const t0 = SplashTimeline(0);
        expect(t0.routeDrawn, 0);
        expect(t0.pinOpacity, 0);
        expect(t0.wordmark, 0);

        const mid = SplashTimeline(0.4);
        expect(mid.routeDrawn, inExclusiveRange(0, 1));
        expect(mid.pinOpacity, 0);
        expect(mid.startDot, closeTo(1, 0.15));

        const late = SplashTimeline(0.72);
        expect(late.routeDrawn, 1);
        expect(late.pinOpacity, 1);
        expect(late.wordmark, inExclusiveRange(0, 1));

        const end = SplashTimeline(1);
        expect(end.routeDrawn, 1);
        expect(end.pinDrop, closeTo(1, 1e-9));
        expect(end.wordmark, 1);
        expect(end.tagline, 1);
        expect(end.ripple, 1);
      },
    );

    test('laluan dilukis menaik tanpa berundur', () {
      var prev = 0.0;
      for (var i = 0; i <= 100; i++) {
        final v = SplashTimeline(i / 100).routeDrawn;
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });
  });

  group('SplashGeometry', () {
    test(
      'laluan bermula di titik mula dan berakhir di destinasi (ruang ikon 1024)',
      () {
        final metric = SplashGeometry.route().computeMetrics().first;
        final start = metric.getTangentForOffset(0)!.position;
        final end = metric.getTangentForOffset(metric.length)!.position;
        expect(start, SplashGeometry.start);
        expect(end.dx, closeTo(756, 0.5));
        expect(end.dy, closeTo(272, 0.5));
        expect(metric.length, greaterThan(900));
      },
    );

    test('penanda mengelilingi pusatnya dan berada dalam kanvas', () {
      final bounds = SplashGeometry.pin().getBounds();
      expect(bounds.contains(SplashGeometry.pinCenter), isTrue);
      expect(bounds.left, greaterThan(0));
      expect(bounds.right, lessThan(1024));
      expect(bounds.bottom, lessThan(1024));
    });
  });

  testWidgets('painter dirender pada setiap peringkat tanpa ralat', (
    tester,
  ) async {
    for (final t in [0.0, 0.1, 0.3, 0.6, 0.75, 0.9, 1.0]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      SplashPainter(
        timeline: SplashTimeline(t),
        artRect: const Rect.fromLTWH(40, 100, 320, 320),
      ).paint(canvas, const Size(400, 800));
      recorder.endRecording().dispose();
    }
  });

  group('aliran splash dalam app', () {
    late SharedPreferences prefs;
    late _CountingLoader loader;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      loader = _CountingLoader();
    });

    Future<void> pumpFull(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            FakeMapHarness().override,
            sharedPreferencesProvider.overrideWithValue(prefs),
            locationServiceProvider.overrideWithValue(
              FakeLocationService(fix: const LocationFix(point: klcc)),
            ),
            idleRecenterAfterProvider.overrideWithValue(
              const Duration(hours: 1),
            ),
            mapStyleLoaderProvider.overrideWithValue(loader),
          ],
          child: const FgmapApp(),
        ),
      );
    }

    testWidgets('app bermula dengan splash dan memuatkan gaya peta di latar', (
      tester,
    ) async {
      await pumpFull(tester);
      await tester.pump();
      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.text('FGMaps'), findsOneWidget);
      expect(loader.requested, isNotEmpty, reason: 'gaya dimuat semasa splash');
      // Bukan peta atau sambutan lagi.
      expect(find.byType(OnboardingPage), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('pengguna baharu: selepas animasi -> sambutan', (tester) async {
      await pumpFull(tester);
      await tester.pump(SplashPage.animation);
      await tester.pump(SplashPage.hold + const Duration(milliseconds: 50));
      await _settle(tester);
      expect(find.byType(SplashPage), findsNothing);
      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('pengguna sedia ada: selepas animasi -> peta', (tester) async {
      await prefs.setBool('onboarding.v1', true);
      await pumpFull(tester);
      await tester.pump(SplashPage.animation);
      await tester.pump(SplashPage.hold + const Duration(milliseconds: 50));
      await _settle(tester);
      expect(find.byType(SplashPage), findsNothing);
      expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
    });

    testWidgets('ketuk melangkau animasi dengan segera', (tester) async {
      await prefs.setBool('onboarding.v1', true);
      await pumpFull(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('splash')));
      await tester.pump(const Duration(milliseconds: 200));
      await _settle(tester);
      expect(find.byType(SplashPage), findsNothing);
      expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
    });

    testWidgets('Reduce Motion: logo statik sebentar, tiada animasi panjang', (
      tester,
    ) async {
      await prefs.setBool('onboarding.v1', true);
      reduceMotion(tester);
      await pumpFull(tester);
      await tester.pump();
      expect(find.byType(SplashPage), findsOneWidget);
      await tester.pump(
        SplashPage.reducedMotionHold + const Duration(milliseconds: 50),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SplashPage), findsNothing);
    });

    testWidgets(
      'splash tidak dipaparkan semula selepas selesai (sesi yang sama)',
      (tester) async {
        await prefs.setBool('onboarding.v1', true);
        await pumpFull(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SplashPage)),
        );
        await tester.pump(SplashPage.animation);
        await tester.pump(SplashPage.hold + const Duration(milliseconds: 50));
        await _settle(tester);
        expect(container.read(splashDoneProvider), isTrue);
        expect(find.byType(SplashPage), findsNothing);
      },
    );
  });
}
