import 'package:dio/dio.dart';
import 'package:fgmap/features/local_assistant/data/islamic_app_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  test('ask menghuraikan jawapan berpetikan', () async {
    final dio = Dio()
      ..httpClientAdapter = StubAdapter(
        (_) => StubAdapter.json({
          'code': 200,
          'status': 'OK',
          'data': {
            'question': 'patience',
            'grounded': true,
            'answer': 'Patience is… [1]',
            'model': 'llama',
            'sources': [
              {
                'n': 1,
                'book_title': 'مدارج السالكين',
                'translit': 'Madarij al-Salikin',
                'book_slug': 'madarij-al-salikin',
                'chapter_title': 'Sabr',
                'page': 340,
                'score': 0.7,
              },
            ],
          },
        }),
      );
    final client = IslamicAppClient(dio, baseUrl: 'https://api.islamic.app');
    final a = await client.ask('patience');
    expect(a.grounded, isTrue);
    expect(a.answer, contains('Patience'));
    expect(a.sources, hasLength(1));
    expect(a.sources.first.translit, 'Madarij al-Salikin');
    expect(a.sources.first.url, contains('madarij-al-salikin'));
  });

  test('ask 429 jadi rate limit', () async {
    final dio = Dio()
      ..httpClientAdapter = StubAdapter(
        (_) => StubAdapter.json({'code': 429, 'data': 'rate_limited'}, status: 429),
      );
    final client = IslamicAppClient(dio, baseUrl: 'https://api.islamic.app');
    expect(
      () => client.ask('zakat'),
      throwsA(isA<IslamicAppRateLimitException>()),
    );
  });
}
