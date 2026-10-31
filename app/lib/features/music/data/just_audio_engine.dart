import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../../core/utils/log.dart';
import '../domain/eq.dart';
import '../domain/music_repository.dart';
import '../domain/player_state.dart';
import '../domain/track.dart';

/// Enjin sebenar: `just_audio` dengan penyama Android dalam saluran paip audio.
///
/// `handleInterruptions: false`: penyelaras Dart ([AudioCoordinator]) yang berkuasa untuk suara
/// navigasi kita sendiri, supaya tidak diperlahankan dua kali. Gangguan luar (panggilan telefon,
/// app lain) dikendalikan oleh sesi audio di bawah.
class JustAudioEngine implements MusicEngine {
  JustAudioEngine({ja.AudioPlayer? player, ja.AndroidEqualizer? equalizer})
    : _eq = equalizer ?? (_isAndroid ? ja.AndroidEqualizer() : null) {
    _player =
        player ??
        ja.AudioPlayer(
          handleInterruptions: false,
          audioPipeline: ja.AudioPipeline(
            androidAudioEffects: [if (_eq != null) _eq],
          ),
        );
    _wire();
  }

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  late final ja.AudioPlayer _player;
  final ja.AndroidEqualizer? _eq;
  final _snapshots = StreamController<EngineSnapshot>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  Future<void>? _session;
  bool _externalPause = false;

  PlayerStatus _status = PlayerStatus.idle;
  int? _index;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _error;
  String? _nowPlaying;

  void _wire() {
    _subs.add(
      _player.playerStateStream.listen((s) {
        _status = switch (s.processingState) {
          ja.ProcessingState.idle => PlayerStatus.idle,
          ja.ProcessingState.loading => PlayerStatus.loading,
          ja.ProcessingState.buffering => PlayerStatus.buffering,
          ja.ProcessingState.ready =>
            s.playing ? PlayerStatus.playing : PlayerStatus.paused,
          ja.ProcessingState.completed => PlayerStatus.paused,
        };
        _emit();
      }),
    );
    _subs.add(
      _player.currentIndexStream.listen((i) {
        _index = i;
        _nowPlaying =
            null; // tajuk stesen sebelumnya tidak boleh bocor ke stesen baharu
        _emit();
      }),
    );
    _subs.add(
      _player.icyMetadataStream.listen((m) {
        _nowPlaying = m?.info?.title;
        _emit();
      }),
    );
    _subs.add(
      _player.durationStream.listen((d) {
        _duration = d;
        _emit();
      }),
    );
    _subs.add(
      _player.positionStream.listen((p) {
        _position = p;
        _emit();
      }),
    );
    _subs.add(
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object e) {
          _error = e.toString();
          _status = PlayerStatus.error;
          _emit();
          logDiag('Pemain muzik ralat: $e');
        },
      ),
    );
  }

  void _emit() => _snapshots.add(
    EngineSnapshot(
      status: _status,
      index: _index,
      position: _position,
      duration: _duration,
      error: _error,
      nowPlaying: _nowPlaying,
    ),
  );

  /// Sesi audio "muzik" dikongsi untuk app; dikonfigurasi sekali sebelum main pertama.
  Future<void> _ensureSession() => _session ??= () async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _subs.add(
        session.interruptionEventStream.listen((event) {
          // Panggilan telefon / app lain: jeda dan sambung semula bila tamat.
          if (event.begin) {
            if (event.type != AudioInterruptionType.duck && _player.playing) {
              _externalPause = true;
              unawaited(_player.pause());
            }
          } else if (event.type == AudioInterruptionType.pause &&
              _externalPause) {
            _externalPause = false;
            unawaited(_player.play());
          }
        }),
      );
      _subs.add(
        session.becomingNoisyEventStream.listen((_) {
          // Fon telinga dicabut: jangan tiba-tiba kuat di pembesar suara.
          unawaited(_player.pause());
        }),
      );
    } on Object catch (e) {
      logDiag('Sesi audio gagal dikonfigurasi: $e');
    }
  }();

  @override
  Stream<EngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> setQueue(List<Track> tracks, int startIndex) async {
    await _ensureSession();
    _error = null;
    _nowPlaying = null;
    await _player.setAudioSources(
      [
        for (final t in tracks)
          ja.AudioSource.uri(
            t.streamUri,
            tag: MediaItem(
              id: t.key,
              title: t.title,
              artist: t.artist,
              artUri: t.artworkUri,
              duration: t.duration,
              isLive: t.isLive,
            ),
          ),
      ],
      initialIndex: startIndex.clamp(0, tracks.isEmpty ? 0 : tracks.length - 1),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekToIndex(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  bool get equalizerSupported => _eq != null;

  @override
  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gainsDb,
  }) async {
    final eq = _eq;
    if (eq == null) return;
    try {
      await eq.setEnabled(enabled);
      if (!enabled) return;
      final params = await eq.parameters;
      final mapped = mapGainsToBands(
        gainsDb,
        deviceBands: params.bands.length,
        minDb: params.minDecibels,
        maxDb: params.maxDecibels,
      );
      for (var i = 0; i < params.bands.length; i++) {
        await params.bands[i].setGain(mapped[i]);
      }
    } on Object catch (e) {
      logDiag('Penyama gagal: $e');
    }
  }

  /// Pemain mentah untuk pengendali `audio_service`.
  ja.AudioPlayer get player => _player;

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _snapshots.close();
  }
}
