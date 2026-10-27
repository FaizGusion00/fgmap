import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/preferences.dart';
import '../utils/geo.dart';
import 'solar.dart';

/// Pilihan tema pengguna (Bahagian 14.6). [sun] = gelap antara matahari terbenam dan terbit di lokasi
/// pengguna (dikira dalam peranti, tanpa rangkaian).
enum AppThemeMode { system, light, dark, sun }

@immutable
class ThemeSettings {
  const ThemeSettings({this.mode = AppThemeMode.system, this.amoled = false});

  final AppThemeMode mode;

  /// Hitam AMOLED, hanya berkesan dalam mod gelap.
  final bool amoled;

  ThemeSettings copyWith({AppThemeMode? mode, bool? amoled}) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      amoled: amoled ?? this.amoled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings && other.mode == mode && other.amoled == amoled;

  @override
  int get hashCode => Object.hash(mode, amoled);
}

const _modeKey = 'theme.mode';
const _amoledKey = 'theme.amoled';
const _sunLatKey = 'theme.sunLat';
const _sunLngKey = 'theme.sunLng';

/// Membaca tetapan tema dari storan tempatan secara serta-merta (tanpa async) kerana
/// `SharedPreferences` sudah dimuat sebelum `runApp`. Nilai tidak dikenali -> ikut sistem.
ThemeSettings readThemeSettings(SharedPreferences prefs) {
  final mode = AppThemeMode.values.firstWhere(
    (m) => m.name == prefs.getString(_modeKey),
    orElse: () => AppThemeMode.system,
  );
  return ThemeSettings(mode: mode, amoled: prefs.getBool(_amoledKey) ?? false);
}

class ThemeController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() =>
      readThemeSettings(ref.watch(sharedPreferencesProvider));

  Future<void> setMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await ref.read(sharedPreferencesProvider).setString(_modeKey, mode.name);
  }

  Future<void> setAmoled(bool value) async {
    state = state.copyWith(amoled: value);
    await ref.read(sharedPreferencesProvider).setBool(_amoledKey, value);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

/// Jam yang digunakan oleh mod matahari; diganti dalam ujian.
final themeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Lokasi terakhir yang diketahui untuk mengira matahari; lalai Kuala Lumpur. Dikemas kini apabila
/// pengguna berpindah jauh (> 30 km) supaya tidak menulis storan pada setiap fix.
class SunLocationController extends Notifier<GeoPoint> {
  static const _kualaLumpur = GeoPoint(3.139, 101.687);
  static const _updateAfterMeters = 30000.0;

  @override
  GeoPoint build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final lat = prefs.getDouble(_sunLatKey);
    final lng = prefs.getDouble(_sunLngKey);
    if (lat == null || lng == null) return _kualaLumpur;
    final stored = GeoPoint(lat, lng);
    final coarse = coarsen(stored);
    // Nilai tepat yang disimpan oleh versi lama dikaburkan semula dan ditulis ganti.
    if (coarse != stored) _persist(prefs, coarse);
    return coarse;
  }

  /// Privasi: lokasi untuk mengira matahari dibundarkan ke 0.1 darjah (~11 km). Ralat waktu
  /// matahari terbit/terbenam beberapa minit sahaja, tetapi kedudukan tepat pengguna tidak disimpan
  /// (dan tidak tersandar ke pelayan sandaran peranti).
  @visibleForTesting
  static GeoPoint coarsen(GeoPoint p) => GeoPoint(
    (p.lat * 10).roundToDouble() / 10,
    (p.lng * 10).roundToDouble() / 10,
  );

  static void _persist(SharedPreferences prefs, GeoPoint p) {
    unawaited(prefs.setDouble(_sunLatKey, p.lat));
    unawaited(prefs.setDouble(_sunLngKey, p.lng));
  }

  void update(GeoPoint point) {
    if (distanceMeters(state, point) < _updateAfterMeters) return;
    final coarse = coarsen(point);
    state = coarse;
    _persist(ref.read(sharedPreferencesProvider), coarse);
  }
}

final sunLocationProvider = NotifierProvider<SunLocationController, GeoPoint>(
  SunLocationController.new,
);

/// Benar apabila matahari sudah terbenam (atau belum terbit) di lokasi semasa. Menjadualkan
/// semakan semula tepat pada peralihan seterusnya.
class SunDarkController extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    final location = ref.watch(sunLocationProvider);
    final now = ref.read(themeClockProvider)();
    final phase = sunPhaseAt(now, lat: location.lat, lng: location.lng);
    _timer?.cancel();
    // Tambah satu saat supaya semakan jatuh selepas peralihan, dan had bawah supaya tidak berpusing.
    final wait = phase.nextChange.difference(now) + const Duration(seconds: 1);
    _timer = Timer(
      wait < const Duration(seconds: 5) ? const Duration(seconds: 5) : wait,
      ref.invalidateSelf,
    );
    return phase.isNight;
  }
}

final sunDarkProvider = NotifierProvider<SunDarkController, bool>(
  SunDarkController.new,
);

/// `ThemeMode` Flutter yang berkesan; mod matahari dipetakan kepada cerah atau gelap.
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(themeControllerProvider.select((s) => s.mode));
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.sun =>
      ref.watch(sunDarkProvider) ? ThemeMode.dark : ThemeMode.light,
  };
});

/// Benar jika [mode] menghasilkan paparan gelap di bawah kecerahan sistem [platform]. Digunakan oleh
/// app (tema) dan peta supaya keputusan cerah/gelap hanya ada satu sumber.
bool isDarkTheme(ThemeMode mode, Brightness platform) =>
    mode == ThemeMode.dark ||
    (mode == ThemeMode.system && platform == Brightness.dark);
