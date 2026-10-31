import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import '../data/azan_settings.dart';
import 'prayer.dart';
import 'prayer_calculator.dart';

/// Satu notifikasi yang dijadualkan: azan pada waktu solat, atau peringatan beberapa minit sebelum.
@immutable
class ScheduledAzan {
  const ScheduledAzan({
    required this.id,
    required this.prayer,
    required this.at,
    required this.sound,
    this.reminder = false,
    this.reminderMinutes = 0,
  });

  final int id;
  final Prayer prayer;

  /// Masa tempatan notifikasi dibunyikan.
  final DateTime at;
  final AzanSound sound;
  final bool reminder;
  final int reminderMinutes;

  @override
  bool operator ==(Object other) =>
      other is ScheduledAzan &&
      other.id == id &&
      other.prayer == prayer &&
      other.at == at &&
      other.sound == sound &&
      other.reminder == reminder &&
      other.reminderMinutes == reminderMinutes;

  @override
  int get hashCode =>
      Object.hash(id, prayer, at, sound, reminder, reminderMinutes);

  @override
  String toString() =>
      'ScheduledAzan(${prayer.name}${reminder ? '-ingat' : ''} $at #$id)';
}

/// ID notifikasi yang tetap bagi (hari, waktu, peringatan): jadual semula pada hari yang sama menulis
/// ganti entri yang sama, dan tetingkap 2 hari tidak pernah berlanggar. Julat 100000-136651.
int azanNotificationId(DateTime day, Prayer prayer, {bool reminder = false}) {
  final start = DateTime(day.year);
  final dayOfYear =
      DateTime(day.year, day.month, day.day).difference(start).inDays + 1;
  return 100000 + dayOfYear * 100 + prayer.index * 10 + (reminder ? 1 : 0);
}

/// Merancang notifikasi untuk [days] hari bermula hari ini: hanya waktu yang dipilih, hanya masa
/// hadapan, ditambah peringatan jika [AzanSettings.reminderMinutes] > 0. Fungsi tulen.
List<ScheduledAzan> planAzanSchedule({
  required DateTime now,
  required GeoPoint at,
  required AzanSettings settings,
  required PrayerCalculator calculator,
  int days = 2,
}) {
  if (!settings.enabled) return const [];
  final out = <ScheduledAzan>[];
  final today = DateTime(now.year, now.month, now.day);
  for (var d = 0; d < days; d++) {
    final day = DateTime(today.year, today.month, today.day + d);
    final times = calculator.compute(
      at: at,
      day: day,
      method: settings.method,
      madhab: settings.madhab,
    );
    for (final prayer in Prayer.fardu) {
      if (!settings.prayers.contains(prayer)) continue;
      final t = times.timeOf(prayer);
      if (t == null) continue;
      if (t.isAfter(now)) {
        out.add(
          ScheduledAzan(
            id: azanNotificationId(day, prayer),
            prayer: prayer,
            at: t,
            sound: settings.sound,
          ),
        );
      }
      if (settings.reminderMinutes > 0) {
        final r = t.subtract(Duration(minutes: settings.reminderMinutes));
        if (r.isAfter(now)) {
          out.add(
            ScheduledAzan(
              id: azanNotificationId(day, prayer, reminder: true),
              prayer: prayer,
              at: r,
              sound: AzanSound.short,
              reminder: true,
              reminderMinutes: settings.reminderMinutes,
            ),
          );
        }
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
