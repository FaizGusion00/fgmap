import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/platform/system_settings.dart';
import '../../../core/utils/log.dart';
import '../domain/instruction_text.dart';

/// Status suara navigasi tanpa internet bagi satu bahasa.
enum OfflineVoiceStatus {
  /// Data suara ada dalam telefon: arahan bersuara berfungsi tanpa internet.
  installed,

  /// Tiada suara luar talian: tanpa internet arahan mungkin senyap atau dalam bahasa lain.
  missing,

  /// Tidak dapat ditentukan (platform lain / ralat).
  unknown,
}

/// Penyemak suara TTS luar talian. Antara muka supaya ujian tidak memerlukan plugin.
abstract interface class OfflineVoiceProbe {
  Future<OfflineVoiceStatus> status(VoiceLanguage language);

  /// Buka skrin muat turun suara sistem.
  Future<bool> openInstaller();
}

class FlutterTtsVoiceProbe implements OfflineVoiceProbe {
  FlutterTtsVoiceProbe(this._settings, [FlutterTts? tts]) : _ttsOrNull = tts;

  final SystemSettings _settings;
  FlutterTts? _ttsOrNull;
  FlutterTts get _tts => _ttsOrNull ??= FlutterTts();

  @override
  Future<OfflineVoiceStatus> status(VoiceLanguage language) async {
    if (kIsWeb) return OfflineVoiceStatus.unknown;
    try {
      if (Platform.isAndroid) {
        // Benar hanya jika ada suara bagi locale ini yang TIDAK perlukan rangkaian dan datanya dipasang.
        final installed = await _tts.isLanguageInstalled(language.ttsLocale);
        return installed == true
            ? OfflineVoiceStatus.installed
            : OfflineVoiceStatus.missing;
      }
      if (Platform.isIOS) {
        // AVSpeechSynthesizer sentiasa dalam peranti; soalannya hanya sama ada suara bahasa itu wujud.
        final available = await _tts.isLanguageAvailable(language.ttsLocale);
        return available == true
            ? OfflineVoiceStatus.installed
            : OfflineVoiceStatus.missing;
      }
    } on Object catch (e) {
      logDiag('Status suara offline gagal: $e');
    }
    return OfflineVoiceStatus.unknown;
  }

  @override
  Future<bool> openInstaller() => _settings.openTtsSettings();
}

/// Suara luar talian terbaik untuk [language] daripada senarai `getVoices` Android (peta dengan
/// `name`, `locale`, `network_required`, `features`, `quality`), atau null jika tiada. Kualiti tertinggi
/// dahulu.
Map<String, String>? pickOfflineVoice(Object? voices, VoiceLanguage language) {
  if (voices is! List) return null;
  const rank = {
    'very high': 5,
    'high': 4,
    'normal': 3,
    'low': 2,
    'very low': 1,
  };
  Map<String, String>? best;
  var bestScore = -1;
  for (final v in voices) {
    if (v is! Map) continue;
    final name = v['name'];
    final locale = v['locale'];
    if (name is! String || locale is! String) continue;
    final lang = locale.toLowerCase().replaceAll('_', '-');
    final want = language.ttsLocale.toLowerCase();
    final sameLanguage = lang == want || lang.split('-').first == language.code;
    if (!sameLanguage) continue;
    if (v['network_required'] != '0') continue;
    final features = v['features'];
    if (features is String && features.contains('notInstalled')) continue;
    // Locale tepat (ms-MY) mengatasi bahasa sama negara lain (ms-SG).
    final score = (rank[v['quality']] ?? 0) * 2 + (lang == want ? 1 : 0);
    if (score > bestScore) {
      bestScore = score;
      best = {'name': name, 'locale': locale};
    }
  }
  return best;
}

final offlineVoiceProbeProvider = Provider<OfflineVoiceProbe>(
  (ref) => FlutterTtsVoiceProbe(ref.watch(systemSettingsProvider)),
);

final offlineVoiceStatusProvider = FutureProvider.autoDispose
    .family<OfflineVoiceStatus, VoiceLanguage>(
      (ref, language) => ref.watch(offlineVoiceProbeProvider).status(language),
    );
