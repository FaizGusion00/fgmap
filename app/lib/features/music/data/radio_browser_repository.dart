import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/log.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';
import 'curated_stations.dart';

/// URL strim stesen: `url_resolved` (selepas ubah hala/playlist) jika ada, jika tidak `url`.
String? _streamUrl(Map<dynamic, dynamic> item) {
  final resolved = item['url_resolved'];
  if (resolved is String && resolved.isNotEmpty) return resolved;
  final url = item['url'];
  return url is String && url.isNotEmpty ? url : null;
}

/// Menghurai senarai stesen Radio Browser. Hanya strim HTTPS dikekalkan: build release melarang
/// trafik cleartext (ADR 0010), jadi stesen `http://` tidak akan dapat dimainkan. Pengecualian:
/// stesen `http://` yang uuid-nya ada dalam [upgraded] (varian `https://` sudah disahkan berfungsi,
/// lihat [DioRadioBrowserRepository]) dimainkan melalui `https://`. Stesen dengan `ssl_error`
/// (sijil rosak) dibuang kerana tidak akan disambung oleh OS.
List<Track> parseRadioStations(
  Object? json, {
  Set<String> upgraded = const {},
}) {
  if (json is! List) return const [];
  final out = <Track>[];
  final seen = <String>{};
  for (final item in json) {
    if (item is! Map) continue;
    final uuid = item['stationuuid'] as String?;
    final name = (item['name'] as String?)?.trim();
    var url = _streamUrl(item);
    if (uuid == null || name == null || name.isEmpty || url == null) continue;
    if (url.startsWith('http://')) {
      if (!upgraded.contains(uuid)) continue;
      url = 'https://${url.substring('http://'.length)}';
    } else if (!url.startsWith('https://')) {
      continue;
    }
    if (item['lastcheckok'] == 0) continue;
    if (item['ssl_error'] == 1) continue;
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

/// Stesen `http://` yang boleh dicuba pada `https://`, mengikut tertib senarai (uuid -> URL HTTPS).
Map<String, Uri> radioUpgradeCandidates(Object? json) {
  if (json is! List) return const {};
  final out = <String, Uri>{};
  for (final item in json) {
    if (item is! Map) continue;
    final uuid = item['stationuuid'] as String?;
    final url = _streamUrl(item);
    if (uuid == null || url == null || !url.startsWith('http://')) continue;
    if (item['lastcheckok'] == 0) continue;
    final secure = Uri.tryParse('https://${url.substring('http://'.length)}');
    if (secure != null) out[uuid] = secure;
  }
  return out;
}

class DioRadioBrowserRepository implements RadioRepository {
  DioRadioBrowserRepository(
    this._dio, {
    List<String>? mirrors,
    this.upgradeHttp = true,
    this.curated = curatedStations,
  }) : _mirrors = mirrors ?? AppConfig.radioBrowserUrls;

  final Dio _dio;
  final List<String> _mirrors;

  /// Stesen disahkan yang digabung ke senarai kawasannya; ujian menghantar `[]` untuk matikan.
  final List<CuratedStation> curated;

  /// Cuba varian `https://` bagi stesen `http://` dan paparkan yang berfungsi. Diukur pada data
  /// sebenar: 8 daripada 30 stesen http Malaysia (termasuk RTM Nasional FM, Asyik FM, Klasik),
  /// 9 daripada 29 Indonesia dan 24 daripada 42 Japan berfungsi; selebihnya tidak ada HTTPS.
  final bool upgradeHttp;
  int _preferred = 0;

  /// Keputusan sahkan HTTPS setiap stesen untuk sesi ini (uuid -> berfungsi). Stesen yang belum
  /// sempat disahkan (had masa) tidak dicatat dan dicuba semula pada muatan seterusnya.
  final _verdicts = <String, bool>{};
  static const maxUpgradeProbes = 30;
  static const _probeConcurrency = 8;
  static const _upgradeBudget = Duration(seconds: 5);
  final _cache = <RadioRegion, (List<Track>, DateTime)>{};
  static const _cacheFor = Duration(minutes: 30);

  @override
  Future<List<Track>> stations({
    String query = '',
    RadioRegion region = RadioRegion.malaysia,
  }) async {
    // Kegemaran datang dari peranti, bukan Radio Browser (lihat MusicSearchController).
    if (region == RadioRegion.favorites) return const [];
    final q = query.trim().toLowerCase();
    final browse = await _region(region);
    if (q.isEmpty) return browse;
    final local = [
      for (final t in browse)
        if (t.title.toLowerCase().contains(q) ||
            (t.artist?.toLowerCase().contains(q) ?? false))
          t,
    ];
    // Carian nama di seluruh dunia: stesen Indonesia/Korea tidak ada dalam senarai Malaysia.
    List<Track> remote;
    try {
      remote = await _tracks(await _get({'name': q, 'limit': 60, ..._base}));
    } on Object {
      if (local.isNotEmpty) return local;
      rethrow;
    }
    final seen = {for (final t in local) t.id};
    return [
      ...local,
      for (final t in remote)
        if (seen.add(t.id)) t,
    ];
  }

  static const _base = {
    'hidebroken': 'true',
    'order': 'clickcount',
    'reverse': 'true',
  };

  Future<List<Track>> _region(RadioRegion region) async {
    final cached = _cache[region];
    if (cached != null && DateTime.now().difference(cached.$2) < _cacheFor) {
      return cached.$1;
    }
    try {
      final tracks = _withCurated(
        region,
        await _tracks(await _get({...region.params, 'limit': 150, ..._base})),
      );
      _cache[region] = (tracks, DateTime.now());
      return tracks;
    } on Object {
      if (cached != null) return cached.$1;
      // Direktori tidak dapat dicapai: stesen disahkan masih boleh dipaparkan (tidak di-cache).
      final fallback = _withCurated(region, const []);
      if (fallback.isNotEmpty) return fallback;
      rethrow;
    }
  }

  /// Stesen disahkan [region] di hadapan; stesen Radio Browser yang sama dibuang (URL disahkan di
  /// sini lebih dipercayai).
  List<Track> _withCurated(RadioRegion region, List<Track> browse) {
    final mine = [
      for (final c in curated)
        if (c.region == region) c,
    ];
    if (mine.isEmpty) return browse;
    final names = [for (final c in mine) normalizeStationName(c.name)];
    return [
      for (final c in mine) c.toTrack(),
      for (final t in browse)
        if (!names.any((n) => sameStation(n, normalizeStationName(t.title)))) t,
    ];
  }

  Future<List<Track>> _tracks(Object? raw) async {
    if (upgradeHttp) {
      final todo = {
        for (final e in radioUpgradeCandidates(raw).entries)
          if (!_verdicts.containsKey(e.key)) e.key: e.value,
      };
      if (todo.isNotEmpty) await _verifyHttps(todo);
    }
    return parseRadioStations(
      raw,
      upgraded: {
        for (final e in _verdicts.entries)
          if (e.value) e.key,
      },
    );
  }

  /// Sahkan (selari, dalam had masa) varian HTTPS [candidates] benar-benar menyiarkan audio. Dihadkan
  /// kepada [maxUpgradeProbes] stesen teratas dan [_upgradeBudget] supaya senarai tidak tertahan;
  /// hanya pengepala dibaca, kemudian sambungan ditutup.
  Future<void> _verifyHttps(Map<String, Uri> candidates) async {
    final queue = candidates.entries.take(maxUpgradeProbes).toList();
    final cancel = CancelToken();
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length && !cancel.isCancelled) {
        final e = queue[next++];
        final ok = await _servesAudio(e.value, cancel);
        if (!cancel.isCancelled) _verdicts[e.key] = ok;
      }
    }

    try {
      await Future.wait([
        for (var i = 0; i < _probeConcurrency; i++) worker(),
      ]).timeout(_upgradeBudget);
    } on TimeoutException {
      logDiag('Sahkan HTTPS radio: had masa, sebahagian belum disahkan');
    } finally {
      cancel.cancel();
    }
  }

  Future<bool> _servesAudio(Uri uri, CancelToken cancel) async {
    try {
      // Token sendiri supaya sambungan ditutup sebaik pengepala dibaca (strim radio tidak berkesudahan).
      final probe = CancelToken();
      unawaited(cancel.whenCancel.then((_) => probe.cancel()));
      final res = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: probe,
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': '*/*', 'Icy-MetaData': '0'},
          validateStatus: (s) => s == 200,
        ),
      );
      final type = (res.headers.value(Headers.contentTypeHeader) ?? '')
          .toLowerCase();
      probe.cancel();
      return type.startsWith('audio/') ||
          type.contains('mpegurl') ||
          type.contains('ogg');
    } on Object {
      return false;
    }
  }

  /// GET `/json/stations/search` dengan failover cermin.
  Future<Object?> _get(Map<String, Object> params) async {
    Object? lastError;
    for (var n = 0; n < _mirrors.length; n++) {
      final index = (_preferred + n) % _mirrors.length;
      try {
        final res = await _dio.get<Object?>(
          '${_mirrors[index]}/json/stations/search',
          queryParameters: params,
        );
        _preferred = index;
        return res.data;
      } on Object catch (e) {
        lastError = e;
        logDiag('Radio Browser cermin ${index + 1} gagal: $e');
      }
    }
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
