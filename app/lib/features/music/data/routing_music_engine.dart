import 'dart:async';

import '../domain/music_repository.dart';
import '../domain/player_state.dart';
import '../domain/track.dart';

/// Memilih enjin mengikut sumber lagu: [TrackSource.appleMusic] dimain oleh MusicKit ([apple]),
/// yang lain oleh just_audio. Hanya satu enjin aktif pada satu masa; menukar enjin menghentikan
/// yang sebelumnya. Gambar keadaan daripada enjin yang tidak aktif dibuang supaya ia tidak
/// menimpa pemain yang sedang berbunyi.
class RoutingMusicEngine implements MusicEngine {
  RoutingMusicEngine({required this.justAudio, this.apple})
    : _active = justAudio {
    _subs.add(justAudio.snapshots.listen((s) => _forward(justAudio, s)));
    final a = apple;
    if (a != null) _subs.add(a.snapshots.listen((s) => _forward(a, s)));
  }

  /// Enjin untuk radio, Audius dan fail (just_audio dalam app sebenar).
  final MusicEngine justAudio;

  /// Null apabila platform tiada MusicKit.
  final MusicEngine? apple;

  MusicEngine _active;
  final _out = StreamController<EngineSnapshot>.broadcast();
  final _subs = <StreamSubscription<EngineSnapshot>>[];

  @override
  Stream<EngineSnapshot> get snapshots => _out.stream;

  void _forward(MusicEngine from, EngineSnapshot s) {
    if (identical(from, _active)) _out.add(s);
  }

  MusicEngine _engineFor(Track t) {
    if (t.source != TrackSource.appleMusic) return justAudio;
    final a = apple;
    if (a == null) {
      throw StateError('Apple Music tidak tersedia pada platform ini');
    }
    return a;
  }

  @override
  Future<void> setQueue(List<Track> tracks, int startIndex) async {
    final target = _engineFor(tracks[startIndex]);
    if (!identical(target, _active)) {
      final previous = _active;
      _active = target;
      await previous.stop();
    }
    await target.setQueue(tracks, startIndex);
  }

  @override
  Future<void> play() => _active.play();

  @override
  Future<void> pause() => _active.pause();

  @override
  Future<void> stop() => _active.stop();

  @override
  Future<void> seek(Duration position) => _active.seek(position);

  @override
  Future<void> seekToIndex(int index) => _active.seekToIndex(index);

  @override
  Future<void> setVolume(double volume) => _active.setVolume(volume);

  /// Penyama hanya untuk just_audio (Android); tetapan dipakai pada enjin itu walaupun MusicKit
  /// sedang aktif supaya ia sedia apabila pengguna kembali ke radio atau Audius.
  @override
  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gainsDb,
  }) => justAudio.setEqualizer(enabled: enabled, gainsDb: gainsDb);

  @override
  bool get equalizerSupported => justAudio.equalizerSupported;

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _out.close();
    await justAudio.dispose();
    await apple?.dispose();
  }
}
