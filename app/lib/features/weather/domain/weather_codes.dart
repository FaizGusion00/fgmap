import 'package:flutter/material.dart';

/// Kod cuaca WMO (Open-Meteo) → ikon, label, palet suasana.
abstract final class WeatherCodes {
  /// Hanya hujan lebat / ribut — bukan renyai biasa (80–81) yang kerap di Malaysia.
  static bool isSevere(int code) =>
      code == 65 ||
      code == 66 ||
      code == 67 ||
      code == 82 ||
      code == 95 ||
      code == 96 ||
      code == 99;

  static bool isRainy(int code) =>
      (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;

  static IconData icon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code <= 48) return Icons.blur_on_rounded;
    if (code <= 57) return Icons.grain_rounded;
    if (code <= 67) return Icons.water_drop_rounded;
    if (code <= 77) return Icons.ac_unit_rounded;
    if (code <= 82) return Icons.beach_access_rounded;
    return Icons.thunderstorm_rounded;
  }

  /// Label ringkas BM / EN untuk pemandu.
  static String label(int code, {required bool malay}) {
    if (code == 0) return malay ? 'Cerah' : 'Clear';
    if (code <= 2) return malay ? 'Sebahagian berawan' : 'Partly cloudy';
    if (code == 3) return malay ? 'Mendung' : 'Overcast';
    if (code <= 48) return malay ? 'Berkabus' : 'Fog';
    if (code <= 57) return malay ? 'Gerimis' : 'Drizzle';
    if (code <= 65) return malay ? 'Hujan' : 'Rain';
    if (code <= 67) return malay ? 'Hujan lebat' : 'Heavy rain';
    if (code <= 77) return malay ? 'Salji' : 'Snow';
    if (code <= 82) return malay ? 'Hujan renyai' : 'Showers';
    if (code >= 95) return malay ? 'Ribut petir' : 'Thunderstorm';
    return malay ? 'Cuaca berubah' : 'Variable';
  }

  /// Warna suasana (bukan ungu); selaras brand biru laut FGMaps.
  static (Color top, Color bottom) atmosphere(int code, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (code == 0) {
      return dark
          ? (const Color(0xFF1A3A5C), const Color(0xFF0E1F33))
          : (const Color(0xFF7EC8E8), const Color(0xFFE8F4FA));
    }
    if (code <= 3) {
      return dark
          ? (const Color(0xFF243447), const Color(0xFF121A24))
          : (const Color(0xFFA8C5D8), const Color(0xFFEEF3F7));
    }
    if (isSevere(code) || code >= 80) {
      return dark
          ? (const Color(0xFF3A2A1A), const Color(0xFF1A1210))
          : (const Color(0xFF8FA3B5), const Color(0xFFD5DEE6));
    }
    if (isRainy(code)) {
      return dark
          ? (const Color(0xFF1E2F42), const Color(0xFF101820))
          : (const Color(0xFF6B8FA8), const Color(0xFFDCE6EE));
    }
    return dark
        ? (const Color(0xFF1F2A38), const Color(0xFF121820))
        : (const Color(0xFFB0C4D4), const Color(0xFFF0F4F8));
  }
}
