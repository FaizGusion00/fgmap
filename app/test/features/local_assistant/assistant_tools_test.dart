import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alat dikenali; nama asing ditolak', () {
    expect(isKnownAssistantTool('plan_route'), isTrue);
    expect(isKnownAssistantTool('get_air_quality'), isTrue);
    expect(isKnownAssistantTool('wikipedia_summary'), isTrue);
    expect(isKnownAssistantTool('hack_bank'), isFalse);
    expect(assistantTools(), isNotEmpty);
    expect(assistantTools().map((t) => t.name).toSet(), assistantToolNames);
  });

  test('model TIDAK diberi plan_route (laluan hanya melalui penghala)', () {
    final names = llmAssistantTools().map((t) => t.name).toSet();
    expect(names, isNot(contains('plan_route')));
    expect(names, llmToolNames);
    expect(assistantSystemPrompt, contains('FG AI'));
    expect(assistantSystemPrompt, contains('Faiz Nasir'));
  });

  test('clipToolResult memotong teks panjang', () {
    final long = 'a' * 1200;
    final clipped = clipToolResult(long, max: 100);
    expect(clipped.length, lessThanOrEqualTo(100));
    expect(clipped.endsWith('…'), isTrue);
  });

  test('AssistantMessage JSON bulat-trip', () {
    final m = AssistantMessage(
      role: AssistantRole.user,
      text: 'Navigasi ke KLCC, elak tol',
      at: DateTime(2026, 10, 31, 20),
    );
    final back = AssistantMessage.fromJson(m.toJson());
    expect(back?.role, AssistantRole.user);
    expect(back?.text, contains('KLCC'));
  });

  test(
    'teks kosong ditolak kecuali jawapan pembantu bernota atau bersumber',
    () {
      expect(
        AssistantMessage.fromJson({
          'role': 'user',
          'text': '   ',
          'notice': 'rateLimited',
        }),
        isNull,
      );
      expect(
        AssistantMessage.fromJson({'role': 'assistant', 'text': ''}),
        isNull,
      );
      final noticeOnly = AssistantMessage.fromJson({
        'role': 'assistant',
        'text': '',
        'notice': 'rateLimited',
      });
      expect(noticeOnly?.notice, AnswerNotice.rateLimited);
      expect(noticeOnly?.text, isEmpty);
      final sourcesOnly = AssistantMessage.fromJson({
        'role': 'assistant',
        'text': '',
        'sources': [
          {
            'kind': 'fatwa',
            'title': 'Ruling',
            'url': 'https://example.org/fatwa/1',
          },
        ],
      });
      expect(sourcesOnly?.sources.single.title, 'Ruling');
    },
  );
}
