import 'package:fgmap/features/local_assistant/data/deen_fatwa_client.dart';
import 'package:fgmap/features/local_assistant/data/islamic_app_client.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:fgmap/features/local_assistant/presentation/muslim_ai_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('senarai rujukan di hujung jawapan dibuang; penanda [n] kekal', () {
    const answer =
        'Zakat is obligatory on wealth that reaches the nisab [1][3].\n\n'
        'It purifies wealth [2].\n\n'
        'References:\n'
        '[1] Sahih Ibn Khuzayma\n'
        '[2] Ahkam al-Quran\n'
        '[3] al-Muhadhdhab';
    final out = stripReferenceList(answer);
    expect(out, contains('[1][3]'));
    expect(out, isNot(contains('References')));
    expect(out, isNot(contains('[2] Ahkam')));
  });

  test('senarai bernombor di hujung tanpa tajuk juga dibuang', () {
    const answer = 'Riba is forbidden [1].\n[1] Subul al-Salam\n[2] Tahqiq';
    expect(stripReferenceList(answer), 'Riba is forbidden [1].');
  });

  test(
    'jawapan berstruktur: teks bersih, sumber berasingan, tiada URL dalam teks',
    () {
      final reply = composeMuslimReply(
        library: IslamicAppAnswer.fromJson({
          'grounded': true,
          'answer': 'Patience is half of faith [1].\n\nSources:\n[1] Madarij',
          'sources': [
            {
              'n': 1,
              'book_title': 'مدارج السالكين',
              'translit': 'Madarij al-Salikin',
              'book_slug': 'madarij-al-salikin',
              'chapter_title': 'Sabr',
              'page': 340,
            },
          ],
        }),
        libraryError: null,
        fatwaHits: [
          DeenFatwaHit.fromJson({
            'id': 7,
            'title': 'Ruling on patience',
            'url': 'https://example.org/fatwa/7',
            'source': 'IslamQA',
            'madhab': 'Hanbali',
          })!,
        ],
      );
      expect(reply.text, 'Patience is half of faith [1].');
      expect(reply.text, isNot(contains('http')));
      expect(reply.notice, AnswerNotice.classicalSummary);
      expect(reply.sources, hasLength(2));
      final c = reply.sources.first;
      expect(c.title, 'Madarij al-Salikin');
      expect(c.original, 'مدارج السالكين');
      expect(c.subtitle, 'Sabr · p.340');
      expect(reply.sources.last.kind, AnswerSourceKind.fatwa);
    },
  );

  test('had kadar jadi nota, bukan teks bercampur', () {
    final reply = composeMuslimReply(
      library: null,
      libraryError: const IslamicAppRateLimitException(),
      fatwaHits: const [],
    );
    expect(reply.notice, AnswerNotice.rateLimited);
    expect(reply.text, isEmpty);
  });
}
