import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/local_assistant/data/chat_history_store.dart';
import 'package:fgmap/features/local_assistant/data/edge_ai_runtime.dart';
import 'package:fgmap/features/local_assistant/data/wikipedia_client.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_models.dart';
import 'package:dio/dio.dart';
import 'package:fgmap/features/local_assistant/presentation/ai_chat_page.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';
import 'fake_llm.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(
    WidgetTester tester,
    FakeLlm llm, {
    AiMode mode = AiMode.fg,
    Locale locale = const Locale('en'),
    WikipediaClient? wiki,
  }) async {
    usePhoneSurface(tester, size: const Size(390, 860));
    reduceMotion(tester);
    await pumpApp(
      tester,
      AiChatPage(mode: mode),
      locale: locale,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(llm),
        wikipediaClientProvider.overrideWithValue(wiki ?? _FakeWiki(const {})),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('ai-input')), text);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ai-send')));
    await tester.pumpAndSettle();
  }

  testWidgets('tanpa model: kad muat turun, arahan peta masih dijawab', (
    tester,
  ) async {
    await pump(tester, FakeLlm(installed: false));
    expect(find.byKey(const ValueKey('assistant-download')), findsOneWidget);
    expect(find.text('FG AI'), findsOneWidget);

    // "Start now" tanpa laluan dijawab oleh penghala, bukan model.
    await send(tester, 'start now');
    expect(find.textContaining("There's no route yet"), findsOneWidget);
  });

  testWidgets(
    '"who are you" dan "can you answer me" dijawab tanpa model, tiada kad laluan',
    (tester) async {
      final llm = FakeLlm(reply: 'Route to Kuala Kedah is ready');
      await pump(tester, llm);
      await send(tester, 'Hi who are you?');
      expect(find.textContaining('Faiz Nasir'), findsOneWidget);
      expect(find.textContaining('FG Universal Empire'), findsOneWidget);
      await send(tester, 'Can you answer me?');
      expect(find.textContaining("Yes, I'm here"), findsOneWidget);
      expect(llm.lastUserText, isNull, reason: 'model tidak dipanggil');
      expect(find.textContaining('Kuala Kedah'), findsNothing);
      expect(find.text('Start navigation'), findsNothing);
    },
  );

  testWidgets(
    'soalan topik dijawab daripada Wikipedia; tiada perkenalan diri berulang',
    (tester) async {
      final llm = FakeLlm(reply: "Hi bro, I'm FG AI");
      await pump(
        tester,
        llm,
        wiki: _FakeWiki(const {
          'palestine':
              'Palestine — Palestine is a geographic region in West Asia. '
              'It is sometimes considered to include Israel and the '
              'Palestinian territories.',
        }),
      );
      await send(tester, 'Hi bro who are you?');
      await send(tester, 'So well wanna ask you about Palestine');
      expect(
        find.textContaining('geographic region in West Asia'),
        findsOneWidget,
      );
      expect(find.textContaining('Source: Wikipedia'), findsOneWidget);
      expect(
        llm.lastUserText,
        isNull,
        reason: 'fakta daripada Wikipedia, bukan model',
      );
    },
  );

  testWidgets('tiada rencana/internet: model menjawab, tanpa sejarah templat', (
    tester,
  ) async {
    final llm = FakeLlm(
      reply: 'Love is a deep feeling of care and attachment.',
    );
    await pump(tester, llm);
    await send(tester, 'Hi bro who are you?');
    await send(tester, 'Can you tell me the idea about love');
    expect(llm.lastUserText, 'Can you tell me the idea about love');
    expect(
      compactHistory(llm.lastHistory).where((m) => m.text.contains('FG AI')),
      isEmpty,
      reason: 'jawapan identiti tidak dihantar kepada model sebagai contoh',
    );
    expect(find.textContaining('deep feeling'), findsOneWidget);
  });

  testWidgets(
    'pilih model: 5 pilihan 3 tahap; muat turun & guna, tukar, padam',
    (tester) async {
      final llm = FakeLlm();
      await pump(tester, llm);
      await tester.tap(find.byKey(const ValueKey('ai-models')));
      await tester.pumpAndSettle();
      expect(find.text('AI models on this phone'), findsOneWidget);
      expect(find.text('Basic · fast and light'), findsOneWidget);
      for (final m in aiModelOptions) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('ai-model-${m.id}')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(m.name), findsOneWidget, reason: m.name);
      }

      // Gemma 4 E2B: muat turun terus menjadikannya model yang digunakan.
      final e2b = aiModelOptions.firstWhere((m) => m.name == 'Gemma 4 E2B');
      final dl = find.byKey(ValueKey('ai-model-download-${e2b.id}'));
      await tester.scrollUntilVisible(
        dl,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(dl);
      await tester.pumpAndSettle();
      expect(llm.downloads, [e2b.id]);
      expect(llm.selected, e2b.id);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('ai-model-${e2b.id}')),
          matching: find.text('In use'),
        ),
        findsOneWidget,
      );

      // Tukar semula ke model asas yang sudah ada (tiada muat turun).
      final basic = defaultAiModel;
      final use = find.byKey(ValueKey('ai-model-use-${basic.id}'));
      await tester.scrollUntilVisible(
        use,
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(llm.selected, basic.id);
      expect(llm.downloads, [e2b.id]);

      // Padam Gemma 4 E2B (dengan pengesahan).
      final del = find.byKey(ValueKey('ai-model-delete-${e2b.id}'));
      await tester.scrollUntilVisible(
        del,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(del);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(llm.models, isNot(contains(e2b.id)));
    },
  );

  testWidgets('BM: "siapa awak" dijawab dalam BM', (tester) async {
    final llm = FakeLlm();
    await pump(tester, llm, locale: const Locale('ms'));
    await send(tester, 'siapa awak');
    expect(find.textContaining('Saya FG AI'), findsOneWidget);
    expect(llm.lastUserText, isNull);
  });

  testWidgets('soalan umum ke model; teks dipaparkan; perbualan disimpan', (
    tester,
  ) async {
    final llm = FakeLlm(reply: 'Tolls in **Malaysia** are paid by card.');
    await pump(tester, llm);
    await send(tester, 'Explain tolls in Malaysia');
    expect(llm.lastUserText, 'Explain tolls in Malaysia');
    expect(find.textContaining('are paid by card'), findsOneWidget);
    expect(llm.warmUps, 1);

    final store = ConversationStore(prefs, AiMode.fg);
    expect(store.list().single.title, 'Explain tolls in Malaysia');
    expect(llm.lastSessionKey, store.list().single.id);

    // Sembang baharu kosongkan skrin, senarai di laci kekal.
    await tester.tap(find.byKey(const ValueKey('ai-new-chat')));
    await tester.pumpAndSettle();
    expect(find.textContaining('are paid by card'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ai-chats')));
    await tester.pumpAndSettle();
    expect(find.text('Explain tolls in Malaysia'), findsWidgets);

    // Buka semula daripada laci.
    await tester.tap(find.byKey(ValueKey('ai-conv-${store.list().single.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('are paid by card'), findsOneWidget);
  });

  testWidgets(
    'model yang membuang tool_code tidak dipaparkan dalam gelembung',
    (tester) async {
      final llm = FakeLlm(
        reply:
            'Hello! How can I help?\n'
            '<tool_code>get_weather: Current weather at GPS. Parameters: '
            '{"type": "object", "properties": {"query": {"type": "string"}}}'
            '</tool_code>',
      );
      await pump(tester, llm);
      await send(tester, 'Hello');
      expect(find.textContaining('Hello'), findsWidgets);
      expect(find.textContaining('tool_code'), findsNothing);
      expect(find.textContaining('Parameters'), findsNothing);
      expect(find.textContaining('get_weather'), findsNothing);
    },
  );

  testWidgets('soalan ciri offline dijawab tanpa model / tanpa skema alat', (
    tester,
  ) async {
    final llm = FakeLlm(reply: 'SHOULD_NOT_APPEAR <tool_code>x</tool_code>');
    await pump(tester, llm);
    await send(tester, 'What can i ask you using your ofline features?');
    expect(llm.lastUserText, isNull);
    expect(find.textContaining('SHOULD_NOT_APPEAR'), findsNothing);
    expect(find.textContaining('tool_code'), findsNothing);
    expect(find.textContaining('On-device'), findsOneWidget);
  });

  testWidgets('FGMuslim ialah halaman berasingan dengan pintu opt-in', (
    tester,
  ) async {
    await pump(
      tester,
      FakeLlm(),
      mode: AiMode.muslim,
      locale: const Locale('ms'),
    );
    expect(find.text('FGMuslim AI'), findsWidgets);
    expect(find.byKey(const ValueKey('muslim-enable')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-input')), findsNothing);
  });
}

class _FakeWiki extends WikipediaClient {
  _FakeWiki(this.pages) : super(Dio());

  final Map<String, String> pages;

  @override
  Future<String?> summary(String query, {String lang = 'ms'}) async =>
      lang == 'en' ? pages[query.toLowerCase()] : null;
}
