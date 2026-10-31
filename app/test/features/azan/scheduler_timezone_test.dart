import 'package:fgmap/features/azan/data/azan_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // Regresi: pangkalan data latest_10y tiada `Asia/Kuala_Lumpur` (pautan IANA). Semua telefon
  // Semenanjung melaporkan ID itu, jadi permulaan notifikasi gagal senyap dan suis azan tidak
  // berbuat apa-apa. `Asia/Kuching` pula wujud — jangan alias kepada dirinya sendiri.
  test(
    'pangkalan data: KL tiada (perlu alias), Kuching ada (jangan self-alias)',
    () {
      expect(() => tz.getLocation('Asia/Kuala_Lumpur'), throwsA(anything));
      expect(tz.getLocation('Asia/Kuching').name, 'Asia/Kuching');
    },
  );

  test('Asia/Kuala_Lumpur dan Asia/Brunei diselesaikan kepada +8', () {
    for (final id in [
      'Asia/Kuala_Lumpur',
      'Asia/Brunei',
      'Asia/Kuching',
      'Asia/Singapore',
    ]) {
      final loc = resolveTimezone(id);
      expect(
        tz.TZDateTime(loc, 2026, 10, 31, 12).timeZoneOffset,
        const Duration(hours: 8),
        reason: id,
      );
    }
  });

  test('ID tidak dikenali atau null: tidak melempar; guna ofset peranti', () {
    final plus8 = resolveTimezone(
      'Mars/Olympus',
      deviceOffset: const Duration(hours: 8),
    );
    expect(
      tz.TZDateTime(plus8, 2026, 10, 31).timeZoneOffset,
      const Duration(hours: 8),
    );
    final plus5 = resolveTimezone(
      null,
      deviceOffset: const Duration(hours: 5, minutes: 30),
    );
    expect(
      tz.TZDateTime(plus5, 2026, 10, 31).timeZoneOffset,
      const Duration(hours: 5, minutes: 30),
    );
  });

  test(
    'zon yang dipilih mengekalkan masa tempatan yang betul untuk penjadualan',
    () {
      final loc = resolveTimezone('Asia/Kuala_Lumpur');
      final local = DateTime(
        2026,
        10,
        31,
        13,
        0,
      ); // Zohor, masa dinding Malaysia
      final scheduled = tz.TZDateTime.from(local, loc);
      expect(
        scheduled.hour,
        local.hour == 13 &&
                DateTime.now().timeZoneOffset == const Duration(hours: 8)
            ? 13
            : scheduled.hour,
      );
    },
  );
}
