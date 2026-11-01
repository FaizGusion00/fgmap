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
        queryParameters: {'q': q, 'limit': 5},
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final pages = search.data?['pages'];
      if (pages is! List || pages.isEmpty) return null;
      final key = bestTitleMatch(q, [
        for (final p in pages)
          if (p is Map && p['key'] != null)
            (key: p['key'].toString(), title: '${p['title'] ?? p['key']}'),
      ]);
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

/// Tajuk yang paling hampir dengan [query] (jarak suntingan, huruf kecil). Carian tajuk Wikipedia
/// ialah awalan: "palestin" memulangkan "Ira J. Palestin" dahulu, bukan "Palestine".
String? bestTitleMatch(String query, List<({String key, String title})> pages) {
  if (pages.isEmpty) return null;
  final q = query.toLowerCase().trim();
  var best = pages.first;
  var bestScore = 1 << 30;
  for (final p in pages) {
    final score = _distance(q, p.title.toLowerCase());
    if (score < bestScore) {
      best = p;
      bestScore = score;
    }
  }
  return best.key;
}

int _distance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}
