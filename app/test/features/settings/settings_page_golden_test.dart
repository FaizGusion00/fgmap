@Tags(['golden'])
library;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final entry in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
    'amoled': AppTheme.dark(amoled: true),
  }.entries) {
    testWidgets('halaman tetapan (${entry.key})', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      usePhoneSurface(tester, size: const Size(390, 1400));
      reduceMotion(tester);
      await withShadows(() async {
        await pumpApp(
          tester,
          const SettingsPage(),
          theme: entry.value,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            locationServiceProvider.overrideWithValue(
              FakeLocationService(accessValue: LocationAccess.granted),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(SettingsPage),
          matchesGoldenFile('goldens/settings_page_${entry.key}.png'),
        );
      });
    });
  }
}
