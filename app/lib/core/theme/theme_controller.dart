import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/preferences.dart';

@immutable
class ThemeSettings {
  const ThemeSettings({this.mode = ThemeMode.system, this.amoled = false});

  final ThemeMode mode;

  /// Hitam AMOLED, hanya berkesan dalam mod gelap.
  final bool amoled;

  ThemeSettings copyWith({ThemeMode? mode, bool? amoled}) {
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

/// Membaca tetapan tema dari storan tempatan secara serta-merta (tanpa async) kerana
/// `SharedPreferences` sudah dimuat sebelum `runApp`.
ThemeSettings readThemeSettings(SharedPreferences prefs) {
  final mode = ThemeMode.values.firstWhere(
    (m) => m.name == prefs.getString(_modeKey),
    orElse: () => ThemeMode.system,
  );
  return ThemeSettings(mode: mode, amoled: prefs.getBool(_amoledKey) ?? false);
}

class ThemeController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() =>
      readThemeSettings(ref.watch(sharedPreferencesProvider));

  Future<void> setMode(ThemeMode mode) async {
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
