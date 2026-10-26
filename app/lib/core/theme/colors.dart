import 'package:flutter/material.dart';

/// Token warna FGMap (Bahagian 14.1 pelan). Widget tidak merujuk kelas ini terus; ia membaca
/// `Theme.of(context).colorScheme` dan `FgmapColors` yang dibina daripada palet ini.
@immutable
class FgPalette {
  const FgPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.routeCasing,
    required this.routeAlternative,
    required this.trafficFree,
    required this.trafficModerate,
    required this.trafficHeavy,
    required this.trafficSevere,
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;

  /// Garis tepi laluan di peta, supaya laluan jelas atas jalan berwarna.
  final Color routeCasing;
  final Color routeAlternative;

  final Color trafficFree;
  final Color trafficModerate;
  final Color trafficHeavy;
  final Color trafficSevere;

  static const light = FgPalette(
    brightness: Brightness.light,
    primary: Color(0xFF2563EB),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF00C2A8),
    onAccent: Color(0xFF0F172A),
    warning: Color(0xFFF59E0B),
    onWarning: Color(0xFF0F172A),
    danger: Color(0xFFEF4444),
    // Putih atas #EF4444 hanya 3.8:1 (gagal AA untuk teks biasa), jadi teks gelap digunakan.
    onDanger: Color(0xFF0F172A),
    background: Color(0xFFF7F9FC),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    outline: Color(0xFFE2E8F0),
    routeCasing: Color(0xFFFFFFFF),
    routeAlternative: Color(0xFF94A3B8),
    trafficFree: Color(0xFF16A34A),
    trafficModerate: Color(0xFFF59E0B),
    trafficHeavy: Color(0xFFEF4444),
    trafficSevere: Color(0xFF991B1B),
  );

  static const dark = FgPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF4F8BFF),
    onPrimary: Color(0xFF0B1220),
    accent: Color(0xFF19D3B8),
    onAccent: Color(0xFF0B1220),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF0B1220),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF0B1220),
    background: Color(0xFF0B1220),
    surface: Color(0xFF141C2E),
    textPrimary: Color(0xFFE6EAF2),
    textSecondary: Color(0xFFA3AEC2),
    outline: Color(0xFF263149),
    // Tepi laluan TERANG pada peta gelap (sama seperti tepi putih pada peta cerah): tepi gelap hilang
    // dalam jalan gelap dan garisan biru kehilangan sempadannya.
    routeCasing: Color(0xFFCFE0FF),
    routeAlternative: Color(0xFF7C8BA3),
    trafficFree: Color(0xFF4ADE80),
    trafficModerate: Color(0xFFFBBF24),
    trafficHeavy: Color(0xFFF87171),
    trafficSevere: Color(0xFFDC2626),
  );

  /// Hitam AMOLED: latar hitam tulen (jimat bateri pada OLED, kurang silau). Permukaan sedikit
  /// lebih cerah daripada hitam supaya kad dan lembaran masih kelihatan berbeza.
  static final amoled = dark.copyWith(
    background: const Color(0xFF000000),
    surface: const Color(0xFF0A0F1C),
    outline: const Color(0xFF1C2438),
  );

  FgPalette copyWith({
    Color? background,
    Color? surface,
    Color? outline,
    Color? routeCasing,
  }) {
    return FgPalette(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      accent: accent,
      onAccent: onAccent,
      warning: warning,
      onWarning: onWarning,
      danger: danger,
      onDanger: onDanger,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      outline: outline ?? this.outline,
      routeCasing: routeCasing ?? this.routeCasing,
      routeAlternative: routeAlternative,
      trafficFree: trafficFree,
      trafficModerate: trafficModerate,
      trafficHeavy: trafficHeavy,
      trafficSevere: trafficSevere,
    );
  }
}
