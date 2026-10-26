import 'package:fgmap/core/theme/solar.dart';
import 'package:flutter_test/flutter_test.dart';

// Nilai rujukan dikira secara bebas daripada separuh hari: tengah hari suria = 12:00 + (meridian zon
// 120 BT - bujur) x 4 min - persamaan masa; panjang hari daripada deklinasi. Diterima dalam lingkungan
// 8 minit (formula ringkas, pembiasan -0.833 darjah).
Duration _diff(DateTime a, DateTime b) => a.difference(b).abs();

void main() {
  group('solarTimes', () {
    test(
      'Kuala Lumpur 26 Okt 2026: terbit ~07:03, terbenam ~19:08 (MYT, UTC+8)',
      () {
        final t = solarTimes(
          year: 2026,
          month: 10,
          day: 26,
          lat: 3.139,
          lng: 101.687,
        )!;
        final rise = t.sunrise.add(const Duration(hours: 8));
        final set = t.sunset.add(const Duration(hours: 8));
        expect(
          _diff(rise, DateTime.utc(2026, 10, 26, 6, 57)),
          lessThan(const Duration(minutes: 8)),
        );
        expect(
          _diff(set, DateTime.utc(2026, 10, 26, 18, 58)),
          lessThan(const Duration(minutes: 8)),
        );
      },
    );

    test('Kota Kinabalu 21 Jun: terbit ~06:04, terbenam ~18:30 (UTC+8)', () {
      final t = solarTimes(
        year: 2026,
        month: 6,
        day: 21,
        lat: 5.98,
        lng: 116.07,
      )!;
      expect(
        _diff(
          t.sunrise.add(const Duration(hours: 8)),
          DateTime.utc(2026, 6, 21, 6, 4),
        ),
        lessThan(const Duration(minutes: 8)),
      );
      expect(
        _diff(
          t.sunset.add(const Duration(hours: 8)),
          DateTime.utc(2026, 6, 21, 18, 30),
        ),
        lessThan(const Duration(minutes: 8)),
      );
    });

    test('khatulistiwa: panjang hari ~12 jam sepanjang tahun', () {
      for (var month = 1; month <= 12; month++) {
        final t = solarTimes(
          year: 2026,
          month: month,
          day: 15,
          lat: 3.1,
          lng: 101.7,
        )!;
        final hours = t.sunset.difference(t.sunrise).inMinutes / 60;
        expect(hours, inInclusiveRange(11.7, 12.5), reason: 'bulan $month');
      }
    });

    test('latitud tinggi: hari panjang musim panas dan pendek musim sejuk', () {
      final summer = solarTimes(
        year: 2026,
        month: 6,
        day: 21,
        lat: 50,
        lng: 10,
      )!;
      final winter = solarTimes(
        year: 2026,
        month: 12,
        day: 21,
        lat: 50,
        lng: 10,
      )!;
      expect(
        summer.sunset.difference(summer.sunrise).inHours,
        greaterThanOrEqualTo(15),
      );
      expect(
        winter.sunset.difference(winter.sunrise).inHours,
        lessThanOrEqualTo(8),
      );
    });

    test('kutub tanpa matahari terbit -> null', () {
      expect(
        solarTimes(year: 2026, month: 12, day: 21, lat: 80, lng: 0),
        isNull,
      );
    });
  });

  group('sunPhaseAt', () {
    // Mesin ujian berjalan dalam zon masa apa pun; elakkan kebergantungan dengan membina instan
    // daripada UTC dan menggunakan lng khatulistiwa 0 supaya hari tempatan = hari UTC.
    const lat = 0.0, lng = 0.0;

    test(
      'siang: bukan malam; peralihan seterusnya ialah matahari terbenam',
      () {
        final now = DateTime.utc(2026, 3, 20, 12);
        final phase = sunPhaseAt(now.toLocal(), lat: lat, lng: lng);
        expect(phase.isNight, isFalse);
        expect(phase.nextChange.toUtc().hour, anyOf(17, 18));
      },
    );

    test('malam sebelum fajar: gelap; seterusnya ialah matahari terbit', () {
      final now = DateTime.utc(2026, 3, 20, 3);
      final phase = sunPhaseAt(now.toLocal(), lat: lat, lng: lng);
      expect(phase.isNight, isTrue);
      expect(phase.nextChange.toUtc().hour, anyOf(5, 6));
    });

    test('selepas terbenam: gelap; terbit esok', () {
      final now = DateTime.utc(2026, 3, 20, 22);
      final phase = sunPhaseAt(now.toLocal(), lat: lat, lng: lng);
      expect(phase.isNight, isTrue);
      expect(phase.nextChange.isAfter(now), isTrue);
      expect(phase.nextChange.difference(now).inHours, lessThan(12));
    });

    test('kutub: sandaran jam 06-18', () {
      expect(
        sunPhaseAt(DateTime(2026, 12, 21, 12), lat: 80, lng: 0).isNight,
        isFalse,
      );
      expect(
        sunPhaseAt(DateTime(2026, 12, 21, 22), lat: 80, lng: 0).isNight,
        isTrue,
      );
    });
  });
}
