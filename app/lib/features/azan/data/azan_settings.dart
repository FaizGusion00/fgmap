import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../domain/prayer.dart';

/// Tetapan Waktu Azan. Lalai: mati (pengguna menghidupkan sendiri), semua lima waktu, azan penuh,
/// kaedah JAKIM, mazhab Syafie, tiada peringatan awal, tidak main azan penuh semasa navigasi.
@immutable
class AzanSettings {
  const AzanSettings({
    this.enabled = false,
    this.prayers = const {
      Prayer.fajr,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    },
    this.sound = AzanSound.full,
    this.method = AzanMethod.jakim,
    this.madhab = AzanMadhab.shafi,
    this.reminderMinutes = 0,
    this.playDuringNavigation = false,
    this.cityName,
  });

  final bool enabled;
  final Set<Prayer> prayers;
  final AzanSound sound;
  final AzanMethod method;
  final AzanMadhab madhab;

  /// Minit sebelum waktu untuk peringatan; 0 = tiada. Salah satu daripada [reminderChoices].
  final int reminderMinutes;

  /// Semasa navigasi aktif: azan penuh (true) atau hanya bunyi pendek + cip HUD (false, lalai).
  final bool playDuringNavigation;

  /// Bandar pilihan manual (lihat `malaysia_cities.dart`); null = ikut lokasi peranti.
  final String? cityName;

  bool get useCity => cityName != null;

  static const reminderChoices = [0, 5, 10, 15];

  AzanSettings copyWith({
    bool? enabled,
    Set<Prayer>? prayers,
    AzanSound? sound,
    AzanMethod? method,
    AzanMadhab? madhab,
    int? reminderMinutes,
    bool? playDuringNavigation,
    String? cityName,
    bool clearCity = false,
  }) => AzanSettings(
    enabled: enabled ?? this.enabled,
    prayers: prayers ?? this.prayers,
    sound: sound ?? this.sound,
    method: method ?? this.method,
    madhab: madhab ?? this.madhab,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    playDuringNavigation: playDuringNavigation ?? this.playDuringNavigation,
    cityName: clearCity ? null : (cityName ?? this.cityName),
  );

  @override
  bool operator ==(Object other) =>
      other is AzanSettings &&
      other.enabled == enabled &&
      setEquals(other.prayers, prayers) &&
      other.sound == sound &&
      other.method == method &&
      other.madhab == madhab &&
      other.reminderMinutes == reminderMinutes &&
      other.playDuringNavigation == playDuringNavigation &&
      other.cityName == cityName;

  @override
  int get hashCode => Object.hash(
    enabled,
    Object.hashAllUnordered(prayers),
    sound,
    method,
    madhab,
    reminderMinutes,
    playDuringNavigation,
    cityName,
  );
}

const _enabledKey = 'azan.enabled';
const _prayersKey = 'azan.prayers';
const _soundKey = 'azan.sound';
const _methodKey = 'azan.method';
const _madhabKey = 'azan.madhab';
const _reminderKey = 'azan.reminderMin';
const _duringNavKey = 'azan.playDuringNav';
const _cityKey = 'azan.city';

class AzanSettingsController extends Notifier<AzanSettings> {
  @override
  AzanSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final names = prefs.getStringList(_prayersKey);
    final prayers = names == null
        ? null
        : {
            for (final n in names)
              if (Prayer.fromName(n) case final p? when p.notifiable) p,
          };
    final reminder = prefs.getInt(_reminderKey) ?? 0;
    return AzanSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      prayers: prayers ?? const AzanSettings().prayers,
      sound: AzanSound.fromName(prefs.getString(_soundKey)),
      method: AzanMethod.fromName(prefs.getString(_methodKey)),
      madhab: AzanMadhab.fromName(prefs.getString(_madhabKey)),
      reminderMinutes: AzanSettings.reminderChoices.contains(reminder)
          ? reminder
          : 0,
      playDuringNavigation: prefs.getBool(_duringNavKey) ?? false,
      cityName: prefs.getString(_cityKey),
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_enabledKey, value);
  }

  Future<void> setPrayer(Prayer prayer, bool on) async {
    if (!prayer.notifiable) return;
    final next = {...state.prayers};
    on ? next.add(prayer) : next.remove(prayer);
    state = state.copyWith(prayers: next);
    await ref.read(sharedPreferencesProvider).setStringList(_prayersKey, [
      for (final p in next) p.name,
    ]);
  }

  Future<void> setSound(AzanSound value) async {
    state = state.copyWith(sound: value);
    await ref.read(sharedPreferencesProvider).setString(_soundKey, value.name);
  }

  Future<void> setMethod(AzanMethod value) async {
    state = state.copyWith(method: value);
    await ref.read(sharedPreferencesProvider).setString(_methodKey, value.name);
  }

  Future<void> setMadhab(AzanMadhab value) async {
    state = state.copyWith(madhab: value);
    await ref.read(sharedPreferencesProvider).setString(_madhabKey, value.name);
  }

  Future<void> setReminderMinutes(int value) async {
    if (!AzanSettings.reminderChoices.contains(value)) return;
    state = state.copyWith(reminderMinutes: value);
    await ref.read(sharedPreferencesProvider).setInt(_reminderKey, value);
  }

  Future<void> setPlayDuringNavigation(bool value) async {
    state = state.copyWith(playDuringNavigation: value);
    await ref.read(sharedPreferencesProvider).setBool(_duringNavKey, value);
  }

  /// [name] null = ikut lokasi peranti.
  Future<void> setCity(String? name) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (name == null) {
      state = state.copyWith(clearCity: true);
      await prefs.remove(_cityKey);
    } else {
      state = state.copyWith(cityName: name);
      await prefs.setString(_cityKey, name);
    }
  }
}

final azanSettingsProvider =
    NotifierProvider<AzanSettingsController, AzanSettings>(
      AzanSettingsController.new,
    );
