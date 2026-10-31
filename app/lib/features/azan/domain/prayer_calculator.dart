import '../../../core/utils/geo.dart';
import 'prayer.dart';
import 'prayer_times.dart';

/// Pengira waktu solat: pada peranti, tanpa rangkaian. Antara muka supaya ujian boleh memberi waktu
/// tetap.
abstract interface class PrayerCalculator {
  /// [day] ialah hari tempatan (hanya tahun/bulan/hari digunakan).
  DailyPrayerTimes compute({
    required GeoPoint at,
    required DateTime day,
    required AzanMethod method,
    required AzanMadhab madhab,
  });
}
