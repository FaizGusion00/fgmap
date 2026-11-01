import 'dart:convert';

import 'package:fgmap/features/local_assistant/data/chat_history_store.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AssistantMessage _m(AssistantRole role, String text) =>
    AssistantMessage(role: role, text: text, at: DateTime(2026, 11, 1, 10));

void main() {
  test('cipta, simpan, tajuk automatik, namakan semula, padam', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 11, 1, 9);
    final store = ConversationStore(prefs, AiMode.fg, clock: () => now);

    final a = store.create();
    final savedA = await store.save(a, [
      _m(AssistantRole.user, 'Route to Kuala Terengganu without tolls please'),
      _m(AssistantRole.assistant, 'Ready.'),
    ]);
    expect(savedA.title, startsWith('Route to Kuala Terengganu'));
    expect(savedA.title.length, lessThanOrEqualTo(41));

    now = now.add(const Duration(minutes: 5));
    final b = store.create();
    await store.save(b, [_m(AssistantRole.user, 'Cuaca Ipoh')]);
    expect(store.list().map((c) => c.title), ['Cuaca Ipoh', savedA.title]);

    await store.rename(a.id, 'Trip KT');
    expect(store.list().last.title, 'Trip KT');
    expect(store.messages(a.id), hasLength(2));

    final removed = await store.delete(a.id);
    expect(removed, hasLength(2));
    expect(store.list(), hasLength(1));
    expect(store.messages(a.id), isEmpty);

    // Buat asal.
    await store.save(savedA, removed);
    expect(store.list(), hasLength(2));
  });

  test('sembang lama (satu senarai) dipindahkan sekali', () async {
    SharedPreferences.setMockInitialValues({
      assistantChatPrefsKey: jsonEncode([
        _m(AssistantRole.user, 'Route to KLCC').toJson(),
        _m(AssistantRole.assistant, 'Ok').toJson(),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = ConversationStore(prefs, AiMode.fg);
    final list = store.list();
    expect(list, hasLength(1));
    expect(list.single.title, 'Route to KLCC');
    expect(store.messages(list.single.id), hasLength(2));
    expect(prefs.getString(assistantChatPrefsKey), isNull);
    // Mod lain tidak terjejas.
    expect(ConversationStore(prefs, AiMode.muslim).list(), isEmpty);
  });

  test('padam semua dan padam data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fg = ConversationStore(prefs, AiMode.fg);
    final muslim = ConversationStore(prefs, AiMode.muslim);
    await fg.save(fg.create(), [_m(AssistantRole.user, 'a')]);
    await muslim.save(muslim.create(), [_m(AssistantRole.user, 'b')]);
    await fg.deleteAll();
    expect(fg.list(), isEmpty);
    expect(muslim.list(), hasLength(1));
    await eraseConversations(prefs);
    expect(
      prefs.getKeys().where((k) => k.startsWith(conversationPrefsPrefix)),
      isEmpty,
    );
  });

  test('mesej dengan sumber dan tindakan kekal selepas disimpan', () {
    const m = AssistantMessage(
      role: AssistantRole.assistant,
      text: 'Jawapan [1]',
      notice: AnswerNotice.classicalSummary,
      sources: [
        AnswerSource(
          kind: AnswerSourceKind.classical,
          n: 1,
          title: 'Sahih Ibn Khuzayma',
          url: 'https://islamic.app/library/sahih-2/read?page=1070',
        ),
      ],
      actions: [AssistantAction(AssistantActionKind.startNavigation)],
    );
    final back = AssistantMessage.fromJson(jsonDecode(jsonEncode(m.toJson())))!;
    expect(back.sources.single.title, 'Sahih Ibn Khuzayma');
    expect(back.notice, AnswerNotice.classicalSummary);
    expect(back.actions.single.kind, AssistantActionKind.startNavigation);
  });
}
