import 'package:flutter/material.dart';

import 'colors.dart';

/// Token khas FGMap yang tiada tempat dalam `ColorScheme` Material: warna trafik, laluan di peta
/// dan permukaan kaca. Baca dengan `Theme.of(context).extension<FgmapColors>()!` atau
/// `context.fg` (lihat `FgmapColorsX`).
@immutable
class FgmapColors extends ThemeExtension<FgmapColors> {
  const FgmapColors({
    required this.accent,
    required this.onAccent,
    required this.warning,
    required this.onWarning,
    required this.routeMain,
    required this.routeCasing,
    required this.routeAlternative,
    required this.destination,
    required this.trafficFree,
    required this.trafficModerate,
    required this.trafficHeavy,
    required this.trafficSevere,
    required this.glassSurface,
    required this.glassBorder,
  });

  factory FgmapColors.fromPalette(FgPalette p) {
    return FgmapColors(
      accent: p.accent,
      onAccent: p.onAccent,
      warning: p.warning,
      onWarning: p.onWarning,
      routeMain: p.primary,
      routeCasing: p.routeCasing,
      routeAlternative: p.routeAlternative,
      destination: p.danger,
      trafficFree: p.trafficFree,
      trafficModerate: p.trafficModerate,
      trafficHeavy: p.trafficHeavy,
      trafficSevere: p.trafficSevere,
      glassSurface: p.surface.withValues(alpha: 0.82),
      // Garis tepi kad/butang pada peta gelap mesti kelihatan: `outline` gelap hampir sama dengan latar.
      glassBorder: p.brightness == Brightness.dark
          ? Color.lerp(p.outline, const Color(0xFFFFFFFF), 0.2)!
          : p.outline,
    );
  }

  final Color accent;
  final Color onAccent;
  final Color warning;
  final Color onWarning;

  final Color routeMain;
  final Color routeCasing;
  final Color routeAlternative;
  final Color destination;

  final Color trafficFree;
  final Color trafficModerate;
  final Color trafficHeavy;
  final Color trafficSevere;

  /// Permukaan separa lutsinar untuk kad terapung di atas peta (digandingkan dengan blur ringan).
  final Color glassSurface;
  final Color glassBorder;

  @override
  FgmapColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? warning,
    Color? onWarning,
    Color? routeMain,
    Color? routeCasing,
    Color? routeAlternative,
    Color? destination,
    Color? trafficFree,
    Color? trafficModerate,
    Color? trafficHeavy,
    Color? trafficSevere,
    Color? glassSurface,
    Color? glassBorder,
  }) {
    return FgmapColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      routeMain: routeMain ?? this.routeMain,
      routeCasing: routeCasing ?? this.routeCasing,
      routeAlternative: routeAlternative ?? this.routeAlternative,
      destination: destination ?? this.destination,
      trafficFree: trafficFree ?? this.trafficFree,
      trafficModerate: trafficModerate ?? this.trafficModerate,
      trafficHeavy: trafficHeavy ?? this.trafficHeavy,
      trafficSevere: trafficSevere ?? this.trafficSevere,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
    );
  }

  @override
  FgmapColors lerp(ThemeExtension<FgmapColors>? other, double t) {
    if (other is! FgmapColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FgmapColors(
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      routeMain: mix(routeMain, other.routeMain),
      routeCasing: mix(routeCasing, other.routeCasing),
      routeAlternative: mix(routeAlternative, other.routeAlternative),
      destination: mix(destination, other.destination),
      trafficFree: mix(trafficFree, other.trafficFree),
      trafficModerate: mix(trafficModerate, other.trafficModerate),
      trafficHeavy: mix(trafficHeavy, other.trafficHeavy),
      trafficSevere: mix(trafficSevere, other.trafficSevere),
      glassSurface: mix(glassSurface, other.glassSurface),
      glassBorder: mix(glassBorder, other.glassBorder),
    );
  }
}

extension FgmapColorsX on BuildContext {
  FgmapColors get fg => Theme.of(this).extension<FgmapColors>()!;
}
