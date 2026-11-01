import 'package:fgmap/features/local_assistant/presentation/ai_chat_page.dart'
    show streamCarry;
import 'package:fgmap/features/local_assistant/presentation/widgets/smooth_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _words = List.generate(40, (i) => 'perkataan$i').join(' ');

void main() {
  group('SmoothReveal.visiblePrefix', () {
    test('teks penuh dipulangkan apa adanya', () {
      expect(SmoothReveal.visiblePrefix('a **b** [2]', 99), 'a **b** [2]');
    });

    test('tidak memotong pasangan surrogat (emoji)', () {
      expect(SmoothReveal.visiblePrefix('a😀b', 2), 'a😀');
      expect(SmoothReveal.visiblePrefix('a😀b', 1), 'a');
    });

    test('menahan penanda separuh taip supaya tidak berkelip mentah', () {
      expect(SmoothReveal.visiblePrefix('lihat **tebal** ok', 8), 'lihat ');
      expect(SmoothReveal.visiblePrefix('lihat [2] ok', 7), 'lihat ');
      expect(SmoothReveal.visiblePrefix('lihat [12] ok', 9), 'lihat ');
      expect(SmoothReveal.visiblePrefix('lihat **teb', 11), 'lihat **teb');
    });
  });

  group('streamCarry', () {
    test('hanya awalan yang sama dan tidak melebihi yang kelihatan', () {
      expect(
        streamCarry(streamed: 'abcdef', finalText: 'abcdef!', shown: 4),
        4,
      );
      expect(streamCarry(streamed: 'abcdef', finalText: 'abXdef', shown: 5), 2);
      expect(streamCarry(streamed: 'abc', finalText: 'abcdef', shown: 9), 3);
      expect(streamCarry(streamed: 'abc', finalText: '', shown: 3), 0);
    });
  });

  group('SmoothReveal (widget)', () {
    Widget host({
      String? text,
      ValueNotifier<String>? notifier,
      bool live = false,
      int initialChars = 0,
      void Function(int)? onShown,
      VoidCallback? onProgress,
      VoidCallback? onDone,
    }) {
      final source = notifier ?? ValueNotifier<String>(text ?? '');
      return Scaffold(
        body: ValueListenableBuilder<String>(
          valueListenable: source,
          builder: (context, value, _) => SmoothReveal(
            text: value,
            live: live,
            initialChars: initialChars,
            charsPerSecond: 100,
            onShown: onShown,
            onProgress: onProgress,
            onDone: onDone,
            builder: (context, visible, done) =>
                Text(visible, key: ValueKey(done ? 'done' : 'typing')),
          ),
        ),
      );
    }

    int shownLen(WidgetTester tester) =>
        tester.widget<Text>(find.byType(Text)).data!.length;

    Future<void> frames(WidgetTester tester, int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('mendedahkan sedikit demi sedikit, bukan sekaligus', (
      tester,
    ) async {
      var done = 0;
      var progress = 0;
      await pumpApp(
        tester,
        host(text: _words, onDone: () => done++, onProgress: () => progress++),
      );
      expect(shownLen(tester), 0);
      await frames(tester, 20);
      final mid = shownLen(tester);
      expect(mid, inExclusiveRange(10, _words.length - 50));
      expect(find.byKey(const ValueKey('typing')), findsOneWidget);
      expect(progress, greaterThan(0));
      await frames(tester, 3);
      expect(shownLen(tester), greaterThan(mid), reason: 'terus maju');

      await frames(tester, 400);
      expect(find.text(_words), findsOneWidget);
      expect(find.byKey(const ValueKey('done')), findsOneWidget);
      expect(done, 1, reason: 'onDone sekali sahaja');
    });

    testWidgets(
      'kemajuan licin: tiada lompatan > beberapa aksara setiap bingkai',
      (tester) async {
        await pumpApp(tester, host(text: _words));
        var prev = 0;
        var biggest = 0;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final now = shownLen(tester);
          if (now - prev > biggest) biggest = now - prev;
          prev = now;
        }
        expect(biggest, lessThanOrEqualTo(6), reason: 'aksara demi aksara');
      },
    );

    testWidgets('initialChars: bermula daripada aksara yang sudah kelihatan', (
      tester,
    ) async {
      await pumpApp(tester, host(text: _words, initialChars: 120));
      expect(shownLen(tester), 120);
      await frames(tester, 5);
      expect(shownLen(tester), greaterThan(120));
    });

    testWidgets(
      'initialChars = seluruh teks: terus selesai (onDone dipanggil)',
      (tester) async {
        var done = 0;
        await pumpApp(
          tester,
          host(text: 'ringkas', initialChars: 999, onDone: () => done++),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('ringkas'), findsOneWidget);
        expect(done, 1);
      },
    );

    testWidgets('ketik melangkau ke teks penuh', (tester) async {
      var done = 0;
      await pumpApp(tester, host(text: _words, onDone: () => done++));
      await frames(tester, 5);
      expect(shownLen(tester), lessThan(_words.length));
      await tester.tap(find.byType(Text));
      await tester.pump();
      await tester.pump();
      expect(find.text(_words), findsOneWidget);
      expect(done, 1);
    });

    testWidgets('Reduce Motion: teks penuh serta-merta', (tester) async {
      reduceMotion(tester);
      var done = 0;
      await pumpApp(tester, host(text: _words, onDone: () => done++));
      await tester.pump();
      await tester.pump();
      expect(find.text(_words), findsOneWidget);
      expect(done, 1);
    });

    testWidgets(
      'live: token berkelompok dikejar dengan lembut, tidak pernah "selesai"',
      (tester) async {
        var shown = 0;
        final source = ValueNotifier<String>('Halo');
        await pumpApp(
          tester,
          host(notifier: source, live: true, onShown: (n) => shown = n),
        );
        await frames(tester, 30);
        expect(find.text('Halo'), findsOneWidget);

        // Segugus besar tiba sekaligus (token berkelompok).
        final burst = 'Halo $_words';
        source.value = burst;
        await tester.pump();
        await frames(tester, 3);
        expect(shown, lessThan(burst.length), reason: 'tidak melompat');
        expect(shown, greaterThan(4));
        await frames(tester, 80);
        expect(find.text(burst), findsOneWidget, reason: 'tunggakan dikejar');
        expect(find.byKey(const ValueKey('typing')), findsOneWidget);
      },
    );

    testWidgets(
      'live: teks diganti memendekkan yang kelihatan ke awalan sepunya',
      (tester) async {
        final source = ValueNotifier<String>('Hello world, ini jawapan');
        await pumpApp(tester, host(notifier: source, live: true));
        await frames(tester, 100);
        expect(find.text('Hello world, ini jawapan'), findsOneWidget);
        source.value = 'Hello dunia';
        await tester.pump();
        expect(shownLen(tester), lessThanOrEqualTo(6));
      },
    );
  });
}
