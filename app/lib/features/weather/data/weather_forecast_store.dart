import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../domain/weather_forecast.dart';

/// Awalan kunci ramalan tersimpan (dipadam oleh "padam data").
const weatherCachePrefix = 'weather.v1.';
const weatherPlacesKey = 'weather.places.v1';

/// Ramalan terakhir setiap tempat (halaman Cuaca dibuka serta-merta dan tetap berguna tanpa internet)
/// dan senarai tempat yang disimpan pengguna.
class WeatherForecastStore {
  WeatherForecastStore(this._prefs);

  final SharedPreferences _prefs;

  static const maxPlaces = 8;
  static const _maxCached = 10;

  static String _key(GeoPoint p) =>
      '$weatherCachePrefix${p.lat.toStringAsFixed(2)},${p.lng.toStringAsFixed(2)}';

  WeatherForecast? load(GeoPoint point) {
    final raw = _prefs.getString(_key(point));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final f = WeatherForecast.fromStorage(json);
      // Lebih 2 hari: ramalan jam/hari sudah tidak bermakna.
      if (f == null ||
          DateTime.now().difference(f.fetchedAt) > const Duration(days: 2)) {
        return null;
      }
      return f;
    } on Object {
      return null;
    }
  }

  Future<void> save(
    GeoPoint point,
    Map<String, dynamic> response,
    DateTime fetchedAt,
  ) async {
    await _prefs.setString(
      _key(point),
      jsonEncode(WeatherForecast.rawForStorage(response, point, fetchedAt)),
    );
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(weatherCachePrefix))
        .toList();
    if (keys.length > _maxCached) {
      DateTime at(String k) {
        final m = RegExp(
          r'"_at":"([^"]+)"',
        ).firstMatch(_prefs.getString(k) ?? '');
        return DateTime.tryParse(m?.group(1) ?? '') ?? DateTime(2000);
      }

      keys.sort((a, b) => at(a).compareTo(at(b)));
      for (final k in keys.take(keys.length - _maxCached)) {
        await _prefs.remove(k);
      }
    }
  }

  List<WeatherPlace> places() {
    final raw = _prefs.getString(weatherPlacesKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final e in list) ?WeatherPlace.fromJson(e)];
    } on Object {
      return const [];
    }
  }

  Future<void> savePlaces(List<WeatherPlace> places) => _prefs.setString(
    weatherPlacesKey,
    jsonEncode([for (final p in places.take(maxPlaces)) p.toJson()]),
  );
}

final weatherForecastStoreProvider = Provider(
  (ref) => WeatherForecastStore(ref.watch(sharedPreferencesProvider)),
);
