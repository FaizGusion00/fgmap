import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../../core/utils/log.dart';
import '../domain/stream_title.dart';

/// Pengendali `audio_service`: kawalan skrin kunci / notifikasi media dan butang fon telinga,
/// dipetakan terus kepada pemain just_audio. Dimulakan malas pada main pertama (kos permulaan sifar).
class FgMusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  FgMusicAudioHandler(this._player) {
    _player.playbackEventStream.map(_transform).pipe(playbackState);
    _player.sequenceStateStream.listen((state) {
      final tag = state.currentSource?.tag;
      if (tag is MediaItem) mediaItem.add(tag);
      queue.add([
        for (final s in state.sequence)
          if (s.tag is MediaItem) s.tag as MediaItem,
      ]);
    });
    // Radio langsung: skrin kunci memaparkan lagu yang sedang bersiaran (stesen sebagai artis).
    _player.icyMetadataStream.listen((m) {
      final tag = _player.sequenceState.currentSource?.tag;
      if (tag is! MediaItem || tag.isLive != true) return;
      final song = cleanStreamTitle(m?.info?.title, station: tag.title);
      mediaItem.add(
        song == null ? tag : tag.copyWith(title: song, artist: tag.title),
      );
    });
  }

  final ja.AudioPlayer _player;

  PlaybackState _transform(ja.PlaybackEvent event) {
    final playing = _player.playing;
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ja.ProcessingState.idle: AudioProcessingState.idle,
        ja.ProcessingState.loading: AudioProcessingState.loading,
        ja.ProcessingState.buffering: AudioProcessingState.buffering,
        ja.ProcessingState.ready: AudioProcessingState.ready,
        ja.ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);
}

/// `AudioService.init` hanya boleh dipanggil sekali. Dipanggil malas supaya pengguna yang tidak
/// pernah membuka Muzik tidak membayar kos perkhidmatan latar.
class AudioServiceStarter {
  Future<FgMusicAudioHandler?>? _pending;

  Future<FgMusicAudioHandler?> ensureStarted(ja.AudioPlayer player) =>
      _pending ??= () async {
        try {
          return await AudioService.init(
            builder: () => FgMusicAudioHandler(player),
            config: const AudioServiceConfig(
              androidNotificationChannelId:
                  'com.fguniversalempire.fgmaps.channel.music',
              androidNotificationChannelName: 'Muzik',
              androidNotificationOngoing: true,
              androidStopForegroundOnPause: true,
            ),
          );
        } on Object catch (e) {
          logDiag('audio_service gagal dimulakan: $e');
          return null;
        }
      }();
}
