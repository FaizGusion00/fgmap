import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/adhan_prayer_calculator.dart';
import 'package:fgmap/features/azan/domain/prayer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rujukan: jadual e-Solat JAKIM zon WLY01 (Kuala Lumpur) sekitar 31 Okt (anggaran):
/// Subuh 05:45, Syuruk 06:57, Zohor 12:57, Asar 16:17, Maghrib 18:55, Isyak 20:04.
/// JAKIM menambah ihtiyat (margin keselamatan) dan menggunakan satu jadual untuk seluruh zon, jadi
/// pengiraan astronomi tulen berbeza beberapa minit (Subuh paling ketara). Toleransi 10 minit;
/// UI menyatakan "anggaran".
void main() {
  const calc = AdhanPrayerCalculator();
  const kl = GeoPoint(3.139, 101.687);
  final day = DateTime(2026, 10, 31);

  int minutes(DateTime t) => t.hour * 60 + t.minute;
  void near(DateTime actual, int h, int m, String what) {
    expect(
      (minutes(actual) - (h * 60 + m)).abs(),
      lessThanOrEqualTo(10),
      reason: '$what: ${actual.hour}:${actual.minute} vs $h:$m',
    );
  }

  test('JAKIM Kuala Lumpur 31 Okt 2026 dalam +-10 minit jadual rasmi', () {
    final t = calc.compute(
      at: kl,
      day: day,
      method: AzanMethod.jakim,
      madhab: AzanMadhab.shafi,
    );
    expect(t.day, day);
    for (final p in Prayer.values) {
      expect(t.timeOf(p), isNotNull, reason: p.name);
      expect(t.timeOf(p)!.isUtc, isFalse, reason: 'mesti waktu tempatan');
      expect(t.timeOf(p)!.day, 31, reason: '${p.name} pada hari yang sama');
    }
    near(t.timeOf(Prayer.fajr)!, 5, 45, 'Subuh');
    near(t.timeOf(Prayer.sunrise)!, 6, 57, 'Syuruk');
    near(t.timeOf(Prayer.dhuhr)!, 12, 57, 'Zohor');
    near(t.timeOf(Prayer.asr)!, 16, 17, 'Asar');
    near(t.timeOf(Prayer.maghrib)!, 18, 55, 'Maghrib');
    near(t.timeOf(Prayer.isha)!, 20, 4, 'Isyak');
  }, skip: _notMalaysiaTz());

  test('susunan waktu betul dan Hanafi melewatkan Asar', () {
    final shafi = calc.compute(
      at: kl,
      day: day,
      method: AzanMethod.jakim,
      madhab: AzanMadhab.shafi,
    );
    final hanafi = calc.compute(
      at: kl,
      day: day,
      method: AzanMethod.jakim,
      madhab: AzanMadhab.hanafi,
    );
    final order = [for (final p in Prayer.values) shafi.timeOf(p)!];
    for (var i = 1; i < order.length; i++) {
      expect(order[i].isAfter(order[i - 1]), isTrue, reason: 'susunan $i');
    }
    expect(
      hanafi.timeOf(Prayer.asr)!.isAfter(shafi.timeOf(Prayer.asr)!),
      isTrue,
    );
    expect(hanafi.timeOf(Prayer.dhuhr), shafi.timeOf(Prayer.dhuhr));
  });

  test('Kuching lebih awal daripada Kuala Lumpur (lebih timur)', () {
    const kuching = GeoPoint(1.553, 110.359);
    final klT = calc.compute(
      at: kl,
      day: day,
      method: AzanMethod.jakim,
      madhab: AzanMadhab.shafi,
    );
    final kcT = calc.compute(
      at: kuching,
      day: day,
      method: AzanMethod.jakim,
      madhab: AzanMadhab.shafi,
    );
    final diff = klT
        .timeOf(Prayer.dhuhr)!
        .difference(kcT.timeOf(Prayer.dhuhr)!)
        .inMinutes;
    // ~8.7 darjah longitud = ~35 minit.
    expect(diff, inInclusiveRange(30, 40));
  });

  test('kaedah berbeza mengubah Subuh/Isyak sahaja, bukan Zohor', () {
    final jakim = calc.compute(
      at: kl,
      day: day,
      method: AzanMethod.jakim,
      madhab: AzanMadhab.shafi,
    );
    final mwl = calc.compute(
      at: kl,
      day: day,
      method: AzanMethod.mwl,
      madhab: AzanMadhab.shafi,
    );
    expect(jakim.timeOf(Prayer.fajr), isNot(mwl.timeOf(Prayer.fajr)));
    expect(
      (jakim.timeOf(Prayer.dhuhr)!.difference(mwl.timeOf(Prayer.dhuhr)!))
          .inMinutes
          .abs(),
      lessThanOrEqualTo(1),
    );
  });

  test('nextAfter dan currentAt: sebelum Subuh, tengah hari, selepas Isyak', () {
    final t = calc.compute(
      at: kl,
      day: day,
      method: AzanMethod.jakim,
      madhab: AzanMadhab.shafi,
    );
    expect(t.nextAfter(DateTime(2026, 10, 31, 4)), Prayer.fajr);
    expect(t.currentAt(DateTime(2026, 10, 31, 4)), isNull);
    expect(t.nextAfter(DateTime(2026, 10, 31, 14)), Prayer.asr);
    expect(t.currentAt(DateTime(2026, 10, 31, 14)), Prayer.dhuhr);
    expect(t.nextAfter(DateTime(2026, 10, 31, 23)), isNull);
    expect(t.currentAt(DateTime(2026, 10, 31, 23)), Prayer.isha);
  });
}

/// Ujian nilai mutlak hanya bermakna apabila zon masa ujian ialah Malaysia (+8, tiada DST);
/// CI mungkin UTC. Ujian lain tidak bergantung pada zon.
String? _notMalaysiaTz() {
  final offset = DateTime(2026, 10, 31, 12).timeZoneOffset;
  return offset == const Duration(hours: 8)
      ? null
      : 'zon masa ujian bukan +08:00 (${offset.inHours}j)';
}
