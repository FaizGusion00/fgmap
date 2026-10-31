import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/error_log.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/theme/theme_controller.dart';
import '../../azan/data/azan_location.dart';
import '../../azan/data/official_prayer_times.dart';
import '../../azan/presentation/azan_controller.dart';
import '../../music/data/radio_favorites.dart';
import '../../music/data/radio_health.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../search/presentation/search_history_controller.dart';
import '../../trip_history/data/trip_history_store.dart';

/// Awalan kunci simpanan carian berhampiran (hasil di sekitar lokasi pengguna) dalam SharedPreferences.
const nearbyCachePrefix = 'nearby.v1.';

/// Kunci yang menyimpan kedudukan (dikaburkan) untuk mengira matahari.
const sunLocationKeys = ['theme.sunLat', 'theme.sunLng'];

/// Memadam kunci simpanan carian berhampiran. Dipisahkan supaya boleh diuji dan digunakan semula.
Future<void> eraseNearbyCache(SharedPreferences prefs) async {
  for (final key in prefs.getKeys().where(
    (k) => k.startsWith(nearbyCachePrefix),
  )) {
    await prefs.remove(key);
  }
}

/// Memadam SEMUA data peribadi pada peranti: sejarah carian, tempat disimpan (termasuk Rumah/Kerja),
/// laporan, stesen radio kegemaran, simpanan carian berhampiran, kedudukan matahari, kedudukan waktu azan dan cache jadual rasmi JAKIM. Tetapan (tema, suara, bahasa) dan
/// status sambutan kekal. Tiada data di pelayan untuk dipadam: app tidak mempunyai akaun.
Future<void> eraseAllUserData(WidgetRef ref) async {
  await ref.read(searchHistoryControllerProvider.notifier).clear();
  await ref.read(savedPlacesControllerProvider.notifier).clear();
  await ref.read(reportsControllerProvider.notifier).clear();
  await ref.read(tripHistoryStoreProvider).clear();
  await ref.read(radioFavoritesProvider.notifier).clear();
  await ref.read(radioHealthProvider.notifier).clear();

  final prefs = ref.read(sharedPreferencesProvider);
  await eraseNearbyCache(prefs);
  for (final key in [
    ...sunLocationKeys,
    ...azanLocationKeys,
    ...azanScheduleKeys,
    azanOfficialCacheKey,
  ]) {
    await prefs.remove(key);
  }
  ref.read(errorLogProvider).clear();
  // Bina semula supaya bacaan seterusnya (kini kosong) digunakan, bukan nilai dalam ingatan.
  ref.invalidate(sunLocationProvider);
  ref.invalidate(azanLocationProvider);
  ref.invalidate(officialTimesProvider);
}
