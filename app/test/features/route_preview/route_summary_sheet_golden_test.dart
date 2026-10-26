@Tags(['golden'])
library;

import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/route_preview/presentation/route_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// Golden dijana pada macOS. Teks dirender sedikit berbeza antara platform, jadi CI menjalankan
/// tag `golden` pada macOS sahaja (lihat .github/workflows/app.yml).
void main() {
  setUpAll(loadAppFonts);

  const query = RouteQuery(origin: klcc, destination: klia);
  final ready = RouteReady(
    query: query,
    options: [
      sampleOption(),
      sampleOption(durationS: 3722, distanceM: 72447),
      sampleOption(durationS: 12840, distanceM: 359300, hasTolls: false),
    ],
  );
  const readyWithLocationUnavailable = RouteLocationUnavailable(
    destination: klia,
    destinationLabel: 'KLIA',
  );
  final readyLocation = RouteReady(
    query: const RouteQuery(origin: klcc, destination: klia, avoidTolls: true),
    options: [sampleOption(durationS: 3840, distanceM: 69200, hasTolls: false)],
  );
  final readyOffline = RouteReady(
    query: query,
    options: [
      sampleOption(source: RouteSource.offline),
      sampleOption(
        durationS: 3900,
        distanceM: 72000,
        source: RouteSource.offline,
      ),
    ],
  );
  const loading = RouteLoading(destination: klia, query: query);
  const offlineRequired = RouteFailed(
    query: query,
    kind: RoutingFailureKind.offlineRequired,
  );
  const noRoute = RouteFailed(query: query, kind: RoutingFailureKind.noRoute);
  const unavailable = RouteFailed(
    query: query,
    kind: RoutingFailureKind.unavailable,
  );

  Widget board(List<RoutePreviewState> states, Color background) {
    return ColoredBox(
      color: background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final state in states)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RouteSummarySheet(
                state: state,
                onSelect: (_) {},
                onAvoidTollsChanged: (_) {},
                onRetry: () {},
                onClear: () {},
                onOpenOfflineMaps: () {},
              ),
            ),
        ],
      ),
    );
  }

  final themes = {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
    'amoled': AppTheme.dark(amoled: true),
  };

  for (final entry in themes.entries) {
    testWidgets('lembaran ringkasan laluan (${entry.key}, Bahasa Melayu)', (
      tester,
    ) async {
      usePhoneSurface(tester, size: const Size(390, 1450));
      reduceMotion(tester);
      await withShadows(() async {
        await pumpApp(
          tester,
          SingleChildScrollView(
            child: board([
              ready,
              readyOffline,
              readyWithLocationUnavailable,
              readyLocation,
              loading,
              noRoute,
              offlineRequired,
            ], entry.value.scaffoldBackgroundColor),
          ),
          theme: entry.value,
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(SingleChildScrollView),
          matchesGoldenFile('goldens/route_summary_sheet_${entry.key}.png'),
        );
      });
    });
  }

  testWidgets('lembaran ringkasan laluan (cerah, English)', (tester) async {
    usePhoneSurface(tester, size: const Size(390, 640));
    reduceMotion(tester);
    await withShadows(() async {
      await pumpApp(
        tester,
        SingleChildScrollView(
          child: board([
            readyOffline,
            offlineRequired,
          ], AppTheme.light().scaffoldBackgroundColor),
        ),
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SingleChildScrollView),
        matchesGoldenFile('goldens/route_summary_sheet_light_en.png'),
      );
    });
  });

  testWidgets('teks sistem 2x tidak melimpah pada telefon 360 dp', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(360, 2400));
    reduceMotion(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(
      tester,
      SingleChildScrollView(
        child: board([
          ready,
          readyOffline,
          readyWithLocationUnavailable,
          loading,
          noRoute,
          unavailable,
          offlineRequired,
        ], Colors.white),
      ),
    );
    await tester.pumpAndSettle();

    // Pengecualian "RenderFlex overflowed" akan menggagalkan ujian ini.
    expect(tester.takeException(), isNull);
  });
}
