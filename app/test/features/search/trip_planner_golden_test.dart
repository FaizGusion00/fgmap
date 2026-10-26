@Tags(['golden'])
library;

import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/search/presentation/trip_planner_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final entry in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    testWidgets('perancang perjalanan, keadaan awal (${entry.key})', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'search.history.v1': [
          '{"name":"KLIA Terminal 1","subtitle":"Sepang, Selangor","lat":2.7456,"lng":101.7072,"category":"station"}',
          '{"name":"Petronas Twin Towers","subtitle":"Jalan Ampang, Kuala Lumpur","lat":3.1579,"lng":101.7116}',
          '{"name":"Masjid Negara","subtitle":"Jalan Perdana, Kuala Lumpur","lat":3.1419,"lng":101.6914,"category":"mosque"}',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      usePhoneSurface(tester);
      reduceMotion(tester);
      await withShadows(() async {
        await pumpApp(
          tester,
          const TripPlannerPage(),
          theme: entry.value,
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(
          find.byType(TripPlannerPage),
          matchesGoldenFile('goldens/trip_planner_idle_${entry.key}.png'),
        );
      });
    });
  }
}
