import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/announcement_planner.dart';
import '../domain/instruction_text.dart';
import 'sound_synth.dart';

/// Pembantu suara navigasi: bunyi isyarat + arahan bersuara.
abstract interface class VoiceGuide {
  /// Menyampaikan [announcement]. Ayat `interrupt` memotong yang sedang disebut dan membuang
  /// yang beratur; yang lain beratur mengikut turutan.
  Future<void> announce(Announcement announcement, VoiceLanguage language);

  /// Berhenti serta-merta dan kosongkan baris gilir (cth. dimute atau navigasi tamat).
  Future<void> stop();

  Future<void> dispose();
}

/// Enjin TTS (disorok di belakang antara muka supaya baris gilir boleh diuji tanpa plugin).
abstract interface class TtsEngine {
  Future<void> speak(String text, VoiceLanguage language);
  Future<void> stop();
}

/// Pemain bunyi isyarat.
abstract interface class ChimePlayer {
  /// Selesai apabila bunyi habis dimainkan.
  Future<void> play(ChimeKind kind);
  Future<void> stop();
}

/// Baris gilir suara. Logik tulen: bunyi isyarat dahulu, kemudian ayat; ayat `interrupt`
/// membatalkan yang lama; baris gilir dihad supaya arahan tidak menyusut ketinggalan di belakang
/// kereta (arahan lama yang sudah tidak relevan dibuang).
class QueuedVoiceGuide implements VoiceGuide {
  QueuedVoiceGuide({
    required TtsEngine tts,
    required ChimePlayer chimes,
    this.maxQueued = 2,
  }) : _tts = tts,
       _chimes = chimes;

  final TtsEngine _tts;
  final ChimePlayer _chimes;
  final int maxQueued;

  final Queue<(Announcement, VoiceLanguage)> _queue = Queue();
  bool _running = false;
  int _generation = 0;
  bool _disposed = false;

  @override
  Future<void> announce(Announcement a, VoiceLanguage language) async {
    if (_disposed) return;
    if (a.interrupt) {
      _generation++;
      _queue.clear();
      await _haltAudio();
    } else {
      // Buang yang paling lama jika penuh; arahan terbaru lebih relevan.
      while (_queue.length >= maxQueued) {
        _queue.removeFirst();
      }
    }
    _queue.add((a, language));
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final generation = _generation;
        final (a, language) = _queue.removeFirst();
        try {
          final chime = a.chime;
          if (chime != null) await _chimes.play(chime);
          if (generation != _generation || _disposed) continue;
          if (a.text.isNotEmpty) await _tts.speak(a.text, language);
        } on Object catch (e) {
          // Kegagalan audio tidak boleh menjatuhkan navigasi.
          debugPrint('Suara navigasi gagal: $e');
        }
      }
    } finally {
      _running = false;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _queue.clear();
    await _haltAudio();
  }

  /// Hentikan TTS dan bunyi isyarat. Ralat plugin ditelan: pemanggil tidak menunggu hasilnya
  /// (`unawaited`) dan tamat navigasi tidak boleh gagal kerananya.
  Future<void> _haltAudio() async {
    try {
      await Future.wait([_tts.stop(), _chimes.stop()]);
    } on Object catch (e) {
      debugPrint('Menghentikan audio gagal: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}

/// TTS sebenar melalui `flutter_tts`, dikonfigurasi sebagai suara navigasi (menurunkan kelantangan
/// muzik, bukan menghentikannya).
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine({
    FlutterTts? tts,
    this.volume = _defaultVolume,
    this.speechRate = _defaultRate,
  }) : _tts = tts ?? FlutterTts();

  static double _defaultVolume() => 1.0;
  static double _defaultRate() => 0.5;

  /// Dibaca sebelum setiap ayat, jadi perubahan dalam Tetapan berkuat kuasa pada ayat seterusnya.
  final double Function() volume;
  final double Function() speechRate;

  final FlutterTts _tts;
  Future<void>? _ready;
  VoiceLanguage? _language;
  double? _appliedVolume;
  double? _appliedRate;

  Future<void> _configure() => _ready ??= () async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setPitch(1.0);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions
              .interruptSpokenAudioAndMixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.setAudioAttributesForNavigation();
    }
  }();

  @override
  Future<void> speak(String text, VoiceLanguage language) async {
    await _configure();
    final v = volume();
    if (_appliedVolume != v) {
      await _tts.setVolume(v);
      _appliedVolume = v;
    }
    final r = speechRate();
    if (_appliedRate != r) {
      await _tts.setSpeechRate(r);
      _appliedRate = r;
    }
    if (_language != language) {
      await _tts.setLanguage(language.ttsLocale);
      _language = language;
    }
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// Bunyi isyarat melalui `audioplayers`, dengan WAV yang dijana dalam kod dan di-cache.
class AudioplayersChimePlayer implements ChimePlayer {
  AudioplayersChimePlayer([AudioPlayer? player]) : _player = player;

  AudioPlayer? _player;
  final Map<ChimeKind, Uint8List> _cache = {};

  AudioPlayer get _p {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    created.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.assistanceNavigationGuidance,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );
    return _player = created;
  }

  @override
  Future<void> play(ChimeKind kind) async {
    final bytes = _cache.putIfAbsent(kind, () => synthChime(kind));
    await _p.play(BytesSource(bytes, mimeType: 'audio/wav'));
    // Tunggu bunyi habis supaya suara tidak bertindih dengannya.
    await Future<void>.delayed(Duration(milliseconds: chimeDurationMs(kind)));
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }
}
