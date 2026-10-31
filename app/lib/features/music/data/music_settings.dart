import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../domain/eq.dart';
import '../presentation/player_controller.dart' show musicEngineProvider;

/// Apa yang berlaku kepada muzik apabila suara navigasi bercakap.
enum DuckMode {
  /// Perlahankan kepada ~20% (lalai: muzik tidak terputus, arahan tetap jelas).
  duck,

  /// Jeda sepenuhnya dan sambung semula selepas ayat.
  pause;

  static DuckMode fromName(String? name) =>
      name == DuckMode.pause.name ? DuckMode.pause : DuckMode.duck;
}

@immutable
class MusicSettings {
  const MusicSettings({
    this.duckMode = DuckMode.duck,
    this.eq = const EqSettings(),
    this.lastTab = 0,
  });

  final DuckMode duckMode;
  final EqSettings eq;

  /// Tab terakhir dalam lembaran Muzik (0 lagu, 1 radio, 2 fail saya).
  final int lastTab;

  MusicSettings copyWith({DuckMode? duckMode, EqSettings? eq, int? lastTab}) =>
      MusicSettings(
        duckMode: duckMode ?? this.duckMode,
        eq: eq ?? this.eq,
        lastTab: lastTab ?? this.lastTab,
      );

  @override
  bool operator ==(Object other) =>
      other is MusicSettings &&
      other.duckMode == duckMode &&
      other.eq == eq &&
      other.lastTab == lastTab;

  @override
  int get hashCode => Object.hash(duckMode, eq, lastTab);
}

const _duckKey = 'music.duckMode';
const _eqEnabledKey = 'music.eq.enabled';
const _eqPresetKey = 'music.eq.preset';
const _eqGainsKey = 'music.eq.gains';
const _tabKey = 'music.lastTab';

class MusicSettingsController extends Notifier<MusicSettings> {
  @override
  MusicSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final rawGains = prefs.getStringList(_eqGainsKey);
    var gains = const EqSettings().customGainsDb;
    if (rawGains != null && rawGains.length == eqBands) {
      final parsed = [for (final g in rawGains) double.tryParse(g)];
      if (parsed.every((g) => g != null)) {
        gains = [for (final g in parsed) g!.clamp(eqMinDb, eqMaxDb).toDouble()];
      }
    }
    final tab = prefs.getInt(_tabKey) ?? 0;
    return MusicSettings(
      duckMode: DuckMode.fromName(prefs.getString(_duckKey)),
      eq: EqSettings(
        enabled: prefs.getBool(_eqEnabledKey) ?? false,
        preset: EqPreset.fromName(prefs.getString(_eqPresetKey)),
        customGainsDb: gains,
      ),
      lastTab: tab >= 0 && tab <= 2 ? tab : 0,
    );
  }

  Future<void> setDuckMode(DuckMode mode) async {
    state = state.copyWith(duckMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_duckKey, mode.name);
  }

  /// Pakai penyama semasa pada enjin. Dipanggil selepas setiap perubahan dan sekali oleh pemain
  /// semasa dibina.
  Future<void> applyEqualizer() => ref
      .read(musicEngineProvider)
      .setEqualizer(enabled: state.eq.enabled, gainsDb: state.eq.gainsDb);

  Future<void> setEqEnabled(bool on) async {
    state = state.copyWith(eq: state.eq.copyWith(enabled: on));
    await ref.read(sharedPreferencesProvider).setBool(_eqEnabledKey, on);
    await applyEqualizer();
  }

  Future<void> setEqPreset(EqPreset preset) async {
    state = state.copyWith(
      eq: state.eq.copyWith(preset: preset, enabled: true),
    );
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_eqPresetKey, preset.name);
    await prefs.setBool(_eqEnabledKey, true);
    await applyEqualizer();
  }

  Future<void> setCustomGain(int band, double db) async {
    if (band < 0 || band >= eqBands) return;
    final gains = [...state.eq.customGainsDb];
    gains[band] = db.clamp(eqMinDb, eqMaxDb).toDouble();
    state = state.copyWith(
      eq: state.eq.copyWith(customGainsDb: gains, preset: EqPreset.custom),
    );
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_eqGainsKey, [
      for (final g in gains) g.toString(),
    ]);
    await prefs.setString(_eqPresetKey, EqPreset.custom.name);
    await applyEqualizer();
  }

  Future<void> setLastTab(int tab) async {
    state = state.copyWith(lastTab: tab);
    await ref.read(sharedPreferencesProvider).setInt(_tabKey, tab);
  }
}

final musicSettingsProvider =
    NotifierProvider<MusicSettingsController, MusicSettings>(
      MusicSettingsController.new,
    );
