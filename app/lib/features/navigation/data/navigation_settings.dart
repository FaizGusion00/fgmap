import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../domain/camera_planner.dart';
import '../domain/instruction_text.dart';

@immutable
class NavigationSettings {
  const NavigationSettings({
    this.voiceEnabled = true,
    this.voiceLanguage,
    this.cameraMode = NavCameraMode.auto,
    this.overspeedToleranceKmh = 5,
  });

  final bool voiceEnabled;

  /// Null = ikut bahasa app.
  final VoiceLanguage? voiceLanguage;
  final NavCameraMode cameraMode;

  /// Berapa km/j di atas had laju sebelum amaran; -1 = amaran dimatikan.
  final int overspeedToleranceKmh;

  NavigationSettings copyWith({
    bool? voiceEnabled,
    VoiceLanguage? voiceLanguage,
    bool clearVoiceLanguage = false,
    NavCameraMode? cameraMode,
    int? overspeedToleranceKmh,
  }) {
    return NavigationSettings(
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      voiceLanguage: clearVoiceLanguage
          ? null
          : (voiceLanguage ?? this.voiceLanguage),
      cameraMode: cameraMode ?? this.cameraMode,
      overspeedToleranceKmh:
          overspeedToleranceKmh ?? this.overspeedToleranceKmh,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NavigationSettings &&
      other.voiceEnabled == voiceEnabled &&
      other.voiceLanguage == voiceLanguage &&
      other.cameraMode == cameraMode &&
      other.overspeedToleranceKmh == overspeedToleranceKmh;

  @override
  int get hashCode => Object.hash(
    voiceEnabled,
    voiceLanguage,
    cameraMode,
    overspeedToleranceKmh,
  );
}

const _voiceKey = 'nav.voice';
const _languageKey = 'nav.voiceLanguage';
const _cameraKey = 'nav.cameraMode';
const _overspeedKey = 'nav.overspeedTolerance';

class NavigationSettingsController extends Notifier<NavigationSettings> {
  @override
  NavigationSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final lang = prefs.getString(_languageKey);
    return NavigationSettings(
      voiceEnabled: prefs.getBool(_voiceKey) ?? true,
      voiceLanguage: lang == null ? null : VoiceLanguage.fromCode(lang),
      cameraMode: NavCameraMode.fromName(prefs.getString(_cameraKey)),
      overspeedToleranceKmh: prefs.getInt(_overspeedKey) ?? 5,
    );
  }

  Future<void> setVoiceEnabled(bool value) async {
    state = state.copyWith(voiceEnabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_voiceKey, value);
  }

  /// [language] null = ikut bahasa app.
  Future<void> setVoiceLanguage(VoiceLanguage? language) async {
    state = language == null
        ? state.copyWith(clearVoiceLanguage: true)
        : state.copyWith(voiceLanguage: language);
    final prefs = ref.read(sharedPreferencesProvider);
    if (language == null) {
      await prefs.remove(_languageKey);
    } else {
      await prefs.setString(_languageKey, language.code);
    }
  }

  Future<void> setOverspeedTolerance(int kmh) async {
    state = state.copyWith(overspeedToleranceKmh: kmh);
    await ref.read(sharedPreferencesProvider).setInt(_overspeedKey, kmh);
  }

  Future<void> setCameraMode(NavCameraMode mode) async {
    state = state.copyWith(cameraMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_cameraKey, mode.name);
  }
}

final navigationSettingsProvider =
    NotifierProvider<NavigationSettingsController, NavigationSettings>(
      NavigationSettingsController.new,
    );
