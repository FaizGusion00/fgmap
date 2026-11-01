import 'package:fgmap/features/local_assistant/data/edge_ai_runtime.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:flutter_test/flutter_test.dart';

AssistantMessage _u(String t) =>
    AssistantMessage(role: AssistantRole.user, text: t);
AssistantMessage _a(String t, {bool card = false}) => AssistantMessage(
  role: AssistantRole.assistant,
  text: t,
  actions: card
      ? const [AssistantAction(AssistantActionKind.showRoute)]
      : const [],
);

void main() {
  test(
    'kad laluan penghala (dan soalannya) tidak dimainkan semula kepada model',
    () {
      final h = compactHistory([
        _u('I wanna go to Kuala Kedah'),
        _a('Route to Kuala Kedah is ready: 5 h 51 min', card: true),
        _u('What is a durian?'),
        _a('A durian is a spiky tropical fruit.'),
      ]);
      expect(h.map((m) => m.text), [
        'What is a durian?',
        'A durian is a spiky tropical fruit.',
      ]);
    },
  );

  test(
    'jawapan templat app (identiti) tidak dimainkan semula: model tidak menyalinnya',
    () {
      final h = compactHistory([
        _u('Hi bro who are you?'),
        const AssistantMessage(
          role: AssistantRole.assistant,
          text: "I'm FG AI, the smart assistant in FGMaps",
          local: true,
        ),
        _u('Explain photosynthesis'),
        _a('Plants turn light into sugar.'),
      ]);
      expect(h.map((m) => m.text), [
        'Explain photosynthesis',
        'Plants turn light into sugar.',
      ]);
      // Tanda kekal selepas disimpan dan dibaca semula.
      final back = AssistantMessage.fromJson(
        const AssistantMessage(
          role: AssistantRole.assistant,
          text: 'x',
          local: true,
        ).toJson(),
      );
      expect(back!.local, isTrue);
    },
  );

  test('jawapan sebenar vs sisa sebelum panggilan alat', () {
    expect(hasSubstantiveAnswer('.'), isFalse);
    expect(hasSubstantiveAnswer('Let me check'), isFalse);
    expect(
      hasSubstantiveAnswer(
        'Yes, I can answer you. Ask me about routes, places or anything else.',
      ),
      isTrue,
    );
    // Soalan balas bukan jawapan: panggilan web_search selepasnya mesti dijalankan.
    expect(
      hasSubstantiveAnswer(
        'I can certainly browse the internet for you. What specific topics '
        'are you interested in?',
      ),
      isFalse,
    );
  });

  test(
    'sesi baharu: sejarah dalam SATU blok berlabel, jawapan lama dipendekkan',
    () {
      final tips = 'Here are a few general tips for better sleep: ${'x' * 300}';
      final p = replayPrompt([
        _u('How to sleep better?'),
        _a(tips),
      ], 'Can you browse the internet? Find latest new');
      expect(p, startsWith('Earlier in this chat (context only'));
      expect(p, contains('User: How to sleep better?'));
      expect(p, contains('FG AI: Here are a few general tips'));
      expect(p, isNot(contains('x' * 150)));
      expect(
        p,
        endsWith(
          'Now answer only this: Can you browse the internet? Find latest new',
        ),
      );
      expect(replayPrompt(const [], 'Hi'), 'Hi');
    },
  );
}
