import 'package:flutter/material.dart';

import 'colors.dart';
import 'fgmap_theme_extension.dart';
import 'typography.dart';

/// Membina `ThemeData` Material 3 daripada palet token. Tiada warna hard-coded dalam widget.
abstract final class AppTheme {
  static ThemeData light() => _build(FgPalette.light);

  static ThemeData dark({bool amoled = false}) =>
      _build(amoled ? FgPalette.amoled : FgPalette.dark);

  static ThemeData _build(FgPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: p.onAccent,
      tertiary: p.warning,
      onTertiary: p.onWarning,
      error: p.danger,
      onError: p.onDanger,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      outline: p.outline,
      outlineVariant: p.outline,
    );

    final textTheme = FgTypography.textTheme(p.textPrimary, p.textSecondary);
    const sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      fontFamily: FgTypography.family,
      textTheme: textTheme,
      extensions: [FgmapColors.fromPalette(p)],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        shape: sheetShape,
        showDragHandle: true,
        dragHandleColor: p.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: p.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: textTheme.labelLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      dividerTheme: DividerThemeData(color: p.outline, space: 1),
    );
  }
}
