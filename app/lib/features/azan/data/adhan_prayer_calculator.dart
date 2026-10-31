import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../domain/prayer.dart';
import '../domain/prayer_calculator.dart';
import '../domain/prayer_times.dart';
import 'azan_settings.dart';
import 'official_prayer_times.dart';

/// Pengiraan astronomi pada peranti melalui `adhan_dart` (port Adhan; MIT; tiada rangkaian).
///
/// JAKIM = pratetap Singapura pakej itu: Subuh 20°, Isyak 18°, Zohor +1 minit, dibundarkan ke
/// atas. Nilai dikembalikan dalam UTC oleh pakej dan ditukar ke waktu tempatan di sini.
class AdhanPrayerCalculator implements PrayerCalculator {
  const AdhanPrayerCalculator();

  @override
  DailyPrayerTimes compute({
    required GeoPoint at,
    required DateTime day,
    required AzanMethod method,
    required AzanMadhab madhab,
  }) {
    final params = _params(method)
      ..madhab = madhab == AzanMadhab.hanafi
          ? adhan.Madhab.hanafi
          : adhan.Madhab.shafi;
    // adhan_dart mengira untuk tarikh UTC; hantar tengah hari tempatan supaya hari tidak beralih
    // di zon +8 (tengah malam tempatan = 16:00 UTC hari sebelumnya).
    final noon = DateTime(day.year, day.month, day.day, 12);
    final pt = adhan.PrayerTimes(
      date: noon.toUtc(),
      coordinates: adhan.Coordinates(at.lat, at.lng),
      calculationParameters: params,
    );
    return DailyPrayerTimes(
      day: DateTime(day.year, day.month, day.day),
      times: {
        Prayer.fajr: pt.fajr.toLocal(),
        Prayer.sunrise: pt.sunrise.toLocal(),
        Prayer.dhuhr: pt.dhuhr.toLocal(),
        Prayer.asr: pt.asr.toLocal(),
        Prayer.maghrib: pt.maghrib.toLocal(),
        Prayer.isha: pt.isha.toLocal(),
      },
    );
  }

  static adhan.CalculationParameters _params(AzanMethod method) =>
      switch (method) {
        AzanMethod.jakim => adhan.CalculationMethodParameters.singapore(),
        AzanMethod.mwl => adhan.CalculationMethodParameters.muslimWorldLeague(),
        AzanMethod.egyptian => adhan.CalculationMethodParameters.egyptian(),
        AzanMethod.karachi => adhan.CalculationMethodParameters.karachi(),
        AzanMethod.ummAlQura => adhan.CalculationMethodParameters.ummAlQura(),
      };
}

/// Waktu rasmi JAKIM jika dibenarkan dan ada dalam cache; jika tidak, pengiraan pada telefon.
/// Cache baharu membina semula penyedia ini (pengawal azan memerhatikannya).
final prayerCalculatorProvider = Provider<PrayerCalculator>((ref) {
  const calculated = AdhanPrayerCalculator();
  if (!ref.watch(azanSettingsProvider.select((s) => s.useOfficial))) {
    return calculated;
  }
  return OfficialFirstCalculator(
    months: ref.watch(officialTimesProvider),
    fallback: calculated,
  );
});
