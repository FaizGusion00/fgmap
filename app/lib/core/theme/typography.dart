import 'package:flutter/material.dart';

/// Tipografi FGMap: Plus Jakarta Sans (fon variabel, dibundel; lesen OFL dalam assets/fonts).
///
/// Berat ditetapkan melalui paksi `wght` (FontVariation) di samping FontWeight, kerana fon ini
/// satu fail variabel dan FontWeight sahaja tidak dijamin memilih paksi pada semua enjin.
abstract final class FgTypography {
  static const family = 'PlusJakartaSans';

  static TextStyle _style(
    double size,
    int weight, {
    double? height,
    double? letterSpacing,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  /// Nombor ETA / kelajuan: besar dan berat, angka selebar tetap supaya tidak bergoyang bila berubah.
  static final metricLarge = _style(
    34,
    800,
    height: 1.1,
    letterSpacing: -0.5,
    features: const [FontFeature.tabularFigures()],
  );

  static final metricMedium = _style(
    22,
    700,
    height: 1.15,
    features: const [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
          headlineSmall: _style(24, 700, height: 1.25),
          titleLarge: _style(20, 700, height: 1.3),
          titleMedium: _style(16, 600, height: 1.35),
          titleSmall: _style(14, 600, height: 1.35),
          bodyLarge: _style(16, 500, height: 1.45),
          bodyMedium: _style(14, 500, height: 1.45),
          bodySmall: _style(12, 500, height: 1.4),
          labelLarge: _style(14, 700, height: 1.3),
          labelMedium: _style(12, 600, height: 1.3),
          labelSmall: _style(11, 600, height: 1.3, letterSpacing: 0.2),
        )
        .apply(bodyColor: primary, displayColor: primary)
        .copyWith(
          bodySmall: _style(12, 500, height: 1.4).copyWith(color: secondary),
          labelSmall: _style(
            11,
            600,
            height: 1.3,
            letterSpacing: 0.2,
          ).copyWith(color: secondary),
        );
  }
}
