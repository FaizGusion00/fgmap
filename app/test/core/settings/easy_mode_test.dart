import 'package:fgmap/core/settings/app_preferences.dart';
import 'package:fgmap/core/settings/easy_mode_scope.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nisbah kontras WCAG antara dua warna legap.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppPreferences.easyMode', () {
    test('lalai mati; dibaca dari storan; teks berkesan >= 115%', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(readAppPreferences(prefs).easyMode, isFalse);
      expect(const AppPreferences().effectiveTextScale, 1.0);

      await prefs.setBool('app.easyMode', true);
      final read = readAppPreferences(prefs);
      expect(read.easyMode, isTrue);
      expect(read.effectiveTextScale, 1.15);
      expect(
        const AppPreferences(easyMode: true, textScale: 1.3).effectiveTextScale,
        1.3,
      );
      expect(
        const AppPreferences(easyMode: true, textScale: 0.9).effectiveTextScale,
        1.15,
      );
    });
  });

  group('NavHudMetrics Mod mudah', () {
    test('ikon dan butang 25% lebih besar, nombor 15%, padding sama', () {
      for (final size in const [
        Size(390, 844),
        Size(844, 390),
        Size(320, 568),
      ]) {
        final base = NavHudMetrics.forSize(size);
        final easy = NavHudMetrics.forSize(size, easy: true);
        expect(easy.bannerIcon, closeTo(base.bannerIcon * 1.25, 0.01));
        expect(easy.thenIcon, closeTo(base.thenIcon * 1.25, 0.01));
        expect(easy.button, closeTo(base.button * 1.25, 0.01));
        expect(easy.distanceSize, closeTo(base.distanceSize * 1.15, 0.01));
        expect(easy.speedSize, closeTo(base.speedSize * 1.15, 0.01));
        expect(easy.padH, base.padH);
        expect(easy.padV, base.padV);
        expect(easy.bannerMaxWidth, base.bannerMaxWidth);
        expect(easy.button, greaterThanOrEqualTo(50));
      }
    });

    testWidgets('NavHudMetrics.of membaca EasyModeScope', (tester) async {
      late NavHudMetrics inScope;
      late NavHudMetrics outside;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  outside = NavHudMetrics.of(context);
                  return const SizedBox();
                },
              ),
              EasyModeScope(
                enabled: true,
                child: Builder(
                  builder: (context) {
                    inScope = NavHudMetrics.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(inScope.bannerIcon, greaterThan(outside.bannerIcon));
    });
  });

  group('BannerColors kontras tinggi', () {
    test('>= 7:1 pada kedua-dua tema, sempadan 2 px', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final normal = BannerColors.of(theme, Colors.white);
        final high = BannerColors.of(theme, Colors.white, highContrast: true);
        expect(
          contrastRatio(high.background, high.foreground),
          greaterThanOrEqualTo(7),
          reason: theme.brightness.name,
        );
        expect(high.borderWidth, 2);
        expect(normal.borderWidth, 1);
        // Kad biasa pun mesti AA (>= 4.5:1).
        expect(
          contrastRatio(normal.background, normal.foreground),
          greaterThanOrEqualTo(4.5),
          reason: theme.brightness.name,
        );
      }
    });
  });
}
