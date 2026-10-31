import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/log.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';

/// Menghurai senarai stesen Radio Browser. Hanya strim HTTPS dikekalkan: build release melarang
/// trafik cleartext (ADR 0010), jadi stesen `http://` tidak akan dapat dimainkan.
List<Track> parseRadioStations(Object? json) {
  if (json is! List) return const [];
  final out = <Track>[];
  final seen = <String>{};
  for (final item in json) {
    if (item is! Map) continue;
    final uuid = item['stationuuid'] as String?;
    final name = (item['name'] as String?)?.trim();
    final url = (item['url_resolved'] as String?) ?? (item['url'] as String?);
    if (uuid == null || name == null || name.isEmpty || url == null) continue;
    if (!url.startsWith('https://')) continue;
    if (item['lastcheckok'] == 0) continue;
    if (!seen.add(uuid)) continue;
    final favicon = item['favicon'] as String?;
    final homepage = item['homepage'] as String?;
    final tags = (item['tags'] as String?)?.trim();
    final stream = Uri.tryParse(url);
    if (stream == null) continue;
    out.add(
      Track(
        id: uuid,
        source: TrackSource.radio,
        title: name,
        artist: tags == null || tags.isEmpty
            ? null
            : tags.split(',').take(3).join(', '),
        streamUri: stream,
        artworkUri: favicon != null && favicon.startsWith('https://')
            ? Uri.tryParse(favicon)
            : null,
        permalink: homepage == null ? null : Uri.tryParse(homepage),
        radioUuid: uuid,
      ),
    );
  }
  return out;
}

class DioRadioBrowserRepository implements RadioRepository {
  DioRadioBrowserRepository(this._dio, {List<String>? mirrors})
    : _mirrors = mirrors ?? AppConfig.radioBrowserUrls;

  final Dio _dio;
  final List<String> _mirrors;
  int _preferred = 0;
  List<Track>? _cache;
  DateTime? _cachedAt;
  static const _cacheFor = Duration(minutes: 30);

  @override
  Future<List<Track>> stations({String query = ''}) async {
    final all = await _all();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final t in all)
        if (t.title.toLowerCase().contains(q) ||
            (t.artist?.toLowerCase().contains(q) ?? false))
          t,
    ];
  }

  Future<List<Track>> _all() async {
    final cached = _cache;
    final at = _cachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheFor) {
      return cached;
    }
    Object? lastError;
    for (var n = 0; n < _mirrors.length; n++) {
      final index = (_preferred + n) % _mirrors.length;
      try {
        final res = await _dio.get<Object?>(
          '${_mirrors[index]}/json/stations/search',
          queryParameters: {
            'countrycode': 'MY',
            'hidebroken': 'true',
            'order': 'clickcount',
            'reverse': 'true',
            'limit': 100,
          },
        );
        final tracks = parseRadioStations(res.data);
        _preferred = index;
        _cache = tracks;
        _cachedAt = DateTime.now();
        return tracks;
      } on Object catch (e) {
        lastError = e;
        logDiag('Radio Browser cermin ${index + 1} gagal: $e');
      }
    }
    if (cached != null) return cached;
    throw lastError ?? StateError('Tiada cermin Radio Browser');
  }

  @override
  Future<void> countClick(String stationUuid) async {
    try {
      await _dio.get<Object?>(
        '${_mirrors[_preferred % _mirrors.length]}/json/url/$stationUuid',
      );
    } on Object catch (e) {
      logDiag('Kiraan klik radio gagal: $e');
    }
  }
}

final radioRepositoryProvider = Provider<RadioRepository>(
  (ref) => DioRadioBrowserRepository(ref.watch(dioProvider)),
);
