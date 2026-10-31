import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/azan_location.dart';
import 'package:fgmap/features/azan/data/azan_settings.dart';
import 'package:fgmap/features/azan/domain/malaysia_cities.dart';
import 'package:fgmap/features/azan/domain/prayer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  group('AzanSettings', () {
    test(
      'lalai: mati, lima waktu, azan penuh, JAKIM, Syafie, tiada peringatan',
      () {
        final s = container.read(azanSettingsProvider);
        expect(s.enabled, isFalse);
        expect(s.prayers, Prayer.fardu.toSet());
        expect(s.sound, AzanSound.full);
        expect(s.method, AzanMethod.jakim);
        expect(s.madhab, AzanMadhab.shafi);
        expect(s.reminderMinutes, 0);
        expect(s.playDuringNavigation, isFalse);
        expect(s.cityName, isNull);
        expect(s.useCity, isFalse);
      },
    );

    test('setiap tetapan disimpan dan dibaca semula', () async {
      final c = container.read(azanSettingsProvider.notifier);
      await c.setEnabled(true);
      await c.setPrayer(Prayer.fajr, false);
      await c.setPrayer(Prayer.sunrise, true); // diabaikan: syuruk tidak boleh
      await c.setSound(AzanSound.short);
      await c.setMethod(AzanMethod.mwl);
      await c.setMadhab(AzanMadhab.hanafi);
      await c.setReminderMinutes(10);
      await c.setReminderMinutes(7); // bukan pilihan: diabaikan
      await c.setPlayDuringNavigation(true);
      await c.setCity('Kuching');

      expect(prefs.getBool('azan.enabled'), isTrue);
      expect(prefs.getStringList('azan.prayers'), isNot(contains('fajr')));
      expect(prefs.getStringList('azan.prayers'), isNot(contains('sunrise')));
      expect(prefs.getString('azan.sound'), 'short');
      expect(prefs.getInt('azan.reminderMin'), 10);
      expect(prefs.getString('azan.city'), 'Kuching');

      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      final s = again.read(azanSettingsProvider);
      expect(s.enabled, isTrue);
      expect(s.prayers, {
        Prayer.dhuhr,
        Prayer.asr,
        Prayer.maghrib,
        Prayer.isha,
      });
      expect(s.sound, AzanSound.short);
      expect(s.method, AzanMethod.mwl);
      expect(s.madhab, AzanMadhab.hanafi);
      expect(s.reminderMinutes, 10);
      expect(s.playDuringNavigation, isTrue);
      expect(s.cityName, 'Kuching');

      await again.read(azanSettingsProvider.notifier).setCity(null);
      expect(again.read(azanSettingsProvider).cityName, isNull);
      expect(prefs.containsKey('azan.city'), isFalse);
    });

    test('nilai rosak dalam storan kembali ke lalai', () async {
      await prefs.setString('azan.sound', 'loud');
      await prefs.setString('azan.method', 'nasa');
      await prefs.setInt('azan.reminderMin', 99);
      await prefs.setStringList('azan.prayers', ['sunrise', 'zzz', 'asr']);
      final s = container.read(azanSettingsProvider);
      expect(s.sound, AzanSound.full);
      expect(s.method, AzanMethod.jakim);
      expect(s.reminderMinutes, 0);
      expect(s.prayers, {Prayer.asr});
    });
  });

  group('AzanLocation', () {
    test(
      'dibundarkan ke 0.01 darjah dan hanya ditulis selepas 20 km',
      () async {
        final c = container.read(azanLocationProvider.notifier);
        expect(container.read(azanLocationProvider), isNull);
        c.update(const GeoPoint(3.13912, 101.68734));
        expect(
          container.read(azanLocationProvider),
          const GeoPoint(3.14, 101.69),
        );
        expect(prefs.getDouble('azan.lat'), 3.14);
        // 5 km: tidak ditulis semula.
        c.update(const GeoPoint(3.18, 101.69));
        expect(
          container.read(azanLocationProvider),
          const GeoPoint(3.14, 101.69),
        );
        // Johor Bahru: ditulis.
        c.update(const GeoPoint(1.4927, 103.7414));
        expect(
          container.read(azanLocationProvider),
          const GeoPoint(1.49, 103.74),
        );
      },
    );

    test(
      'lokasi berkesan: bandar > tersimpan > lokasi matahari (KL)',
      () async {
        expect(
          container.read(effectiveAzanLocationProvider),
          const GeoPoint(3.139, 101.687),
        );
        container
            .read(azanLocationProvider.notifier)
            .update(const GeoPoint(5.98, 116.07));
        expect(
          container.read(effectiveAzanLocationProvider),
          const GeoPoint(5.98, 116.07),
        );
        await container.read(azanSettingsProvider.notifier).setCity('Kuching');
        expect(
          container.read(effectiveAzanLocationProvider),
          cityNamed('Kuching')!.point,
        );
      },
    );

    test('bandar terdekat', () {
      expect(nearestCity(const GeoPoint(3.0, 101.6)).name, 'Shah Alam');
      expect(nearestCity(const GeoPoint(6.0, 116.1)).name, 'Kota Kinabalu');
      expect(cityNamed('Tiada'), isNull);
      expect(
        malaysianCities.map((c) => c.name).toSet().length,
        malaysianCities.length,
      );
    });
  });
}
