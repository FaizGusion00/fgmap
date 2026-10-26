import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/theme_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const Scaffold(body: NavigationSettingsSheet()),
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(NavigationSettingsSheet)),
    );
  }

  testWidgets(
    'lembaran navigasi: tukar siang/malam/matahari/sistem serta-merta',
    (tester) async {
      final c = await pumpSheet(tester);
      expect(find.text('Paparan peta'), findsOneWidget);

      Future<void> pick(String label, AppThemeMode expected) async {
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('nav-theme-mode')),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(c.read(themeControllerProvider).mode, expected);
      }

      await pick('Gelap', AppThemeMode.dark);
      expect(c.read(effectiveThemeModeProvider), ThemeMode.dark);
      await pick('Cerah', AppThemeMode.light);
      expect(c.read(effectiveThemeModeProvider), ThemeMode.light);
      await pick('Matahari', AppThemeMode.sun);
      await pick('Sistem', AppThemeMode.system);
      // Pilihan disimpan (tema global yang sama dengan halaman Tetapan).
      expect(prefs.getString('theme.mode'), 'system');
    },
  );

  test('isDarkTheme: sumber tunggal cerah/gelap untuk app dan peta', () {
    expect(isDarkTheme(ThemeMode.dark, Brightness.light), isTrue);
    expect(isDarkTheme(ThemeMode.light, Brightness.dark), isFalse);
    expect(isDarkTheme(ThemeMode.system, Brightness.dark), isTrue);
    expect(isDarkTheme(ThemeMode.system, Brightness.light), isFalse);
  });
}
