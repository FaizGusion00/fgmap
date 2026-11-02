import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:fgmap/app/app.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/features/map/presentation/idle_follow.dart';
import 'package:fgmap/features/navigation/data/trip_record.dart';
import 'package:fgmap/features/navigation/data/trip_store.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/onboarding/presentation/onboarding_page.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/splash/data/splash_controller.dart';
import 'package:fgmap/features/splash/presentation/splash_page.dart';
import 'package:fgmap/features/splash/presentation/splash_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../navigation/nav_test_support.dart';

class _CountingLoader extends MapStyleLoader {
  _CountingLoader() : super(Dio(), null);

  final List<bool> requested = [];

  @override
  Future<ResolvedMapStyle> resolve({required bool dark}) async {
    requested.add(dark);
    return light();
  }
}

/// Animasi splash dimajukan setiap bingkai (bukan jam dinding), jadi ia dimainkan dalam bingkai 16 ms
/// seperti pada telefon.
Future<void> _play(WidgetTester tester, Duration length) async {
  final frames = length.inMilliseconds ~/ 16 + 2;
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
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
      'peringkat berurutan: laluan dilukis, kemudian anak panah, kemudian nama app',
      () {
        const t0 = SplashTimeline(0);
        expect(t0.routeDrawn, 0);
        expect(t0.arm, 0);
        expect(t0.arrowOpacity, 0);
        expect(t0.wordmark, 0);

        const mid = SplashTimeline(0.4);
        expect(mid.routeDrawn, inExclusiveRange(0, 1));
        expect(mid.arm, inExclusiveRange(0, 1));
        expect(mid.arrowOpacity, 0);
        expect(mid.startDot, closeTo(1, 0.15));

        const late = SplashTimeline(0.72);
        expect(late.routeDrawn, 1);
        expect(late.arm, 1);
        expect(late.arrowOpacity, 1);
        expect(late.wordmark, inExclusiveRange(0, 1));

        const end = SplashTimeline(1);
        expect(end.routeDrawn, 1);
        expect(end.arrowIn, closeTo(1, 1e-9));
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
      'laluan bermula di titik mula, naik, membelok ke kanan dan berakhir di pangkal anak panah',
      () {
        final metric = SplashGeometry.route().computeMetrics().first;
        final start = metric.getTangentForOffset(0)!.position;
        final end = metric.getTangentForOffset(metric.length)!;
        expect(start, SplashGeometry.start);
        expect(end.position.dx, closeTo(592, 0.5));
        expect(end.position.dy, closeTo(268, 0.5));
        // Arah akhir: ke kanan (ke arah anak panah).
        expect(end.vector.dx, closeTo(1, 1e-3));
        // Batang 382 + lengkok suku bulatan (r 150) + 70.
        expect(metric.length, closeTo(382 + math.pi * 75 + 70, 1));
      },
    );

    test('anak panah mengelilingi pusatnya dan tanda muat dalam ikon 1024', () {
      final arrow = SplashGeometry.arrow().getBounds();
      expect(arrow.contains(SplashGeometry.arrowCenter), isTrue);
      // Sempadan tanda (termasuk separuh lebar garisan dan titik mula) selepas dipetakan ke ruang ikon.
      final topLeft = SplashGeometry.toIcon(
        Offset(SplashGeometry.start.dx - 104, arrow.top - 18),
      );
      final bottomRight = SplashGeometry.toIcon(
        Offset(arrow.right + 18, SplashGeometry.start.dy + 104),
      );
      for (final v in [
        topLeft.dx,
        topLeft.dy,
        bottomRight.dx,
        bottomRight.dy,
      ]) {
        expect(v, inExclusiveRange(64, 960));
      }
      // Tanda berpusat secara mendatar dan menegak dalam ikon.
      expect((topLeft.dx + bottomRight.dx) / 2, closeTo(512, 1));
      expect((topLeft.dy + bottomRight.dy) / 2, closeTo(512, 1));
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
      await _play(tester, SplashPage.animation);
      await tester.pump(SplashPage.hold + const Duration(milliseconds: 50));
      await _settle(tester);
      expect(find.byType(SplashPage), findsNothing);
      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('pengguna sedia ada: selepas animasi -> peta', (tester) async {
      await prefs.setBool('onboarding.v1', true);
      await pumpFull(tester);
      await _play(tester, SplashPage.animation);
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

    testWidgets(
      'Reduce Motion / penjimat bateri: logo siap pudar masuk, kemudian tamat cepat',
      (tester) async {
        await prefs.setBool('onboarding.v1', true);
        reduceMotion(tester);
        await pumpFull(tester);
        await tester.pump();
        expect(find.byType(SplashPage), findsOneWidget);
        double opacity() => tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byType(SplashPage),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        expect(opacity(), lessThan(0.2), reason: 'bermula pudar');
        await _play(tester, SplashPage.reducedMotionReveal);
        expect(opacity(), 1);
        await tester.pump(
          SplashPage.reducedMotionHold + const Duration(milliseconds: 50),
        );
        await _settle(tester);
        expect(find.byType(SplashPage), findsNothing);
      },
    );

    testWidgets(
      'bingkai pertama yang berat tidak melangkau animasi (telefon sebenar)',
      (tester) async {
        await prefs.setBool('onboarding.v1', true);
        await pumpFull(tester);
        await tester.pump();
        // Bingkai 1.5 s (fon, shader, gaya peta): pengawal berasaskan masa akan tamat di sini.
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 16));
        final painter =
            tester
                    .widget<CustomPaint>(
                      find
                          .descendant(
                            of: find.byType(SplashPage),
                            matching: find.byType(CustomPaint),
                          )
                          .first,
                    )
                    .painter!
                as SplashPainter;
        expect(painter.timeline.t, lessThan(0.1));
        expect(painter.timeline.arrowIn, 0, reason: 'anak panah belum masuk');
        await _play(tester, SplashPage.animation);
        await tester.pump(SplashPage.hold + const Duration(milliseconds: 50));
        await _settle(tester);
        expect(find.byType(SplashPage), findsNothing);
      },
    );

    testWidgets('perjalanan disimpan: splash tetap dimainkan (versi pantas)', (
      tester,
    ) async {
      await prefs.setBool('onboarding.v1', true);
      final option = lShapedRoute(legM: 500);
      await prefs.setString(
        TripStore.key,
        encodeTrip(
          NavigationTrip(
            savedAt: DateTime.now(),
            route: option,
            query: RouteQuery(
              origin: option.points.first,
              destination: option.points.last,
            ),
            alongM: 100,
            language: VoiceLanguage.ms,
            position: option.points[2],
            bearing: 90,
            speedMps: 10,
          ),
        )!,
      );
      await pumpFull(tester);
      await tester.pump();
      // Dahulu splash dilangkau terus bila perjalanan disimpan.
      expect(find.byType(SplashPage), findsOneWidget);
      await _play(tester, SplashPage.quickAnimation);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find
                        .descendant(
                          of: find.byType(SplashPage),
                          matching: find.byType(CustomPaint),
                        )
                        .first,
                  )
                  .painter!
              as SplashPainter;
      expect(painter.timeline.t, 1, reason: 'versi pantas sudah lengkap');
      // Hentikan sebelum peta dibina (pemulihan navigasi diuji dalam trip_restore_test).
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'splash tidak dipaparkan semula selepas selesai (sesi yang sama)',
      (tester) async {
        await prefs.setBool('onboarding.v1', true);
        await pumpFull(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SplashPage)),
        );
        await _play(tester, SplashPage.animation);
        await tester.pump(SplashPage.hold + const Duration(milliseconds: 50));
        await _settle(tester);
        expect(container.read(splashDoneProvider), isTrue);
        expect(find.byType(SplashPage), findsNothing);
      },
    );
  });
}
