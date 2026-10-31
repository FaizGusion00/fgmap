import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';

/// API carian fatwa percuma deen.ai (bukan fatwa rasmi JAKIM).
///
/// Diuji 2026-10-31: `POST https://api.deen.ai/search` + `GET /fatwa/{id}`.
class DeenFatwaClient {
  DeenFatwaClient(this._dio, {this.baseUrl = AppConfig.deenApiUrl});

  final Dio _dio;
  final String baseUrl;

  Future<List<DeenFatwaHit>> search(
    String query, {
    CancelToken? cancel,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/search',
      data: {'query': q},
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 20),
        headers: {'User-Agent': AppConfig.userAgent},
      ),
      cancelToken: cancel,
    );
    final results = res.data?['results'];
    if (results is! List) return const [];
    return [
      for (final e in results)
        if (e is Map) ?DeenFatwaHit.fromJson(e),
    ];
  }

  Future<DeenFatwaDetail?> detail(int id, {CancelToken? cancel}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/fatwa/$id',
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 20),
        headers: {'User-Agent': AppConfig.userAgent},
      ),
      cancelToken: cancel,
    );
    final data = res.data;
    if (data == null) return null;
    return DeenFatwaDetail.fromJson(data);
  }
}

@immutable
class DeenFatwaHit {
  const DeenFatwaHit({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.snippet,
    this.madhab,
    this.lang,
    this.scholars = const [],
    this.score,
  });

  final int id;
  final String title;
  final String url;
  final String source;
  final String snippet;
  final String? madhab;
  final String? lang;
  final List<String> scholars;
  final double? score;

  static DeenFatwaHit? fromJson(Map raw) {
    final id = (raw['id'] as num?)?.toInt();
    final title = raw['title']?.toString().trim();
    final url = raw['url']?.toString().trim();
    if (id == null || title == null || title.isEmpty || url == null) {
      return null;
    }
    final scholarsRaw = raw['scholars'];
    return DeenFatwaHit(
      id: id,
      title: title,
      url: url,
      source: raw['source']?.toString() ?? '',
      snippet: raw['snippet']?.toString() ?? '',
      madhab: raw['madhab']?.toString(),
      lang: raw['lang']?.toString(),
      scholars: scholarsRaw is List
          ? [
              for (final s in scholarsRaw)
                if (s.toString().trim().isNotEmpty) s.toString().trim(),
            ]
          : const [],
      score: (raw['score'] as num?)?.toDouble(),
    );
  }
}

@immutable
class DeenFatwaDetail {
  const DeenFatwaDetail({
    required this.id,
    required this.title,
    required this.body,
    required this.url,
    this.madhab,
    this.source,
    this.scholars = const [],
  });

  final int id;
  final String title;
  final String body;
  final String url;
  final String? madhab;
  final String? source;
  final List<String> scholars;

  static DeenFatwaDetail? fromJson(Map raw) {
    final id = (raw['id'] as num?)?.toInt();
    final title = raw['title']?.toString().trim();
    final body = raw['body']?.toString() ?? '';
    final url = raw['url']?.toString() ?? raw['source_url']?.toString() ?? '';
    if (id == null || title == null || title.isEmpty) return null;
    final scholarsRaw = raw['scholars'];
    return DeenFatwaDetail(
      id: id,
      title: title,
      body: body,
      url: url,
      madhab: raw['madhab']?.toString(),
      source: raw['source']?.toString() ?? raw['site']?.toString(),
      scholars: scholarsRaw is List
          ? [
              for (final s in scholarsRaw)
                if (s.toString().trim().isNotEmpty) s.toString().trim(),
            ]
          : const [],
    );
  }
}

final deenFatwaClientProvider = Provider(
  (ref) => DeenFatwaClient(ref.watch(dioProvider)),
);
