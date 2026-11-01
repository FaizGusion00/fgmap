import 'package:fgmap/core/settings/easy_mode_scope.dart';
import 'package:fgmap/features/map/presentation/map_tool_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('MapToolRailPlan.fit', () {
    // Lebar kandungan skrin utama = lebar telefon - 24; pil solat dikhaskan 140 + jurang 8.
    double budgetFor(double phoneWidth) => phoneWidth - 24 - 140 - 8;

    test(
      '390 dp: kelima-lima alat, butang 36 (maksimum), muat dalam bajet',
      () {
        final plan = MapToolRailPlan.fit(budget: budgetFor(390), count: 5);
        expect(plan.visible, 5);
        expect(plan.overflow, isFalse);
        expect(plan.button, 36);
        expect(plan.width, lessThanOrEqualTo(budgetFor(390)));
      },
    );

    test('360 dp: kelima-lima alat dengan butang dikecilkan, tidak < 32', () {
      final plan = MapToolRailPlan.fit(budget: budgetFor(360), count: 5);
      expect(plan.visible, 5);
      expect(plan.overflow, isFalse);
      expect(plan.button, inInclusiveRange(32, 36));
      expect(plan.width, lessThanOrEqualTo(budgetFor(360)));
    });

    test('320 dp: alat terakhir masuk menu "lagi"; semua muat dalam bajet', () {
      final plan = MapToolRailPlan.fit(budget: budgetFor(320), count: 5);
      expect(plan.visible, lessThan(5));
      expect(plan.overflow, isTrue);
      expect(plan.button, greaterThanOrEqualTo(32));
      expect(plan.width, lessThanOrEqualTo(budgetFor(320)));
    });

    test('bajet sangat kecil: hanya butang "lagi"', () {
      final plan = MapToolRailPlan.fit(budget: 40, count: 5);
      expect(plan.visible, 0);
      expect(plan.overflow, isTrue);
    });

    test('Mod mudah: butang >= 44 dan lebih awal masuk menu lagi', () {
      final normal = MapToolRailPlan.fit(budget: 218, count: 5);
      final easy = MapToolRailPlan.fit(
        budget: 218,
        count: 5,
        minButton: 44,
        maxButton: 52,
        gap: 4,
        pad: 4,
      );
      expect(easy.button, greaterThanOrEqualTo(44));
      expect(easy.visible, lessThan(normal.visible));
      expect(easy.overflow, isTrue);
    });
  });

  group('MapToolsRow', () {
    final taps = <String>[];
    setUp(taps.clear);

    List<MapToolSpec> tools() => [
      for (final n in ['Cuaca', 'Udara', 'Kiblat', 'Muzik', 'Peta'])
        MapToolSpec(
          icon: Icons.circle,
          label: n,
          color: Colors.blue,
          onPressed: () => taps.add(n),
        ),
    ];

    Future<void> pump(
      WidgetTester tester, {
      required double width,
      bool easy = false,
    }) async {
      reduceMotion(tester);
      await pumpApp(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: EasyModeScope(
                enabled: easy,
                child: MapToolsRow(
                  tools: tools(),
                  leading: Container(
                    key: const ValueKey('leading'),
                    width: 140,
                    height: 44,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('lebar 366 (telefon 390): lima butang, pil kekal dalam ruang', (
      tester,
    ) async {
      await pump(tester, width: 366);
      expect(tester.takeException(), isNull);
      for (final n in ['Cuaca', 'Udara', 'Kiblat', 'Muzik', 'Peta']) {
        expect(find.byTooltip(n), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('tool-rail-more')), findsNothing);
      final rail = tester.getRect(find.byKey(const ValueKey('tool-rail')));
      final lead = tester.getRect(find.byKey(const ValueKey('leading')));
      expect(lead.right, lessThanOrEqualTo(rail.left));
      expect(rail.height, lessThanOrEqualTo(44));
      expect(rail.right, lessThanOrEqualTo(366));
    });

    testWidgets('lebar 336 (telefon 360): masih lima butang tanpa limpahan', (
      tester,
    ) async {
      await pump(tester, width: 336);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Peta'), findsOneWidget);
      final size = tester.getSize(find.byTooltip('Cuaca'));
      expect(size.width, greaterThanOrEqualTo(32));
      final lead = tester.getRect(find.byKey(const ValueKey('leading')));
      expect(lead.width, 140, reason: 'pil tidak dihimpit di bawah lebarnya');
    });

    testWidgets('lebar 290: butang "lagi" membuka menu alat tersembunyi', (
      tester,
    ) async {
      await pump(tester, width: 290);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('tool-rail-more')), findsOneWidget);
      expect(find.byTooltip('Peta'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tool-rail-more')));
      await tester.pumpAndSettle();
      expect(find.text('Peta'), findsOneWidget);
      await tester.tap(find.text('Peta'));
      await tester.pumpAndSettle();
      expect(taps, ['Peta']);
    });

    testWidgets('ketik butang memanggil alatnya', (tester) async {
      await pump(tester, width: 366);
      await tester.tap(find.byTooltip('Kiblat'));
      expect(taps, ['Kiblat']);
    });

    testWidgets('Mod mudah: butang sekurang-kurangnya 44 dp', (tester) async {
      await pump(tester, width: 366, easy: true);
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byTooltip('Cuaca'));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
