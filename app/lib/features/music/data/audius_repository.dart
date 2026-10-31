import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/retry_interceptor.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';

/// Menghurai `data[]` daripada `/v1/tracks/search` atau `/v1/tracks/trending`. Lagu yang tidak
/// boleh distrim dilangkau. Fungsi tulen untuk ujian dengan respons sebenar yang disimpan.
List<Track> parseAudiusTracks(Object? json, {required String baseUrl}) {
  if (json is! Map) return const [];
  final data = json['data'];
  if (data is! List) return const [];
  final out = <Track>[];
  for (final item in data) {
    if (item is! Map) continue;
    final id = item['id'] as String?;
    final title = item['title'] as String?;
    if (id == null || id.isEmpty || title == null || title.isEmpty) continue;
    if (item['is_streamable'] == false) continue;
    final user = item['user'];
    final artwork = item['artwork'];
    final art = artwork is Map
        ? (artwork['480x480'] ?? artwork['150x150']) as String?
        : null;
    final permalink = item['permalink'] as String?;
    final seconds = item['duration'];
    out.add(
      Track(
        id: id,
        source: TrackSource.audius,
        title: title.trim(),
        artist: user is Map ? (user['name'] as String?)?.trim() : null,
        streamUri: Uri.parse(
          '$baseUrl/v1/tracks/$id/stream?app_name=${AppConfig.audiusAppName}',
        ),
        artworkUri: art == null ? null : Uri.tryParse(art),
        duration: seconds is num ? Duration(seconds: seconds.round()) : null,
        permalink: permalink == null
            ? null
            : Uri.tryParse('https://audius.co$permalink'),
      ),
    );
  }
  return out;
}

class DioAudiusRepository implements AudiusRepository {
  DioAudiusRepository(this._dio, {String? baseUrl})
    : _base = (baseUrl ?? AppConfig.audiusUrl).replaceAll(RegExp(r'/+$'), '');

  final Dio _dio;
  final String _base;

  @override
  Future<List<Track>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final res = await _dio.get<Object?>(
      '$_base/v1/tracks/search',
      queryParameters: {
        'query': q,
        'app_name': AppConfig.audiusAppName,
        'limit': 25,
      },
      options: Options(extra: {RetryInterceptor.retryKey: true}),
    );
    return parseAudiusTracks(res.data, baseUrl: _base);
  }

  @override
  Future<List<Track>> trending() async {
    final res = await _dio.get<Object?>(
      '$_base/v1/tracks/trending',
      queryParameters: {'app_name': AppConfig.audiusAppName, 'limit': 20},
      options: Options(extra: {RetryInterceptor.retryKey: true}),
    );
    return parseAudiusTracks(res.data, baseUrl: _base);
  }
}

final audiusRepositoryProvider = Provider<AudiusRepository>(
  (ref) => DioAudiusRepository(ref.watch(dioProvider)),
);
