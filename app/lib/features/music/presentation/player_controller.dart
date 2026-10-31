import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_coordinator.dart';
import '../../../core/utils/log.dart';
import '../data/just_audio_engine.dart';
import '../data/music_audio_handler.dart';
import '../data/music_settings.dart';
import '../data/radio_browser_repository.dart';
import '../domain/music_repository.dart';
import '../domain/player_state.dart';
import '../domain/track.dart';

/// Enjin audio; ditimpa dengan palsu dalam ujian.
final musicEngineProvider = Provider<MusicEngine>((ref) {
  final engine = JustAudioEngine();
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
    state = next;
  }

  MusicEngine get _engine => ref.read(musicEngineProvider);

  Future<void> _ensureService() async {
    if (_serviceStarted) return;
    _serviceStarted = true;
    final engine = _engine;
    final starter = ref.read(audioServiceStarterProvider);
    if (starter != null && engine is JustAudioEngine) {
      await starter.ensureStarted(engine.player);
    }
  }

  /// Main [track]; [queue] (mengandungi track) menjadi baris gilir, jika tidak hanya lagu ini.
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final list = queue != null && queue.contains(track) ? queue : [track];
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
      await _ensureService();
      await _engine.setQueue(list, index);
      await _engine.setVolume(state.ducked ? duckVolume : state.volume);
      _countRadioClick(track);
      await _engine.play();
    } on Object catch (e) {
      logDiag('Main muzik gagal: $e');
      state = state.copyWith(status: PlayerStatus.error, error: e.toString());
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
    if (!state.ducked) await _engine.setVolume(v);
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
    if (mode == DuckMode.pause) {
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
    await _engine.setVolume(state.volume);
    if (_resumeAfterSpeech) {
      _resumeAfterSpeech = false;
      await _engine.play();
    }
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
