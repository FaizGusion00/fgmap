import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';

/// Jawapan RAG berpetikan dari islamic.app (teks klasik). Bukan fatwa; tiada kunci.
///
/// Diuji 2026-10-31: `POST https://api.islamic.app/v1/library/ask`.
/// Had keyless: ~20/jam per IP + bajet harian global — soft-fail bila 429.
class IslamicAppClient {
  IslamicAppClient(this._dio, {this.baseUrl = AppConfig.islamicAppApiUrl});

  final Dio _dio;
  final String baseUrl;

  Future<IslamicAppAnswer> ask(String question, {CancelToken? cancel}) async {
    final q = question.trim();
    if (q.isEmpty) {
      return const IslamicAppAnswer(
        question: '',
        grounded: false,
        answer: '',
        sources: [],
      );
    }
    final clipped = q.length > 500 ? q.substring(0, 500) : q;
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/v1/library/ask',
      data: {'q': clipped},
      options: Options(
        responseType: ResponseType.json,
        // Retrieval + model 70B — beri masa.
        receiveTimeout: const Duration(seconds: 55),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': AppConfig.userAgent,
          'Accept': 'application/json',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
      cancelToken: cancel,
    );
    final code = res.statusCode ?? 0;
    if (code == 429) {
      throw const IslamicAppRateLimitException();
    }
    if (code >= 400) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'islamic.app HTTP $code',
      );
    }
    final root = res.data;
    final data = root?['data'];
    if (data is! Map) {
      return IslamicAppAnswer(
        question: clipped,
        grounded: false,
        answer: '',
        sources: const [],
      );
    }
    return IslamicAppAnswer.fromJson(data);
  }
}

class IslamicAppRateLimitException implements Exception {
  const IslamicAppRateLimitException();

  @override
  String toString() => 'IslamicAppRateLimitException';
}

@immutable
class IslamicAppAnswer {
  const IslamicAppAnswer({
    required this.question,
    required this.grounded,
    required this.answer,
    required this.sources,
    this.model,
  });

  final String question;
  final bool grounded;
  final String answer;
  final List<IslamicAppSource> sources;
  final String? model;

  static IslamicAppAnswer fromJson(Map raw) {
    final sourcesRaw = raw['sources'];
    return IslamicAppAnswer(
      question: raw['question']?.toString() ?? '',
      grounded: raw['grounded'] == true,
      answer: raw['answer']?.toString() ?? '',
      model: raw['model']?.toString(),
      sources: sourcesRaw is List
          ? [
              for (final e in sourcesRaw)
                if (e is Map) ?IslamicAppSource.fromJson(e),
            ]
          : const [],
    );
  }
}

@immutable
class IslamicAppSource {
  const IslamicAppSource({
    required this.n,
    required this.bookTitle,
    required this.url,
    this.translit,
    this.chapterTitle,
    this.page,
    this.bookSlug,
  });

  final int n;
  final String bookTitle;
  final String url;
  final String? translit;
  final String? chapterTitle;
  final int? page;
  final String? bookSlug;

  String get label {
    final title = (translit != null && translit!.trim().isNotEmpty)
        ? translit!
        : bookTitle;
    final ch = chapterTitle?.trim();
    final p = page;
    if (ch != null && ch.isNotEmpty && p != null) return '$title · $ch · p.$p';
    if (p != null) return '$title · p.$p';
    return title;
  }

  static IslamicAppSource? fromJson(Map raw) {
    final n = (raw['n'] as num?)?.toInt() ?? 0;
    final bookTitle = raw['book_title']?.toString().trim() ?? '';
    final slug = raw['book_slug']?.toString().trim();
    final page = (raw['page'] as num?)?.toInt();
    if (bookTitle.isEmpty && (slug == null || slug.isEmpty)) return null;
    final url = slug != null && slug.isNotEmpty
        ? 'https://islamic.app/library/$slug/read${page != null ? '?page=$page' : ''}'
        : 'https://islamic.app/library';
    return IslamicAppSource(
      n: n,
      bookTitle: bookTitle.isEmpty ? (slug ?? 'Source') : bookTitle,
      url: url,
      translit: raw['translit']?.toString(),
      chapterTitle: raw['chapter_title']?.toString(),
      page: page,
      bookSlug: slug,
    );
  }
}

final islamicAppClientProvider = Provider(
  (ref) => IslamicAppClient(ref.watch(dioProvider)),
);
