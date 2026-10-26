import 'package:fgmap/app/app.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> _container([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

void main() {
  group('ThemeController', () {
    test('lalai: ikut sistem, bukan AMOLED', () async {
      final (c, _) = await _container();
      expect(c.read(themeControllerProvider), const ThemeSettings());
      expect(c.read(themeControllerProvider).mode, ThemeMode.system);
      expect(c.read(themeControllerProvider).amoled, isFalse);
    });

    test(
      'dibaca serta-merta daripada storan (tanpa async) supaya tiada kilat putih',
      () async {
        final (c, _) = await _container({
          'theme.mode': 'dark',
          'theme.amoled': true,
        });
        // Nilai tersedia pada bacaan pertama, sebelum sebarang await.
        final settings = c.read(themeControllerProvider);
        expect(settings.mode, ThemeMode.dark);
        expect(settings.amoled, isTrue);
      },
    );

    test(
      'setMode dan setAmoled disimpan dan dipulihkan oleh bekas baharu',
      () async {
        final (c, prefs) = await _container();
        await c.read(themeControllerProvider.notifier).setMode(ThemeMode.light);
        await c.read(themeControllerProvider.notifier).setAmoled(true);

        expect(
          c.read(themeControllerProvider),
          const ThemeSettings(mode: ThemeMode.light, amoled: true),
        );

        final restored = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(restored.dispose);
        expect(
          restored.read(themeControllerProvider),
          const ThemeSettings(mode: ThemeMode.light, amoled: true),
        );
      },
    );

    test(
      'nilai tersimpan yang tidak dikenali jatuh balik kepada ikut sistem',
      () async {
        final (c, _) = await _container({'theme.mode': 'sunset'});
        expect(c.read(themeControllerProvider).mode, ThemeMode.system);
      },
    );

    test('ThemeSettings kesamaan nilai', () {
      expect(
        const ThemeSettings(mode: ThemeMode.dark),
        const ThemeSettings(mode: ThemeMode.dark),
      );
      expect(const ThemeSettings(), isNot(const ThemeSettings(amoled: true)));
    });
  });

  group('resolveLocale (Bahasa Melayu ialah lalai)', () {
    const supported = [Locale('en'), Locale('ms')];

    test('peranti English -> English', () {
      expect(
        resolveLocale(const Locale('en', 'US'), supported),
        const Locale('en'),
      );
      expect(
        resolveLocale(const Locale('en', 'GB'), supported),
        const Locale('en'),
      );
    });

    test('peranti Melayu -> Melayu', () {
      expect(
        resolveLocale(const Locale('ms', 'MY'), supported),
        const Locale('ms'),
      );
    });

    test(
      'bahasa yang belum disokong (Mandarin, Tamil) -> Melayu, bukan English',
      () {
        expect(
          resolveLocale(const Locale('zh', 'CN'), supported),
          const Locale('ms'),
        );
        expect(
          resolveLocale(const Locale('ta', 'MY'), supported),
          const Locale('ms'),
        );
      },
    );

    test('tiada locale -> Melayu', () {
      expect(resolveLocale(null, supported), const Locale('ms'));
    });
  });
}
