import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/log.dart';
import '../../navigation/data/sound_synth.dart';
import '../../navigation/domain/announcement_planner.dart';
import '../domain/prayer.dart';

/// Memainkan azan dalam app (apabila app terbuka pada waktu solat). Notifikasi OS mengendalikan kes
/// app ditutup.
abstract interface class AzanPlayer {
  Future<void> play(AzanSound sound);
  Future<void> stop();

  /// Tamat main (semula jadi atau dihentikan).
  Stream<void> get completed;
}

class AudioplayersAzanPlayer implements AzanPlayer {
  AudioplayersAzanPlayer([AudioPlayer? player]) : _player = player;

  AudioPlayer? _player;
  final _completed = StreamController<void>.broadcast();
  StreamSubscription<void>? _sub;

  AudioPlayer get _p {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    created.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.music,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );
    _sub = created.onPlayerComplete.listen((_) => _completed.add(null));
    return _player = created;
  }

  @override
  Future<void> play(AzanSound sound) async {
    try {
      switch (sound) {
        case AzanSound.full:
          await _p.play(AssetSource('audio/azan.mp3'));
        case AzanSound.short:
          await _p.play(
            BytesSource(synthChime(ChimeKind.now), mimeType: 'audio/wav'),
          );
        case AzanSound.silent:
          _completed.add(null);
      }
    } on Object catch (e) {
      logDiag('Azan gagal dimainkan: $e');
      _completed.add(null);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } on Object catch (e) {
      logDiag('Menghentikan azan gagal: $e');
    }
    _completed.add(null);
  }

  @override
  Stream<void> get completed => _completed.stream;

  Future<void> dispose() async {
    await _sub?.cancel();
    await _player?.dispose();
    await _completed.close();
  }
}

final azanPlayerProvider = Provider<AzanPlayer>((ref) {
  final player = AudioplayersAzanPlayer();
  ref.onDispose(player.dispose);
  return player;
});
