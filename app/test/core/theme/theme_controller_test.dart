import 'package:fgmap/app/app.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/theme_controller.dart';
import 'package:fgmap/core/utils/geo.dart';
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
      expect(c.read(themeControllerProvider).mode, AppThemeMode.system);
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
        expect(settings.mode, AppThemeMode.dark);
        expect(settings.amoled, isTrue);
      },
    );

    test(
      'setMode dan setAmoled disimpan dan dipulihkan oleh bekas baharu',
      () async {
        final (c, prefs) = await _container();
        await c
            .read(themeControllerProvider.notifier)
            .setMode(AppThemeMode.light);
        await c.read(themeControllerProvider.notifier).setAmoled(true);

        expect(
          c.read(themeControllerProvider),
          const ThemeSettings(mode: AppThemeMode.light, amoled: true),
        );

        final restored = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(restored.dispose);
        expect(
          restored.read(themeControllerProvider),
          const ThemeSettings(mode: AppThemeMode.light, amoled: true),
        );
      },
    );

    test(
      'nilai tersimpan yang tidak dikenali jatuh balik kepada ikut sistem',
      () async {
        final (c, _) = await _container({'theme.mode': 'sunset'});
        expect(c.read(themeControllerProvider).mode, AppThemeMode.system);
      },
    );

    test('ThemeSettings kesamaan nilai', () {
      expect(
        const ThemeSettings(mode: AppThemeMode.dark),
        const ThemeSettings(mode: AppThemeMode.dark),
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

  group('mod matahari', () {
    test(
      'nilai disimpan dan dibaca semula; nilai tidak dikenali -> sistem',
      () async {
        final (c, prefs) = await _container();
        await c
            .read(themeControllerProvider.notifier)
            .setMode(AppThemeMode.sun);
        expect(prefs.getString('theme.mode'), 'sun');
        expect(readThemeSettings(prefs).mode, AppThemeMode.sun);
        await prefs.setString('theme.mode', 'tidak-wujud');
        expect(readThemeSettings(prefs).mode, AppThemeMode.system);
      },
    );

    test('effectiveThemeMode: sun mengikut jam (Kuala Lumpur lalai)', () async {
      // 14:00 MYT = 06:00 UTC: siang. 21:00 MYT = 13:00 UTC: malam. Jam diberi sebagai instan tempatan.
      final (c, _) = await _container({'theme.mode': 'sun'});
      final noon = DateTime.utc(2026, 10, 26, 6).toLocal();
      final c2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          themeClockProvider.overrideWithValue(() => noon),
        ],
      );
      addTearDown(c2.dispose);
      addTearDown(c.dispose);
      expect(c2.read(effectiveThemeModeProvider), ThemeMode.light);

      final night = DateTime.utc(2026, 10, 26, 13).toLocal();
      final c3 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          themeClockProvider.overrideWithValue(() => night),
        ],
      );
      addTearDown(c3.dispose);
      expect(c3.read(effectiveThemeModeProvider), ThemeMode.dark);
    });

    test('mod lain tidak bergantung pada jam', () async {
      final (c, _) = await _container({'theme.mode': 'dark'});
      addTearDown(c.dispose);
      expect(c.read(effectiveThemeModeProvider), ThemeMode.dark);
    });

    test(
      'lokasi matahari: hanya dikemas kini jika berpindah > 30 km',
      () async {
        final (c, prefs) = await _container();
        addTearDown(c.dispose);
        final notifier = c.read(sunLocationProvider.notifier);
        final start = c.read(sunLocationProvider);
        notifier.update(GeoPoint(start.lat + 0.05, start.lng));
        expect(c.read(sunLocationProvider), start, reason: 'kira-kira 5.5 km');
        notifier.update(const GeoPoint(5.98, 116.07));
        // Disimpan dikaburkan ke 0.1 darjah (privasi).
        expect(c.read(sunLocationProvider), const GeoPoint(6.0, 116.1));
        expect(prefs.getDouble('theme.sunLat'), 6.0);
      },
    );
  });
}
