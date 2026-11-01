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

  test('jawapan sebenar vs sisa sebelum panggilan alat', () {
    expect(hasSubstantiveAnswer('.'), isFalse);
    expect(hasSubstantiveAnswer('Let me check'), isFalse);
    expect(
      hasSubstantiveAnswer(
        'Yes, I can answer you. Ask me about routes, places or anything else.',
      ),
      isTrue,
    );
  });
}
