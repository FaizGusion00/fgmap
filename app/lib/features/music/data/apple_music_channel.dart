import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/utils/log.dart';
import '../domain/apple_music.dart';
import '../domain/music_repository.dart';
import '../domain/player_state.dart';
import '../domain/track.dart';

const appleMusicMethodChannel = MethodChannel('fgmaps/apple_music');
const appleMusicEventChannel = EventChannel('fgmaps/apple_music/events');

/// Penanda sahaja: lagu Apple Music dimain oleh MusicKit (DRM), bukan oleh app melalui URL.
Uri appleMusicMarker(String id) =>
    Uri(scheme: 'applemusic', host: 'song', path: '/$id');

/// Menghurai senarai lagu daripada jambatan natif. Fungsi tulen untuk ujian. Gambar hanya HTTPS
/// (ADR 0010); entri tanpa id atau tajuk dilangkau.
List<Track> parseAppleSongs(Object? json) {
  if (json is! List) return const [];
  final out = <Track>[];
  for (final item in json) {
    if (item is! Map) continue;
    final id = item['id'];
    final title = item['title'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty) {
      continue;
    }
    final art = Uri.tryParse(item['artwork'] as String? ?? '');
    final ms = item['durationMs'];
    final artist = (item['artist'] as String?)?.trim();
    out.add(
      Track(
        id: id,
        source: TrackSource.appleMusic,
        title: title.trim(),
        artist: artist == null || artist.isEmpty ? null : artist,
        streamUri: appleMusicMarker(id),
        artworkUri: art != null && art.scheme == 'https' ? art : null,
        duration: ms is num ? Duration(milliseconds: ms.round()) : null,
      ),
    );
  }
  return out;
}

AppleMusicStatus parseAppleStatus(Object? json) {
  if (json is! Map) return const AppleMusicStatus();
  return AppleMusicStatus(
    access: AppleMusicAccess.fromName(json['authorization']),
    canPlay: json['canPlay'] == true,
    canBecomeSubscriber: json['canBecomeSubscriber'] == true,
  );
}

/// Gambar pemain natif -> [EngineSnapshot]. [queue] memetakan id lagu semasa ke indeks baris
/// gilir; jika tidak dikenali, [fallbackIndex] kekal.
EngineSnapshot? parseApplePlayer(
  Object? json, {
  required List<Track> queue,
  required int fallbackIndex,
}) {
  if (json is! Map) return null;
  final status = switch (json['status']) {
    'playing' => PlayerStatus.playing,
    'paused' => PlayerStatus.paused,
    'loading' => PlayerStatus.loading,
    _ => PlayerStatus.idle,
  };
  final id = json['id'];
  var index = fallbackIndex;
  if (id is String) {
    final i = queue.indexWhere((t) => t.id == id);
    if (i >= 0) index = i;
  }
  final ms = json['durationMs'];
  final pos = json['positionMs'];
  return EngineSnapshot(
    status: status,
    index: index,
    position: Duration(milliseconds: pos is num ? pos.round() : 0),
    duration: ms is num
        ? Duration(milliseconds: ms.round())
        : (index < queue.length ? queue[index].duration : null),
  );
}

class ChannelAppleMusicRepository implements AppleMusicRepository {
  ChannelAppleMusicRepository({MethodChannel? channel})
    : _channel = channel ?? appleMusicMethodChannel;

  final MethodChannel _channel;

  @override
  bool get supported => true;

  @override
  Future<AppleMusicStatus> status() async {
    try {
      return parseAppleStatus(await _channel.invokeMethod<Object?>('status'));
    } on PlatformException catch (e) {
      logDiag('Apple Music status gagal: ${e.message}');
      return const AppleMusicStatus();
    }
  }

  @override
  Future<AppleMusicStatus> authorize() async {
    try {
      return parseAppleStatus(
        await _channel.invokeMethod<Object?>('authorize'),
      );
    } on PlatformException catch (e) {
      logDiag('Apple Music kebenaran gagal: ${e.message}');
      return const AppleMusicStatus();
    }
  }

  @override
  Future<List<Track>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final res = await _channel.invokeMethod<Object?>('search', {
      'term': q,
      'limit': 25,
    });
    return parseAppleSongs(res);
  }
}

/// Platform tanpa MusicKit (Android) atau ciri ditutup: tiada apa-apa dipaparkan.
class UnavailableAppleMusicRepository implements AppleMusicRepository {
  const UnavailableAppleMusicRepository();

  @override
  bool get supported => false;

  @override
  Future<AppleMusicStatus> status() async => AppleMusicStatus.unsupported;

  @override
  Future<AppleMusicStatus> authorize() async => AppleMusicStatus.unsupported;

  @override
  Future<List<Track>> search(String query) async => const [];
}

/// Enjin yang memainkan baris gilir [TrackSource.appleMusic] melalui MusicKit. Tiada kawalan kelantangan
/// (MusicKit tidak mendedahkannya) dan tiada penyama; pengawal menjeda semasa suara navigasi.
class AppleMusicEngine implements MusicEngine {
  AppleMusicEngine({MethodChannel? channel, EventChannel? events})
    : _channel = channel ?? appleMusicMethodChannel,
      _events = events ?? appleMusicEventChannel;

  final MethodChannel _channel;
  final EventChannel _events;
  final _snapshots = StreamController<EngineSnapshot>.broadcast();
  StreamSubscription<Object?>? _sub;
  List<Track> _queue = const [];
  int _index = 0;

  @override
  Stream<EngineSnapshot> get snapshots => _snapshots.stream;

  void _listen() {
    _sub ??= _events.receiveBroadcastStream().listen(
      (event) {
        final s = parseApplePlayer(event, queue: _queue, fallbackIndex: _index);
        if (s == null || _queue.isEmpty) return;
        _index = s.index ?? _index;
        _snapshots.add(s);
      },
      onError: (Object e) {
        logDiag('Apple Music peristiwa ralat: $e');
        _snapshots.add(
          EngineSnapshot(
            status: PlayerStatus.error,
            index: _index,
            error: e.toString(),
          ),
        );
      },
    );
  }

  @override
  Future<void> setQueue(List<Track> tracks, int startIndex) async {
    _queue = tracks;
    _index = startIndex;
    _listen();
    await _channel.invokeMethod<Object?>('setQueue', {
      'ids': [for (final t in tracks) t.id],
      'startIndex': startIndex,
    });
  }

  @override
  Future<void> play() => _channel.invokeMethod<void>('play');

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> stop() async {
    _queue = const [];
    await _channel.invokeMethod<void>('stop');
  }

  @override
  Future<void> seek(Duration position) => _channel.invokeMethod<void>('seek', {
    'positionMs': position.inMilliseconds,
  });

  @override
  Future<void> seekToIndex(int index) async {
    if (index == _index + 1) {
      await _channel.invokeMethod<void>('next');
    } else if (index == _index - 1) {
      await _channel.invokeMethod<void>('previous');
    } else {
      await setQueue(_queue, index);
    }
    _index = index;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gainsDb,
  }) async {}

  @override
  bool get equalizerSupported => false;

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _snapshots.close();
  }
}
