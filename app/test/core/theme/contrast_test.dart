import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/core/theme/colors.dart';
import 'package:fgmap/core/theme/fgmap_theme_extension.dart';

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
}
