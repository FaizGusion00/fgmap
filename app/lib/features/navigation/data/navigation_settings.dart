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
    this.simSpeedKmh = 80,
    this.speedCameraAlerts = true,
    this.speedCameraOsm = false,
    this.speedCameraAlertM = 800,
    this.weatherAlerts = true,
    this.alongRouteAnnounce = true,
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

  /// Kelajuan jelajah simulasi (km/j). `0` = ikut anggaran laluan (boleh ~18 km/j di bandar).
  final int simSpeedKmh;

  /// Amaran kamera AwAS (JPJ) sepanjang laluan.
  final bool speedCameraAlerts;

  /// Termasuk kamera `highway=speed_camera` OSM (dilabel komuniti).
  final bool speedCameraOsm;

  /// Jarak amaran kamera di hadapan (meter).
  final int speedCameraAlertM;

  /// Banner cuaca buruk semasa navigasi.
  final bool weatherAlerts;

  /// Suara untuk R&R / stesen minyak di hadapan (chip HUD kekal).
  final bool alongRouteAnnounce;

  static const volumes = [0.5, 0.75, 1.0];
  static const speechRates = [0.42, 0.5, 0.58];

  /// Pilihan kelajuan simulasi; 0 = auto.
  static const simSpeedChoices = [0, 40, 60, 80, 100, 120];

  static const cameraAlertDistances = [400, 800, 1200];

  NavigationSettings copyWith({
    bool? voiceEnabled,
    VoiceLanguage? voiceLanguage,
    bool clearVoiceLanguage = false,
    NavCameraMode? cameraMode,
    int? overspeedToleranceKmh,
    bool? reportAlerts,
    double? voiceVolume,
    double? speechRate,
    int? simSpeedKmh,
    bool? speedCameraAlerts,
    bool? speedCameraOsm,
    int? speedCameraAlertM,
    bool? weatherAlerts,
    bool? alongRouteAnnounce,
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
      simSpeedKmh: simSpeedKmh ?? this.simSpeedKmh,
      speedCameraAlerts: speedCameraAlerts ?? this.speedCameraAlerts,
      speedCameraOsm: speedCameraOsm ?? this.speedCameraOsm,
      speedCameraAlertM: speedCameraAlertM ?? this.speedCameraAlertM,
      weatherAlerts: weatherAlerts ?? this.weatherAlerts,
      alongRouteAnnounce: alongRouteAnnounce ?? this.alongRouteAnnounce,
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
      other.speechRate == speechRate &&
      other.simSpeedKmh == simSpeedKmh &&
      other.speedCameraAlerts == speedCameraAlerts &&
      other.speedCameraOsm == speedCameraOsm &&
      other.speedCameraAlertM == speedCameraAlertM &&
      other.weatherAlerts == weatherAlerts &&
      other.alongRouteAnnounce == alongRouteAnnounce;

  @override
  int get hashCode => Object.hash(
    voiceEnabled,
    voiceLanguage,
    cameraMode,
    overspeedToleranceKmh,
    reportAlerts,
    voiceVolume,
    speechRate,
    simSpeedKmh,
    speedCameraAlerts,
    speedCameraOsm,
    speedCameraAlertM,
    weatherAlerts,
    alongRouteAnnounce,
  );
}

const _voiceKey = 'nav.voice';
const _languageKey = 'nav.voiceLanguage';
const _cameraKey = 'nav.cameraMode';
const _overspeedKey = 'nav.overspeedTolerance';
const _reportAlertsKey = 'nav.reportAlerts';
const _volumeKey = 'nav.voiceVolume';
const _rateKey = 'nav.speechRate';
const _simSpeedKey = 'nav.simSpeedKmh';
const _speedCamKey = 'nav.speedCameraAlerts';
const _speedCamOsmKey = 'nav.speedCameraOsm';
const _speedCamDistKey = 'nav.speedCameraAlertM';
const _weatherAlertsKey = 'nav.weatherAlerts';
const _alongRouteAnnounceKey = 'nav.alongRouteAnnounce';

class NavigationSettingsController extends Notifier<NavigationSettings> {
  @override
  NavigationSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final lang = prefs.getString(_languageKey);
    final sim = prefs.getInt(_simSpeedKey) ?? 80;
    final camDist = prefs.getInt(_speedCamDistKey) ?? 800;
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
      simSpeedKmh: NavigationSettings.simSpeedChoices.contains(sim) ? sim : 80,
      speedCameraAlerts: prefs.getBool(_speedCamKey) ?? true,
      speedCameraOsm: prefs.getBool(_speedCamOsmKey) ?? false,
      speedCameraAlertM:
          NavigationSettings.cameraAlertDistances.contains(camDist)
          ? camDist
          : 800,
      weatherAlerts: prefs.getBool(_weatherAlertsKey) ?? true,
      alongRouteAnnounce: prefs.getBool(_alongRouteAnnounceKey) ?? true,
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

  Future<void> setSimSpeedKmh(int kmh) async {
    if (!NavigationSettings.simSpeedChoices.contains(kmh)) return;
    state = state.copyWith(simSpeedKmh: kmh);
    await ref.read(sharedPreferencesProvider).setInt(_simSpeedKey, kmh);
  }

  Future<void> setSpeedCameraAlerts(bool value) async {
    state = state.copyWith(speedCameraAlerts: value);
    await ref.read(sharedPreferencesProvider).setBool(_speedCamKey, value);
  }

  Future<void> setSpeedCameraOsm(bool value) async {
    state = state.copyWith(speedCameraOsm: value);
    await ref.read(sharedPreferencesProvider).setBool(_speedCamOsmKey, value);
  }

  Future<void> setSpeedCameraAlertM(int meters) async {
    if (!NavigationSettings.cameraAlertDistances.contains(meters)) return;
    state = state.copyWith(speedCameraAlertM: meters);
    await ref.read(sharedPreferencesProvider).setInt(_speedCamDistKey, meters);
  }

  Future<void> setWeatherAlerts(bool value) async {
    state = state.copyWith(weatherAlerts: value);
    await ref.read(sharedPreferencesProvider).setBool(_weatherAlertsKey, value);
  }

  Future<void> setAlongRouteAnnounce(bool value) async {
    state = state.copyWith(alongRouteAnnounce: value);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_alongRouteAnnounceKey, value);
  }
}

final navigationSettingsProvider =
    NotifierProvider<NavigationSettingsController, NavigationSettings>(
      NavigationSettingsController.new,
    );
