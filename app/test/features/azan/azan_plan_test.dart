import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/azan_settings.dart';
import 'package:fgmap/features/azan/domain/azan_plan.dart';
import 'package:fgmap/features/azan/domain/prayer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'azan_test_support.dart';

void main() {
  const kl = GeoPoint(3.139, 101.687);
  final calc = FakePrayerCalculator();
  final now = DateTime(2026, 10, 31, 14, 0); // selepas Zohor (13:05)

  test('mati: tiada jadual', () {
    expect(
      planAzanSchedule(
        now: now,
        at: kl,
        settings: const AzanSettings(),
        calculator: calc,
      ),
      isEmpty,
    );
  });

  test('hanya waktu hadapan dan waktu yang dipilih, 7 hari, tersusun', () {
    final items = planAzanSchedule(
      now: now,
      at: kl,
      settings: const AzanSettings(enabled: true),
      calculator: calc,
    );
    // Hari ini: Asar, Maghrib, Isyak; enam hari lagi: 5 waktu setiap hari.
    expect(items, hasLength(3 + 6 * 5));
    expect(items.first.prayer, Prayer.asr);
    expect(items.first.at, DateTime(2026, 10, 31, 16, 25));
    expect(items.last.prayer, Prayer.isha);
    expect(items.last.at.day, 6);
    expect(items.last.at.month, 11);
    for (var i = 1; i < items.length; i++) {
      expect(items[i].at.isAfter(items[i - 1].at), isTrue);
    }
    expect(items.every((i) => i.sound == AzanSound.full), isTrue);
    expect(items.every((i) => !i.reminder), isTrue);
    expect(items.any((i) => i.prayer == Prayer.sunrise), isFalse);
  });

  test('waktu dibuang daripada pilihan tidak dijadualkan', () {
    final items = planAzanSchedule(
      now: now,
      at: kl,
      settings: const AzanSettings(enabled: true, prayers: {Prayer.maghrib}),
      calculator: calc,
    );
    expect(items.map((i) => i.prayer).toSet(), {Prayer.maghrib});
    expect(items, hasLength(azanScheduleDays));
  });

  test('peringatan awal ditambah sebelum setiap waktu dengan nada pendek', () {
    final items = planAzanSchedule(
      now: now,
      at: kl,
      settings: const AzanSettings(
        enabled: true,
        prayers: {Prayer.asr},
        reminderMinutes: 10,
        sound: AzanSound.silent,
      ),
      calculator: calc,
      days: 1,
    );
    expect(items, hasLength(2));
    expect(items[0].reminder, isTrue);
    expect(items[0].at, DateTime(2026, 10, 31, 16, 15));
    expect(items[0].sound, AzanSound.short);
    expect(items[0].reminderMinutes, 10);
    expect(items[1].reminder, isFalse);
    expect(items[1].sound, AzanSound.silent);
    expect(items[0].id, isNot(items[1].id));
  });

  test('ID tetap, unik dan dalam julat', () {
    final day = DateTime(2026, 10, 31);
    final a = azanNotificationId(day, Prayer.fajr);
    expect(a, azanNotificationId(DateTime(2026, 10, 31, 23, 59), Prayer.fajr));
    // Unik sepanjang satu tahun (ID berulang tahun ke tahun; hanya 7 hari dijadualkan).
    final ids = <int>{};
    for (var d = 0; d < 365; d++) {
      final dd = DateTime(2026, 1, 1 + d);
      for (final p in Prayer.values) {
        ids.add(azanNotificationId(dd, p));
        ids.add(azanNotificationId(dd, p, reminder: true));
      }
    }
    expect(ids, hasLength(365 * Prayer.values.length * 2));
    expect(ids.every((i) => i >= 100000 && i < 140000), isTrue);
  });

  test('menggunakan kaedah dan mazhab daripada tetapan', () {
    final c = FakePrayerCalculator();
    planAzanSchedule(
      now: now,
      at: kl,
      settings: const AzanSettings(
        enabled: true,
        method: AzanMethod.mwl,
        madhab: AzanMadhab.hanafi,
      ),
      calculator: c,
    );
    expect(c.calls, hasLength(azanScheduleDays));
    expect(c.calls.first.$3, AzanMethod.mwl);
    expect(c.calls.first.$4, AzanMadhab.hanafi);
  });

  test('had notifikasi tertunda: yang terdekat dikekalkan (iOS 64)', () {
    final items = planAzanSchedule(
      now: now,
      at: kl,
      settings: const AzanSettings(enabled: true, reminderMinutes: 10),
      calculator: calc,
    );
    // 33 azan + 33 peringatan > 60.
    expect(items, hasLength(azanMaxPending));
    expect(items.first.at, DateTime(2026, 10, 31, 16, 15)); // peringatan Asar
    for (var i = 1; i < items.length; i++) {
      expect(items[i].at.isAfter(items[i - 1].at), isTrue);
    }
  });

  test(
    'tandatangan jadual berubah apabila tetapan yang mempengaruhi OS berubah',
    () {
      String sig(
        AzanSettings s, {
        String source = 'calc',
        String locale = 'ms',
        bool exact = true,
      }) => azanScheduleSignature(
        s,
        source: source,
        locale: locale,
        exact: exact,
      );
      const base = AzanSettings(enabled: true);
      final a = sig(base);
      expect(sig(base), a);
      expect(sig(base.copyWith(sound: AzanSound.short)), isNot(a));
      expect(sig(base.copyWith(reminderMinutes: 5)), isNot(a));
      expect(sig(base.copyWith(prayers: {Prayer.fajr})), isNot(a));
      expect(sig(base.copyWith(method: AzanMethod.mwl)), isNot(a));
      expect(sig(base, source: 'WLY01'), isNot(a));
      expect(sig(base, locale: 'en'), isNot(a));
      expect(sig(base, exact: false), isNot(a));
      // Tidak mempengaruhi OS: tidak menjadualkan semula.
      expect(sig(base.copyWith(playDuringNavigation: true)), a);
    },
  );
}
