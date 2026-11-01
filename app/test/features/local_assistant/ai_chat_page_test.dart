import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/local_assistant/data/chat_history_store.dart';
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
