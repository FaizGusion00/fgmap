import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/assistant_tools.dart';

/// Ringkasan awam Wikipedia (bukan berita langsung).
class WikipediaClient {
  WikipediaClient(this._dio);

  final Dio _dio;

  Future<String?> summary(String query, {String lang = 'ms'}) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final host = lang == 'en' ? 'en' : 'ms';
    try {
      final search = await _dio.get<Map<String, dynamic>>(
        'https://$host.wikipedia.org/w/rest.php/v1/search/title',
        queryParameters: {'q': q, 'limit': 1},
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final pages = search.data?['pages'];
      if (pages is! List || pages.isEmpty) return null;
      final key = (pages.first as Map)['key']?.toString();
      if (key == null || key.isEmpty) return null;
      final page = await _dio.get<Map<String, dynamic>>(
        'https://$host.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(key)}',
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final extract = page.data?['extract']?.toString();
      final title = page.data?['title']?.toString() ?? key;
      if (extract == null || extract.isEmpty) return null;
      return clipToolResult('$title — $extract', max: 700);
    } on Object {
      return null;
    }
  }
}

final wikipediaClientProvider = Provider(
  (ref) => WikipediaClient(ref.watch(dioProvider)),
);
