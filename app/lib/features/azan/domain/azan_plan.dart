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
/// ganti entri yang sama, dan tetingkap 7 hari tidak pernah berlanggar. Julat 100000-136651.
int azanNotificationId(DateTime day, Prayer prayer, {bool reminder = false}) {
  final start = DateTime(day.year);
  final dayOfYear =
      DateTime(day.year, day.month, day.day).difference(start).inDays + 1;
  return 100000 + dayOfYear * 100 + prayer.index * 10 + (reminder ? 1 : 0);
}

/// Bilangan hari yang dijadualkan ke hadapan. Seminggu supaya azan terus berbunyi walaupun app tidak
/// dibuka beberapa hari (OS menjalankan jadual sendiri apabila app ditutup).
const azanScheduleDays = 7;

/// Had notifikasi tertunda: iOS membenarkan 64 sahaja. Android tiada had praktikal, tetapi had yang
/// sama memastikan tingkah laku seragam; yang terdekat dahulu.
const azanMaxPending = 60;

/// Tandatangan jadual (tetapan + sumber waktu + bahasa). Jadual semula dilangkau hanya apabila
/// tandatangan sama; tanpa ini menukar bunyi atau waktu yang dipilih tidak mengemas kini OS.
String azanScheduleSignature(
  AzanSettings s, {
  required String source,
  required String locale,
  bool exact = true,
}) {
  final prayers = [for (final p in s.prayers) p.name]..sort();
  return [
    s.sound.name,
    s.method.name,
    s.madhab.name,
    s.reminderMinutes,
    prayers.join(','),
    source,
    locale,
    // Penggera tepat dibenarkan kemudian: jadual perlu dibuat semula dengan mod tepat.
    exact ? 'exact' : 'inexact',
  ].join('|');
}

/// Merancang notifikasi untuk [days] hari bermula hari ini: hanya waktu yang dipilih, hanya masa
/// hadapan, ditambah peringatan jika [AzanSettings.reminderMinutes] > 0. Fungsi tulen.
List<ScheduledAzan> planAzanSchedule({
  required DateTime now,
  required GeoPoint at,
  required AzanSettings settings,
  required PrayerCalculator calculator,
  int days = azanScheduleDays,
  int maxPending = azanMaxPending,
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
  return out.length <= maxPending ? out : out.sublist(0, maxPending);
}
