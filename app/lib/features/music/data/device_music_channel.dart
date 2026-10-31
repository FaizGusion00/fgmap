import 'package:flutter/services.dart';

import '../domain/device_music.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';

const deviceMusicChannel = MethodChannel('fgmaps/device_music');

/// Skema URI yang boleh dimain terus daripada peranti. Selain ini ditolak (tiada `http`: lagu
/// peranti tidak pernah datang dari rangkaian).
const _playableSchemes = {'content', 'file', 'ipod-library'};

/// Menghurai senarai lagu daripada jambatan natif. Fungsi tulen untuk ujian.
List<Track> parseDeviceSongs(Object? json) {
  if (json is! List) return const [];
  final out = <Track>[];
  for (final item in json) {
    if (item is! Map) continue;
    final id = item['id'];
    final title = item['title'];
    final uri = Uri.tryParse(item['uri'] as String? ?? '');
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        uri == null ||
        !_playableSchemes.contains(uri.scheme)) {
      continue;
    }
    final ms = item['durationMs'];
    final artist = (item['artist'] as String?)?.trim();
    out.add(
      Track(
        id: id,
        source: TrackSource.device,
        title: title.trim(),
        artist: artist == null || artist.isEmpty ? null : artist,
        streamUri: uri,
        duration: ms is num && ms > 0
            ? Duration(milliseconds: ms.round())
            : null,
      ),
    );
  }
  return out;
}

class ChannelDeviceMusicRepository implements DeviceMusicRepository {
  ChannelDeviceMusicRepository({
    MethodChannel? channel,
    this.cacheFor = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : _channel = channel ?? deviceMusicChannel,
       _now = now ?? DateTime.now;

  final MethodChannel _channel;
  final Duration cacheFor;
  final DateTime Function() _now;
  List<Track>? _cache;
  DateTime? _cachedAt;

  @override
  bool get supported => true;

  @override
  Future<DeviceMusicAccess> access() async {
    try {
      return DeviceMusicAccess.fromName(
        await _channel.invokeMethod<Object?>('access'),
      );
    } on PlatformException {
      return DeviceMusicAccess.notDetermined;
    }
  }

  @override
  Future<DeviceMusicAccess> request() async {
    try {
      final result = DeviceMusicAccess.fromName(
        await _channel.invokeMethod<Object?>('request'),
      );
      _cache = null;
      return result;
    } on PlatformException {
      return DeviceMusicAccess.notDetermined;
    }
  }

  @override
  Future<List<Track>> songs({bool refresh = false}) async {
    final cached = _cache;
    final at = _cachedAt;
    if (!refresh &&
        cached != null &&
        at != null &&
        _now().difference(at) < cacheFor) {
      return cached;
    }
    final songs = parseDeviceSongs(
      await _channel.invokeMethod<Object?>('list'),
    );
    _cache = songs;
    _cachedAt = _now();
    return songs;
  }
}

/// Platform tanpa jambatan: tiada apa-apa dipaparkan.
class UnavailableDeviceMusicRepository implements DeviceMusicRepository {
  const UnavailableDeviceMusicRepository();

  @override
  bool get supported => false;

  @override
  Future<DeviceMusicAccess> access() async => DeviceMusicAccess.unsupported;

  @override
  Future<DeviceMusicAccess> request() async => DeviceMusicAccess.unsupported;

  @override
  Future<List<Track>> songs({bool refresh = false}) async => const [];
}
