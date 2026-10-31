import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';

/// Kunci: opt-in FGMuslim AI + versi T&C yang dipersetujui.
const muslimAiEnabledKey = 'assistant.muslim.enabled';
const muslimAiTermsVersionKey = 'assistant.muslim.termsVersion';
const muslimAiChatPrefsKey = 'assistant.muslim.chat.v1';

/// Naikkan bila teks T&C berubah — pengguna mesti bersetuju semula.
const muslimAiTermsVersion = 1;

@immutable
class MuslimAiSettings {
  const MuslimAiSettings({
    this.enabled = false,
    this.agreedTermsVersion = 0,
  });

  final bool enabled;
  final int agreedTermsVersion;

  bool get isActive => enabled && agreedTermsVersion >= muslimAiTermsVersion;

  MuslimAiSettings copyWith({bool? enabled, int? agreedTermsVersion}) =>
      MuslimAiSettings(
        enabled: enabled ?? this.enabled,
        agreedTermsVersion: agreedTermsVersion ?? this.agreedTermsVersion,
      );
}

MuslimAiSettings readMuslimAiSettings(SharedPreferences prefs) =>
    MuslimAiSettings(
      enabled: prefs.getBool(muslimAiEnabledKey) ?? false,
      agreedTermsVersion: prefs.getInt(muslimAiTermsVersionKey) ?? 0,
    );

class MuslimAiSettingsController extends Notifier<MuslimAiSettings> {
  @override
  MuslimAiSettings build() =>
      readMuslimAiSettings(ref.watch(sharedPreferencesProvider));

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// Aktifkan hanya selepas pengguna menanda semua syarat dan bersetuju.
  Future<void> enableAfterAgreement() async {
    await _prefs.setBool(muslimAiEnabledKey, true);
    await _prefs.setInt(muslimAiTermsVersionKey, muslimAiTermsVersion);
    state = state.copyWith(
      enabled: true,
      agreedTermsVersion: muslimAiTermsVersion,
    );
  }

  Future<void> disable() async {
    await _prefs.setBool(muslimAiEnabledKey, false);
    state = state.copyWith(enabled: false);
  }
}

final muslimAiSettingsProvider =
    NotifierProvider<MuslimAiSettingsController, MuslimAiSettings>(
      MuslimAiSettingsController.new,
    );
