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
    this.reportAlerts = true,
    this.voiceVolume = 1.0,
    this.speechRate = 0.5,
  });

  final bool voiceEnabled;

  /// Null = ikut bahasa app.
  final VoiceLanguage? voiceLanguage;
  final NavCameraMode cameraMode;

  /// Berapa km/j di atas had laju sebelum amaran; -1 = amaran dimatikan.
  final int overspeedToleranceKmh;

  /// Amaran suara dan soalan "Masih ada?" bagi laporan di hadapan.
  final bool reportAlerts;

  /// Kelantangan suara (0.5-1.0) dan kelajuan pertuturan (0.42 perlahan, 0.5 biasa, 0.58 pantas).
  final double voiceVolume;
  final double speechRate;

  static const volumes = [0.5, 0.75, 1.0];
  static const speechRates = [0.42, 0.5, 0.58];

  NavigationSettings copyWith({
    bool? voiceEnabled,
    VoiceLanguage? voiceLanguage,
    bool clearVoiceLanguage = false,
    NavCameraMode? cameraMode,
    int? overspeedToleranceKmh,
    bool? reportAlerts,
    double? voiceVolume,
    double? speechRate,
  }) {
    return NavigationSettings(
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      voiceLanguage: clearVoiceLanguage
          ? null
          : (voiceLanguage ?? this.voiceLanguage),
      cameraMode: cameraMode ?? this.cameraMode,
      overspeedToleranceKmh:
          overspeedToleranceKmh ?? this.overspeedToleranceKmh,
      reportAlerts: reportAlerts ?? this.reportAlerts,
      voiceVolume: voiceVolume ?? this.voiceVolume,
      speechRate: speechRate ?? this.speechRate,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NavigationSettings &&
      other.voiceEnabled == voiceEnabled &&
      other.voiceLanguage == voiceLanguage &&
      other.cameraMode == cameraMode &&
      other.overspeedToleranceKmh == overspeedToleranceKmh &&
      other.reportAlerts == reportAlerts &&
      other.voiceVolume == voiceVolume &&
      other.speechRate == speechRate;

  @override
  int get hashCode => Object.hash(
    voiceEnabled,
    voiceLanguage,
    cameraMode,
    overspeedToleranceKmh,
    reportAlerts,
    voiceVolume,
    speechRate,
  );
}

const _voiceKey = 'nav.voice';
const _languageKey = 'nav.voiceLanguage';
const _cameraKey = 'nav.cameraMode';
const _overspeedKey = 'nav.overspeedTolerance';
const _reportAlertsKey = 'nav.reportAlerts';
const _volumeKey = 'nav.voiceVolume';
const _rateKey = 'nav.speechRate';

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
      reportAlerts: prefs.getBool(_reportAlertsKey) ?? true,
      voiceVolume: _oneOf(
        prefs.getDouble(_volumeKey),
        NavigationSettings.volumes,
        1.0,
      ),
      speechRate: _oneOf(
        prefs.getDouble(_rateKey),
        NavigationSettings.speechRates,
        0.5,
      ),
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

  Future<void> setReportAlerts(bool value) async {
    state = state.copyWith(reportAlerts: value);
    await ref.read(sharedPreferencesProvider).setBool(_reportAlertsKey, value);
  }

  Future<void> setVoiceVolume(double value) async {
    if (!NavigationSettings.volumes.contains(value)) return;
    state = state.copyWith(voiceVolume: value);
    await ref.read(sharedPreferencesProvider).setDouble(_volumeKey, value);
  }

  Future<void> setSpeechRate(double value) async {
    if (!NavigationSettings.speechRates.contains(value)) return;
    state = state.copyWith(speechRate: value);
    await ref.read(sharedPreferencesProvider).setDouble(_rateKey, value);
  }

  static double _oneOf(double? value, List<double> allowed, double fallback) =>
      allowed.contains(value) ? value! : fallback;

  Future<void> setCameraMode(NavCameraMode mode) async {
    state = state.copyWith(cameraMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_cameraKey, mode.name);
  }
}

final navigationSettingsProvider =
    NotifierProvider<NavigationSettingsController, NavigationSettings>(
      NavigationSettingsController.new,
    );
