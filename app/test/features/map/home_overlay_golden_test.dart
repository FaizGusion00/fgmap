@Tags(['golden'])
library;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/settings/easy_mode_scope.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/adhan_prayer_calculator.dart';
import 'package:fgmap/features/azan/data/azan_player.dart';
import 'package:fgmap/features/azan/data/azan_scheduler.dart';
import 'package:fgmap/features/azan/data/official_prayer_times.dart';
import 'package:fgmap/features/azan/presentation/azan_controller.dart';
import 'package:fgmap/features/azan/presentation/azan_today_pill.dart';
import 'package:fgmap/features/map/presentation/map_tool_rail.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/saved_places/data/saved_places_controller.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/recent_places_bar.dart';
import 'package:fgmap/features/search/presentation/search_history_controller.dart';
import 'package:fgmap/features/search/presentation/search_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../azan/azan_test_support.dart';
import '../navigation/nav_test_support.dart';

/// Rupa lapisan atas skrin utama (carian, pintasan, waktu solat + alat) di atas latar peta ringkas,
/// pada 390 dan 360 dp, terang dan gelap, dan satu bingkai di tengah pancaran gelombang carian.
void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(
    WidgetTester tester, {
    required String name,
    required double width,
    bool dark = false,
    bool easy = false,
    bool motion = false,
    String locale = 'ms',
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    usePhoneSurface(tester, size: Size(width, 360));
    if (!motion) reduceMotion(tester);
    await pumpApp(
      tester,
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ColoredBox(
          color: dark ? const Color(0xFF16202E) : const Color(0xFFE6ECF2),
          child: EasyModeScope(
            enabled: easy,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Builder(
                  builder: (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Theme.of(context).colorScheme.surface,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.tune_rounded),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SearchPill(
                              label: locale == 'ms' ? 'Ke mana?' : 'Where to?',
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RecentPlacesBar(onPick: (_) {}, onAssign: (_) {}),
                      const SizedBox(height: 8),
                      MapToolsRow(
                        leading: const AzanTodayPill(),
                        tools: [
                          for (final (icon, label, color) in const [
                            (
                              Icons.wb_cloudy_rounded,
                              'Cuaca',
                              Color(0xFF0284C7),
                            ),
                            (Icons.air_rounded, 'Udara', Color(0xFF0D9488)),
                            (
                              Icons.explore_rounded,
                              'Kiblat',
                              Color(0xFFD97706),
                            ),
                            (
                              Icons.music_note_rounded,
                              'Muzik',
                              Color(0xFFDB2777),
                            ),
                            (
                              Icons.cloud_download_rounded,
                              'Peta',
                              Color(0xFF2563EB),
                            ),
                          ])
                            MapToolSpec(
                              icon: icon,
                              label: label,
                              color: color,
                              onPressed: () {},
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      locale: Locale(locale),
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        azanSchedulerProvider.overrideWithValue(FakeAzanScheduler()),
        azanPlayerProvider.overrideWithValue(FakeAzanPlayer()),
        prayerCalculatorProvider.overrideWithValue(FakePrayerCalculator()),
        officialTimesClientProvider.overrideWithValue(FakeOfficialClient()),
        azanClockProvider.overrideWithValue(
          () => DateTime(2026, 10, 31, 14, 0),
        ),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => []),
        ),
        voiceGuideProvider.overrideWithValue(FakeVoice()),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('shot'))),
    );
    const home = Place(
      name: 'Rumah',
      subtitle: 'Shah Alam',
      point: GeoPoint(3.07, 101.52),
    );
    await container.read(savedPlacesControllerProvider.notifier).setHome(home);
    await container
        .read(searchHistoryControllerProvider.notifier)
        .record(
          const Place(
            name: 'KLCC',
            subtitle: 'Kuala Lumpur',
            point: GeoPoint(3.1579, 101.7116),
          ),
        );
    await container
        .read(searchHistoryControllerProvider.notifier)
        .record(
          const Place(
            name: 'Puncak Alam',
            subtitle: 'Selangor',
            point: GeoPoint(3.2, 101.43),
          ),
        );
    if (motion) {
      // 900 ms jeda pertama + ~25% pancaran: gelombang separuh jalan.
      await tester.pump(const Duration(milliseconds: 950));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    } else {
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(const ValueKey('shot')),
      matchesGoldenFile('goldens/home_overlay_$name.png'),
    );
    if (motion) await tester.pumpWidget(const SizedBox());
  }

  testWidgets('390 terang', (t) => shot(t, name: '390_light', width: 390));
  testWidgets(
    '390 gelap',
    (t) => shot(t, name: '390_dark', width: 390, dark: true),
  );
  testWidgets('360 terang', (t) => shot(t, name: '360_light', width: 360));
  testWidgets('320 sempit', (t) => shot(t, name: '320_light', width: 320));
  testWidgets(
    '390 mod mudah',
    (t) => shot(t, name: '390_easy', width: 390, easy: true),
  );
  testWidgets(
    '390 gelombang carian separuh jalan',
    (t) => shot(t, name: '390_wave', width: 390, motion: true),
  );
}
