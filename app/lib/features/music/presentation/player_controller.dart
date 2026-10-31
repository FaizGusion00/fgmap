import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_coordinator.dart';
import '../../../core/utils/log.dart';
import '../data/apple_music_channel.dart';
import '../data/just_audio_engine.dart';
import '../data/music_audio_handler.dart';
import '../data/music_settings.dart';
import '../data/radio_browser_repository.dart';
import '../data/radio_health.dart';
import '../data/routing_music_engine.dart';
import '../domain/music_repository.dart';
import '../domain/player_state.dart';
import '../domain/stream_title.dart';
import '../domain/track.dart';
import 'apple_music_controller.dart';

/// Enjin audio; ditimpa dengan palsu dalam ujian. just_audio untuk radio, Audius dan fail; MusicKit
/// untuk Apple Music (iOS sahaja).
final musicEngineProvider = Provider<MusicEngine>((ref) {
  final engine = RoutingMusicEngine(
    justAudio: JustAudioEngine(),
    apple: appleMusicPlatformSupported ? AppleMusicEngine() : null,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Pemula perkhidmatan audio (kawalan skrin kunci); null dalam ujian.
final audioServiceStarterProvider = Provider<AudioServiceStarter?>(
  (ref) => AudioServiceStarter(),
);

/// Mesin keadaan pemain + dasar memberi laluan kepada suara navigasi.
///
/// idle -> loading (playTrack) -> playing | error; playing <-> paused (toggle); playing ->
/// buffering -> playing; mana-mana -> idle (stop). `ducked` dipasang semasa suara navigasi.
class PlayerController extends Notifier<PlayerState> implements DuckTarget {
  StreamSubscription<EngineSnapshot>? _sub;
  bool _resumeAfterSpeech = false;
  bool _serviceStarted = false;
  static const duckVolume = 0.2;

  @override
  PlayerState build() {
    final engine = ref.watch(musicEngineProvider);
    final coordinator = ref.read(audioCoordinatorProvider)..register(this);
    _sub = engine.snapshots.listen(_onSnapshot);
    ref.onDispose(() {
      coordinator.unregister(this);
      unawaited(_sub?.cancel());
    });
    // Penyama mengikut tetapan tersimpan; perubahan seterusnya dipakai oleh pengawal tetapan.
    unawaited(ref.read(musicSettingsProvider.notifier).applyEqualizer());
    return const PlayerState();
  }

  void _onSnapshot(EngineSnapshot s) {
    if (state.status == PlayerStatus.idle && s.status == PlayerStatus.idle) {
      return;
    }
    var next = state.copyWith(
      status: s.status,
      position: s.position,
      duration: s.duration,
      clearDuration: s.duration == null,
      error: s.error,
      clearError: s.error == null,
    );
    final idx = s.index;
    if (idx != null && idx != state.index && idx < state.queue.length) {
      next = next.copyWith(index: idx);
      _countRadioClick(state.queue[idx]);
    }
    final current = next.current;
    final song = current != null && current.isLive
        ? cleanStreamTitle(s.nowPlaying, station: current.title)
        : null;
    next = next.copyWith(nowPlaying: song, clearNowPlaying: song == null);
    state = next;
    _recordHealth(current, s.status);
  }

  /// Ingat stesen yang gagal (dan lupakan apabila ia berjaya main) supaya senarai Radio
  /// membenamkan stesen mati pada peranti ini.
  void _recordHealth(Track? t, PlayerStatus status) {
    if (t == null || !t.isLive) return;
    final health = ref.read(radioHealthProvider.notifier);
    if (status == PlayerStatus.error) {
      unawaited(health.markFailed(t));
    } else if (status == PlayerStatus.playing) {
      unawaited(health.markOk(t));
    }
  }

  MusicEngine get _engine => ref.read(musicEngineProvider);

  /// MusicKit mengurus Now Playing/skrin kunci sendiri, jadi perkhidmatan audio (yang membungkus
  /// just_audio) hanya dimulakan untuk lagu yang dimain oleh just_audio.
  Future<void> _ensureService(Track track) async {
    if (_serviceStarted || _isApple(track)) return;
    _serviceStarted = true;
    final engine = _engine;
    final starter = ref.read(audioServiceStarterProvider);
    if (starter != null &&
        engine is RoutingMusicEngine &&
        engine.justAudio is JustAudioEngine) {
      await starter.ensureStarted((engine.justAudio as JustAudioEngine).player);
    }
  }

  static bool _isApple(Track t) => t.source == TrackSource.appleMusic;

  /// MusicKit tiada kawalan kelantangan, jadi suara navigasi menjeda lagu Apple Music dan bukan
  /// memperlahankannya.
  bool get _canSetVolume {
    final current = state.current;
    return current == null || !_isApple(current);
  }

  /// Main [track]; [queue] (mengandungi track) menjadi baris gilir, jika tidak hanya lagu ini. Baris
  /// gilir hanya mengekalkan lagu yang dimain oleh enjin yang sama (Apple Music tidak boleh bercampur
  /// dengan Audius dalam satu baris gilir).
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final list = queue != null && queue.contains(track)
        ? [
            for (final t in queue)
              if (_isApple(t) == _isApple(track)) t,
          ]
        : [track];
    final index = list.indexOf(track);
    state = state.copyWith(
      status: PlayerStatus.loading,
      queue: list,
      index: index,
      position: Duration.zero,
      clearDuration: true,
      clearError: true,
    );
    try {
      await _ensureService(track);
      await _engine.setQueue(list, index);
      if (!_isApple(track)) {
        await _engine.setVolume(state.ducked ? duckVolume : state.volume);
      }
      _countRadioClick(track);
      await _engine.play();
    } on Object catch (e) {
      logDiag('Main muzik gagal: $e');
      state = state.copyWith(status: PlayerStatus.error, error: e.toString());
      _recordHealth(track, PlayerStatus.error);
    }
  }

  void _countRadioClick(Track t) {
    final uuid = t.radioUuid;
    if (t.source == TrackSource.radio && uuid != null) {
      unawaited(ref.read(radioRepositoryProvider).countClick(uuid));
    }
  }

  Future<void> toggle() async {
    if (state.current == null) return;
    if (state.isPlaying) {
      _resumeAfterSpeech = false;
      await _engine.pause();
    } else {
      await _engine.play();
    }
  }

  Future<void> next() async {
    if (!state.hasNext) return;
    await _engine.seekToIndex(state.index + 1);
    await _engine.play();
  }

  Future<void> previous() async {
    // Seperti pemain biasa: jika > 3 saat masuk, ulang dari awal.
    if (state.position > const Duration(seconds: 3) || !state.hasPrevious) {
      await _engine.seek(Duration.zero);
      return;
    }
    await _engine.seekToIndex(state.index - 1);
    await _engine.play();
  }

  Future<void> seek(Duration position) async {
    if (state.current?.isLive ?? true) return;
    await _engine.seek(position);
  }

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: v);
    if (!state.ducked && _canSetVolume) await _engine.setVolume(v);
  }

  Future<void> stop() async {
    _resumeAfterSpeech = false;
    await _engine.stop();
    state = const PlayerState();
  }

  @override
  Future<void> onSpeechStart() async {
    if (state.current == null) return;
    final mode = ref.read(musicSettingsProvider).duckMode;
    state = state.copyWith(ducked: true);
    if (mode == DuckMode.pause || !_canSetVolume) {
      if (state.isPlaying) {
        _resumeAfterSpeech = true;
        await _engine.pause();
      }
    } else {
      await _engine.setVolume(duckVolume * state.volume);
    }
  }

  @override
  Future<void> onSpeechEnd() async {
    if (!state.ducked) return;
    state = state.copyWith(ducked: false);
    if (_canSetVolume) await _engine.setVolume(state.volume);
    if (_resumeAfterSpeech) {
      _resumeAfterSpeech = false;
      await _engine.play();
    }
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
