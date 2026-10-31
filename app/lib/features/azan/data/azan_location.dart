import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/geo.dart';
import '../domain/malaysia_cities.dart';
import 'azan_settings.dart';

/// Kunci kedudukan (dikaburkan) untuk waktu solat; dipadam oleh "Padam semua data saya".
const azanLocationKeys = ['azan.lat', 'azan.lng'];

/// Lokasi terakhir untuk waktu solat, dibundarkan ke 0.01° (~1 km: ralat waktu < 10 saat) dan
/// hanya ditulis semula selepas berpindah >= 20 km. Null = belum pernah ada fix.
class AzanLocationController extends Notifier<GeoPoint?> {
  static const _updateAfterMeters = 20000.0;

  @override
  GeoPoint? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final lat = prefs.getDouble(azanLocationKeys[0]);
    final lng = prefs.getDouble(azanLocationKeys[1]);
    if (lat == null || lng == null) return null;
    return coarsen(GeoPoint(lat, lng));
  }

  @visibleForTesting
  static GeoPoint coarsen(GeoPoint p) => GeoPoint(
    (p.lat * 100).roundToDouble() / 100,
    (p.lng * 100).roundToDouble() / 100,
  );

  /// [force] = fix segar yang diminta secara sengaja (cth. semasa menghidupkan azan atau app kembali
  /// ke hadapan): abaikan ambang 20 km dan semakan "coarse sama" supaya persist + pemberitahuan
  /// sentiasa berlaku untuk kemas kini yang diminta.
  void update(GeoPoint point, {bool force = false}) {
    final current = state;
    if (!force &&
        current != null &&
        distanceMeters(current, point) < _updateAfterMeters) {
      return;
    }
    final coarse = coarsen(point);
    if (!force && coarse == current) return;
    state = coarse;
    _persist(ref.read(sharedPreferencesProvider), coarse);
  }

  static void _persist(SharedPreferences prefs, GeoPoint p) {
    unawaited(prefs.setDouble(azanLocationKeys[0], p.lat));
    unawaited(prefs.setDouble(azanLocationKeys[1], p.lng));
  }
}

final azanLocationProvider =
    NotifierProvider<AzanLocationController, GeoPoint?>(
      AzanLocationController.new,
    );

/// Lokasi yang digunakan untuk mengira: bandar pilihan manual jika ditetapkan; jika tidak, lokasi
/// azan tersimpan; jika tiada, lokasi matahari (0.1°, lalai Kuala Lumpur).
final effectiveAzanLocationProvider = Provider<GeoPoint>((ref) {
  final city = cityNamed(ref.watch(azanSettingsProvider).cityName);
  if (city != null) return city.point;
  return ref.watch(azanLocationProvider) ?? ref.watch(sunLocationProvider);
});
