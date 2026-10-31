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
}
