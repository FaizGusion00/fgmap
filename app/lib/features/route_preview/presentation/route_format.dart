import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

/// "800 m", "67.0 km", "359 km". Satu perpuluhan di bawah 100 km; selepas itu nombor bulat.
/// Meter dibundar ke 10 terdekat; 995 m ke atas dipaparkan dalam km supaya tidak menjadi "1000 m".
String formatDistance(AppLocalizations l10n, int meters) {
  if (meters < 995) return l10n.distanceMeters(_roundTo(meters, 10));
  final km = meters / 1000;
  final format = NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: km < 100 ? 1 : 0,
  );
  return l10n.distanceKilometers(format.format(km));
}

/// "58 min", "3 j 34 min". Dibundar ke minit terdekat dan sekurang-kurangnya 1 minit.
String formatDuration(AppLocalizations l10n, int seconds) {
  final totalMinutes = (seconds / 60).round().clamp(1, 1 << 30);
  if (totalMinutes < 60) return l10n.durationMinutes(totalMinutes);
  return l10n.durationHoursMinutes(totalMinutes ~/ 60, totalMinutes % 60);
}

int _roundTo(int value, int step) =>
    ((value / step).round() * step).clamp(step, 1 << 30);
