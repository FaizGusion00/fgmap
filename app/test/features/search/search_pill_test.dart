import 'package:fgmap/features/search/presentation/search_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

SearchWavePainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(SearchWaveIcon),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((c) => c.painter)
    .whereType<SearchWavePainter>()
    .single;

void main() {
  group('SearchPill', () {
    testWidgets(
      'teks, ikon carian dan bulatan "terus"; ketik memanggil onTap',
      (tester) async {
        reduceMotion(tester);
        var taps = 0;
        await pumpApp(
          tester,
          Scaffold(
            body: Center(
              child: SearchPill(label: 'Ke mana?', onTap: () => taps++),
            ),
          ),
        );
        expect(find.text('Ke mana?'), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

        final go = tester.getSize(find.byKey(const ValueKey('search-go')));
        expect(go.width, go.height, reason: 'butang terus ialah bulatan');
        final pill = tester.getSize(find.byKey(const ValueKey('search-pill')));
        expect(pill.height, lessThanOrEqualTo(56), reason: 'padat');

        await tester.tap(find.byKey(const ValueKey('search-pill')));
        expect(taps, 1);
      },
    );

    testWidgets('semantik: butang berlabel dengan petunjuk', (tester) async {
      reduceMotion(tester);
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        Scaffold(
          body: Center(
            child: SearchPill(
              label: 'Ke mana?',
              hint: 'Tekan lama pada peta',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('search-pill'))),
        matchesSemantics(
          label: 'Ke mana?',
          hint: 'Tekan lama pada peta',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('SearchWaveIcon', () {
    testWidgets('gelombang memancar, berhenti, berehat, lalu memancar semula', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: SearchWaveIcon(
              burst: Duration(milliseconds: 400),
              rest: Duration(milliseconds: 300),
              firstDelay: Duration(milliseconds: 100),
            ),
          ),
        ),
      );
      final painter = _painter(tester);
      expect(painter.progress.value, 0, reason: 'tenang sebelum pancaran');

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter.progress.value, inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 500));
      expect(painter.progress.value, 1, reason: 'pancaran habis');

      // Berehat, kemudian pancaran kedua bermula.
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter.progress.value, inExclusiveRange(0, 1));

      // Buang dari pokok: tiada pemasa tertinggal (flutter_test gagal jika ada).
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Reduce Motion: tiada gelombang langsung', (tester) async {
      reduceMotion(tester);
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: SearchWaveIcon(firstDelay: Duration(milliseconds: 10)),
          ),
        ),
      );
      final painter = _painter(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(painter.progress.value, 0);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('pumpAndSettle boleh selesai (tiada gelung tanpa henti)', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(body: Center(child: SearchWaveIcon())),
      );
      await tester.pumpAndSettle();
    });
  });
}
