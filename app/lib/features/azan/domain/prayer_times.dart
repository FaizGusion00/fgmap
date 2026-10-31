import 'package:flutter/foundation.dart';

import 'prayer.dart';

/// Waktu solat untuk satu hari tempatan di satu lokasi. Semua [DateTime] dalam waktu tempatan.
@immutable
class DailyPrayerTimes {
  const DailyPrayerTimes({required this.day, required this.times, this.zone});

  /// Hari (tengah malam tempatan) yang dikira.
  final DateTime day;
  final Map<Prayer, DateTime> times;

  /// Kod zon JAKIM (cth. `WLY01`) jika waktu ini data rasmi e-Solat; null = dikira pada telefon.
  final String? zone;

  bool get isOfficial => zone != null;

  DateTime? timeOf(Prayer p) => times[p];

  /// Waktu fardu seterusnya selepas [now] pada hari ini; null jika Isyak sudah berlalu.
  Prayer? nextAfter(DateTime now) {
    for (final p in Prayer.fardu) {
      final t = times[p];
      if (t != null && t.isAfter(now)) return p;
    }
    return null;
  }

  /// Waktu fardu semasa (yang terakhir bermula sebelum atau pada [now]); null sebelum Subuh.
  Prayer? currentAt(DateTime now) {
    Prayer? current;
    for (final p in Prayer.fardu) {
      final t = times[p];
      if (t != null && !t.isAfter(now)) current = p;
    }
    return current;
  }

  @override
  bool operator ==(Object other) =>
      other is DailyPrayerTimes &&
      other.day == day &&
      other.zone == zone &&
      mapEquals(other.times, times);

  @override
  int get hashCode => Object.hash(day, zone, Object.hashAll(times.values));
}
