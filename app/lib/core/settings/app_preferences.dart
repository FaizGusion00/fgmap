import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/preferences.dart';
import '../utils/haptics.dart';

/// Tetapan umum app: bahasa, saiz teks, gerakan dan getaran (Bahagian 17.10-17.11).
@immutable
class AppPreferences {
  const AppPreferences({
    this.haptics = true,
    this.textScale = 1.0,
    this.reduceMotion = false,
    this.easyMode = false,
    this.languageCode,
  });

  /// Getaran sentuhan (disetel melalui [Haptics]).
  final bool haptics;

  /// Pengganda saiz teks di atas tetapan sistem; salah satu daripada [textScales].
  final double textScale;

  /// Kurangkan animasi walaupun sistem tidak memintanya.
  final bool reduceMotion;

  /// Mod mudah: teks sekurang-kurangnya 115%, HUD navigasi 25% lebih besar dan berkontras tinggi,
  /// kawalan sekunder disembunyikan semasa memandu (untuk warga emas dan yang lemah membaca peta).
  final bool easyMode;

  /// Pengganda saiz teks berkesan: Mod mudah tidak pernah lebih kecil daripada [easyModeMinScale].
  double get effectiveTextScale =>
      easyMode && textScale < easyModeMinScale ? easyModeMinScale : textScale;

  static const easyModeMinScale = 1.15;

  /// `ms`, `en`, atau null (ikut peranti).
  final String? languageCode;

  static const textScales = [0.9, 1.0, 1.15, 1.3];
  static const languages = ['ms', 'en'];

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  AppPreferences copyWith({
    bool? haptics,
    double? textScale,
    bool? reduceMotion,
    bool? easyMode,
    String? languageCode,
    bool clearLanguage = false,
  }) => AppPreferences(
    haptics: haptics ?? this.haptics,
    textScale: textScale ?? this.textScale,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    easyMode: easyMode ?? this.easyMode,
    languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
  );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.haptics == haptics &&
      other.textScale == textScale &&
      other.reduceMotion == reduceMotion &&
      other.easyMode == easyMode &&
      other.languageCode == languageCode;

  @override
  int get hashCode =>
      Object.hash(haptics, textScale, reduceMotion, easyMode, languageCode);
}

const _hapticsKey = 'app.haptics';
const _textScaleKey = 'app.textScale';
const _reduceMotionKey = 'app.reduceMotion';
const _easyModeKey = 'app.easyMode';
const _languageKey = 'app.language';

/// Membaca tetapan dari storan. Nilai luar julat/tidak dikenali kembali kepada lalai.
AppPreferences readAppPreferences(SharedPreferences prefs) {
  final scale = prefs.getDouble(_textScaleKey);
  final language = prefs.getString(_languageKey);
  return AppPreferences(
    haptics: prefs.getBool(_hapticsKey) ?? true,
    textScale: AppPreferences.textScales.contains(scale) ? scale! : 1.0,
    reduceMotion: prefs.getBool(_reduceMotionKey) ?? false,
    easyMode: prefs.getBool(_easyModeKey) ?? false,
    languageCode: AppPreferences.languages.contains(language) ? language : null,
  );
}

class AppPreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() {
    final value = readAppPreferences(ref.watch(sharedPreferencesProvider));
    Haptics.enabled = value.haptics;
    return value;
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> setHaptics(bool value) async {
    Haptics.enabled = value;
    state = state.copyWith(haptics: value);
    await _prefs.setBool(_hapticsKey, value);
  }

  Future<void> setTextScale(double value) async {
    if (!AppPreferences.textScales.contains(value)) return;
    state = state.copyWith(textScale: value);
    await _prefs.setDouble(_textScaleKey, value);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await _prefs.setBool(_reduceMotionKey, value);
  }

  Future<void> setEasyMode(bool value) async {
    state = state.copyWith(easyMode: value);
    await _prefs.setBool(_easyModeKey, value);
  }

  /// [code] null = ikut peranti.
  Future<void> setLanguage(String? code) async {
    if (code == null) {
      state = state.copyWith(clearLanguage: true);
      await _prefs.remove(_languageKey);
      return;
    }
    if (!AppPreferences.languages.contains(code)) return;
    state = state.copyWith(languageCode: code);
    await _prefs.setString(_languageKey, code);
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );
