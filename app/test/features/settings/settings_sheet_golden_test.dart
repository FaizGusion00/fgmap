@Tags(['golden'])
library;

import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/settings/presentation/settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final entry in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    testWidgets('hab tetapan (${entry.key})', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      usePhoneSurface(tester, size: const Size(390, 1000));
      reduceMotion(tester);
      await withShadows(() async {
        await pumpApp(
          tester,
          const Material(child: SettingsSheet()),
          theme: entry.value,
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(SettingsSheet),
          matchesGoldenFile('goldens/settings_sheet_${entry.key}.png'),
        );
      });
    });
  }
}
