import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/core/theme/colors.dart';
import 'package:fgmap/core/theme/fgmap_theme_extension.dart';
import 'package:fgmap/features/navigation/presentation/car/car_renderer.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';

/// Nisbah kontras WCAG 2.x antara dua warna legap.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // AA: 4.5:1 untuk teks biasa (Bahagian 14.5 dan 14.6 pelan).
  const aa = 4.5;

  final palettes = {
    'cerah': FgPalette.light,
    'gelap': FgPalette.dark,
    'AMOLED': FgPalette.amoled,
  };

  for (final entry in palettes.entries) {
    final p = entry.value;

    group('kontras AA (${entry.key})', () {
      final pairs = <String, (Color, Color)>{
        'teks utama / latar': (p.textPrimary, p.background),
        'teks utama / permukaan': (p.textPrimary, p.surface),
        'teks sekunder / latar': (p.textSecondary, p.background),
        'teks sekunder / permukaan': (p.textSecondary, p.surface),
        'onPrimary / primary': (p.onPrimary, p.primary),
        'onAccent / accent': (p.onAccent, p.accent),
        'onWarning / warning': (p.onWarning, p.warning),
        'onDanger / danger': (p.onDanger, p.danger),
        'primary sebagai teks / latar': (p.primary, p.background),
        'primary sebagai teks / permukaan': (p.primary, p.surface),
      };

      pairs.forEach((name, colors) {
        test(name, () {
          final ratio = contrastRatio(colors.$1, colors.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(aa),
            reason: '$name = ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });
  }

  test('AMOLED menggunakan latar hitam tulen', () {
    expect(FgPalette.amoled.background, const Color(0xFF000000));
  });

  test('token cerah dan gelap sepadan dengan jadual Bahagian 14.1', () {
    expect(FgPalette.light.primary, const Color(0xFF2563EB));
    expect(FgPalette.light.accent, const Color(0xFF00C2A8));
    expect(FgPalette.light.background, const Color(0xFFF7F9FC));
    expect(FgPalette.dark.primary, const Color(0xFF4F8BFF));
    expect(FgPalette.dark.accent, const Color(0xFF19D3B8));
    expect(FgPalette.dark.background, const Color(0xFF0B1220));
    expect(FgPalette.dark.surface, const Color(0xFF141C2E));
  });

  test('ThemeData membawa FgmapColors dan latar token', () {
    for (final theme in [
      AppTheme.light(),
      AppTheme.dark(),
      AppTheme.dark(amoled: true),
    ]) {
      expect(theme.extension<FgmapColors>(), isNotNull);
      expect(theme.useMaterial3, isTrue);
    }
    expect(
      AppTheme.light().scaffoldBackgroundColor,
      FgPalette.light.background,
    );
    expect(
      AppTheme.dark(amoled: true).scaffoldBackgroundColor,
      const Color(0xFF000000),
    );
  });

  test('FgmapColors.lerp di hujung t=0 dan t=1 memulangkan nilai hujung', () {
    final a = FgmapColors.fromPalette(FgPalette.light);
    final b = FgmapColors.fromPalette(FgPalette.dark);
    expect(a.lerp(b, 0).routeMain, a.routeMain);
    expect(a.lerp(b, 1).routeMain, b.routeMain);
    expect(a.lerp(null, 0.5), same(a));
  });

  group('mod gelap: kenderaan, laluan dan kad manuver di atas peta gelap', () {
    // Latar dan jalan gaya peta gelap yang tipikal.
    const mapBackground = Color(0xFF151D2B);
    const mapRoad = Color(0xFF2B3647);
    final dark = CarPalette.forBrightness(
      FgPalette.dark.primary,
      Brightness.dark,
    );

    test('bahagian kenderaan jelas pada latar dan jalan gelap', () {
      for (final background in [mapBackground, mapRoad]) {
        expect(contrastRatio(dark.body, background), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(dark.bodyTop, background),
          greaterThanOrEqualTo(6),
        );
        expect(contrastRatio(dark.tire, background), greaterThanOrEqualTo(2.0));
        expect(
          contrastRatio(dark.rider, background),
          greaterThanOrEqualTo(3.5),
        );
        expect(
          contrastRatio(dark.metal, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrastRatio(dark.rim!, background), greaterThanOrEqualTo(9));
      }
    });

    test('palet cerah tidak berubah dan tiada kontur terang', () {
      final light = CarPalette.forBrightness(
        FgPalette.light.primary,
        Brightness.light,
      );
      expect(light, CarPalette.fromPrimary(FgPalette.light.primary));
      expect(light.rim, isNull);
      expect(dark.rim, isNotNull);
      expect(dark.haloAlpha, greaterThan(light.haloAlpha));
    });

    test('garisan laluan dan tepinya jelas pada peta gelap', () {
      for (final p in [FgPalette.dark, FgPalette.amoled]) {
        final background = p.background == const Color(0xFF000000)
            ? p.background
            : mapBackground;
        expect(contrastRatio(p.primary, background), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(p.routeCasing, background),
          greaterThanOrEqualTo(9),
        );
        expect(contrastRatio(p.routeCasing, mapRoad), greaterThanOrEqualTo(6));
        // Garisan biru masih dibezakan daripada tepinya.
        expect(
          contrastRatio(p.primary, p.routeCasing),
          greaterThanOrEqualTo(1.8),
        );
      }
    });

    test('kad manuver gelap: teks putih pada biru tua (>= 7:1)', () {
      final colors = BannerColors.of(AppTheme.dark(), const Color(0xFF3A4A6B));
      expect(
        contrastRatio(colors.foreground, colors.background),
        greaterThanOrEqualTo(7),
      );
      // Kad biru tua mesti kelihatan berbeza daripada peta gelap.
      expect(
        contrastRatio(colors.border, mapBackground),
        greaterThanOrEqualTo(3),
      );
      final light = BannerColors.of(AppTheme.light(), const Color(0xFFE2E8F0));
      expect(
        contrastRatio(light.foreground, light.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('garis tepi kaca lebih jelas pada tema gelap', () {
      final dark = FgmapColors.fromPalette(FgPalette.dark);
      expect(
        contrastRatio(dark.glassBorder, FgPalette.dark.surface),
        greaterThan(
          contrastRatio(FgPalette.dark.outline, FgPalette.dark.surface),
        ),
      );
    });
  });
}
