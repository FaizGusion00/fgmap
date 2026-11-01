import 'package:dio/dio.dart';
import 'package:fgmap/core/network/connectivity_probe.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/local_assistant/data/chat_history_store.dart';
import 'package:fgmap/features/local_assistant/data/web_knowledge.dart';
import 'package:fgmap/features/local_assistant/data/web_settings.dart';
import 'package:fgmap/features/local_assistant/data/wikipedia_client.dart';
import 'package:fgmap/features/local_assistant/presentation/ai_chat_page.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';
import 'fake_llm.dart';

class _FakeWeb extends WebKnowledge {
  _FakeWeb({this.results = const [], this.failed = false})
    : super(Dio(), WikipediaClient(Dio()));

  final List<WebSnippet> results;
  final bool failed;
  final List<String> queries = [];

  @override
  Future<WebSearchResult> search(String query, {required bool malay}) async {
    queries.add(query);
    return WebSearchResult(results, failed: failed);
  }

  @override
  Future<List<WebSnippet>> news(String query, {required bool malay}) async {
    queries.add(query);
    return results;
  }

  @override
  Future<WebSnippet?> exchangeRate(String currency) async => WebSnippet(
    title: '1 $currency',
    text: 'beli/buy RM 4.0310 · jual/sell RM 4.0560',
    url: 'https://www.bnm.gov.my/exchange-rates',
    source: 'Bank Negara Malaysia',
    date: DateTime(2026, 10, 30),
  );
}

final _news = [
  WebSnippet(
    title: 'Banjir: 3,000 mangsa dipindahkan di Kelantan',
    text: '',
    url: 'https://news.google.com/a',
    source: 'Berita Harian',
    date: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  WebSnippet(
    title: 'Paras sungai meningkat di Kuala Krai',
    text: '',
    url: 'https://news.google.com/b',
    source: 'Bernama',
    date: DateTime.now().subtract(const Duration(hours: 5)),
  ),
];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(
    WidgetTester tester,
    FakeLlm llm,
    _FakeWeb web, {
    bool online = true,
  }) async {
    usePhoneSurface(tester, size: const Size(390, 860));
    reduceMotion(tester);
    await pumpApp(
      tester,
      const AiChatPage(mode: AiMode.fg),
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(llm),
        webKnowledgeProvider.overrideWithValue(web),
        onlineProbeProvider.overrideWithValue(() async => online),
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

  testWidgets(
    'berita terkini tanpa model: tajuk bersumber dan kad sumber web',
    (tester) async {
      final web = _FakeWeb(results: _news);
      await pump(tester, FakeLlm(installed: false), web);
      await send(tester, 'latest news banjir');
      expect(web.queries.single, 'banjir');
      expect(find.textContaining('Latest news: banjir'), findsOneWidget);
      expect(find.textContaining('3,000 mangsa'), findsOneWidget);
      expect(find.textContaining('Bernama'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-sources-toggle')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ai-sources-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('WEB SOURCES'), findsOneWidget);
    },
  );

  testWidgets('kadar tukaran: fakta rasmi BNM terus, tanpa model', (
    tester,
  ) async {
    final llm = FakeLlm(reply: 'model');
    await pump(tester, llm, _FakeWeb());
    await send(tester, 'kadar tukaran usd hari ini');
    expect(find.textContaining('RM 4.0310'), findsOneWidget);
    expect(find.textContaining('Bank Negara Malaysia'), findsOneWidget);
    expect(llm.lastUserText, isNull);
  });

  testWidgets(
    'dengan model: hasil web dihantar sebagai konteks, jawapan memetik sumber',
    (tester) async {
      final llm = FakeLlm(reply: 'About 3,000 people were evacuated [1].');
      final web = _FakeWeb(results: _news);
      await pump(tester, llm, web);
      await send(tester, 'who was evacuated in the floods today');
      expect(llm.lastUserText, contains('[Web results fetched'));
      expect(llm.lastUserText, contains('[1] Banjir: 3,000 mangsa'));
      expect(llm.lastUserText, contains('Question: who was evacuated'));
      expect(
        find.textContaining('3,000 people were evacuated'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ai-sources-toggle')), findsOneWidget);
    },
  );

  testWidgets(
    'carian automatik dimatikan: model menjawab dan tawarkan "Search the web"',
    (tester) async {
      await prefs.setBool(assistantAutoWebPrefsKey, false);
      final web = _FakeWeb(results: _news);
      final llm = FakeLlm(reply: 'I am not sure who won.');
      await pump(tester, llm, web);
      await send(tester, 'who won the football match yesterday');
      expect(web.queries, isEmpty);
      expect(llm.lastUserText, 'who won the football match yesterday');
      expect(find.textContaining('Search the web'), findsOneWidget);
    },
  );

  testWidgets('tiada internet: mesej luar talian yang jujur', (tester) async {
    await pump(
      tester,
      FakeLlm(installed: false),
      _FakeWeb(failed: true),
      online: false,
    );
    await send(tester, 'search online for petrol subsidy');
    expect(find.textContaining('3,000'), findsNothing);
    expect(find.textContaining('internet', findRichText: true), findsWidgets);
  });
}
