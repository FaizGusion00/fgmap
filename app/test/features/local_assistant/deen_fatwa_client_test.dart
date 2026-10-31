import 'package:dio/dio.dart';
import 'package:fgmap/features/local_assistant/data/deen_fatwa_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  test('search menghuraikan hasil fatwa', () async {
    final dio = Dio()
      ..httpClientAdapter = StubAdapter(
        (_) => StubAdapter.json({
          'query': 'zakat',
          'count': 1,
          'results': [
            {
              'id': 42,
              'title': 'Zakat Questions',
              'url': 'https://example.com/zakat',
              'source': 'albalagh',
              'madhab': 'Hanafi',
              'lang': 'en',
              'scholars': ['Mufti Ebrahim Desai'],
              'score': 8.5,
              'snippet': 'How to calculate zakat…',
            },
          ],
        }),
      );
    final client = DeenFatwaClient(dio, baseUrl: 'https://api.deen.ai');
    final hits = await client.search('zakat');
    expect(hits, hasLength(1));
    expect(hits.first.id, 42);
    expect(hits.first.title, 'Zakat Questions');
    expect(hits.first.scholars, ['Mufti Ebrahim Desai']);
    expect(hits.first.madhab, 'Hanafi');
  });

  test('search kosong jika tiada results', () async {
    final dio = Dio()
      ..httpClientAdapter = StubAdapter(
        (_) => StubAdapter.json({'query': 'x', 'count': 0, 'results': []}),
      );
    final client = DeenFatwaClient(dio, baseUrl: 'https://api.deen.ai');
    expect(await client.search('x'), isEmpty);
    expect(await client.search('  '), isEmpty);
  });

  test('detail menghuraikan badan fatwa', () async {
    final dio = Dio()
      ..httpClientAdapter = StubAdapter(
        (_) => StubAdapter.json({
          'id': 7,
          'title': 'Riba',
          'body': 'Riba is forbidden…',
          'url': 'https://example.com/riba',
          'madhab': 'Hanafi',
          'source': 'askimam',
          'scholars': [],
        }),
      );
    final client = DeenFatwaClient(dio, baseUrl: 'https://api.deen.ai');
    final d = await client.detail(7);
    expect(d?.title, 'Riba');
    expect(d?.body, contains('forbidden'));
  });
}
