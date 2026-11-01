import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/local_assistant/data/chat_history_store.dart';
import 'package:fgmap/features/local_assistant/presentation/ai_chat_page.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_controller.dart';
import 'package:fgmap/features/local_assistant/presentation/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';
import 'fake_llm.dart';

/// Animasi sebenar (tanpa Reduce Motion): menaip licin, auto-scroll mengikut hujung jawapan, dan
/// penunjuk berfikir yang hidup. Ujian lain menutup animasi supaya `pumpAndSettle` boleh selesai.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final reply = [
    for (var i = 1; i <= 45; i++) 'Baris nombor $i jawapan.',
  ].join('\n\n');

  Future<void> pumpPage(WidgetTester tester, FakeLlm llm) async {
    usePhoneSurface(tester, size: const Size(390, 860));
    await pumpApp(
      tester,
      const AiChatPage(mode: AiMode.fg),
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(llm),
      ],
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  ScrollPosition listPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('ai-input')), text);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ai-send')));
  }

  testWidgets('jawapan panjang ditaip licin dan skrin mengikut hujungnya', (
    tester,
  ) async {
    await pumpPage(tester, FakeLlm(reply: reply));
    await send(tester, 'Terangkan');

    // Beberapa bingkai selepas hantar: baru separuh jalan, belum sampai baris terakhir.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      find.textContaining('Baris nombor 45', skipOffstage: false),
      findsNothing,
    );
    final mid = listPosition(tester);
    expect(
      mid.maxScrollExtent,
      greaterThan(0),
      reason: 'jawapan sudah memanjang',
    );
    expect(
      mid.maxScrollExtent - mid.pixels,
      lessThan(2),
      reason: 'skrin mengikut teks yang sedang ditaip',
    );

    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Baris nombor 45'), findsOneWidget);
    final end = listPosition(tester);
    expect(end.maxScrollExtent - end.pixels, lessThan(2));
  });

  testWidgets('pengguna yang menggulung ke atas tidak ditarik ke bawah', (
    tester,
  ) async {
    await pumpPage(tester, FakeLlm(reply: reply));
    await send(tester, 'Terangkan');
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(listPosition(tester).maxScrollExtent, greaterThan(300));
    // Tarik senarai ke bawah (kandungan naik ke atas = baca bahagian awal).
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump();
    final before = listPosition(tester).pixels;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      listPosition(tester).pixels,
      closeTo(before, 1),
      reason: 'tidak merampas gulungan pengguna',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  });

  testWidgets('penunjuk berfikir: label bersinar, titik, garis rangka', (
    tester,
  ) async {
    await pumpPage(tester, FakeLlm());
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: TypingIndicator(
              color: Colors.deepPurple,
              label: 'Thinking…',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Thinking'),
      findsOneWidget,
      reason: 'elipsis jadi titik beralun',
    );
    expect(find.byType(ShaderMask), findsNWidgets(2));
    // Beranimasi: bingkai berbeza menghasilkan sapuan berbeza tanpa ralat.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
