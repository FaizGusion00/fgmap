import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/presentation/maneuver_glyph.dart';
import 'package:fgmap/features/navigation/presentation/roundabout_exit_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );

  group('RoundaboutExitIcon', () {
    testWidgets('melukis pada pelbagai saiz dengan nombor di tengah', (
      tester,
    ) async {
      for (final size in [24.0, 52.0, 80.0]) {
        await pump(
          tester,
          RoundaboutExitIcon(exit: 2, size: size, color: Colors.white),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('2'), findsOneWidget);
        final box = tester.getSize(find.byType(RoundaboutExitIcon));
        expect(box, Size.square(size));
      }
    });

    testWidgets('tiada nombor jika keluar null atau 0', (tester) async {
      await pump(
        tester,
        const RoundaboutExitIcon(exit: null, size: 48, color: Colors.white),
      );
      expect(find.byType(Text), findsNothing);
      await pump(
        tester,
        const RoundaboutExitIcon(exit: 0, size: 48, color: Colors.white),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('nombor tidak membesar mengikut skala teks sistem', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: RoundaboutExitIcon(
                  exit: 3,
                  size: 52,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
      final text = tester.getSize(find.text('3'));
      expect(text.height, lessThan(52 * 0.6));
    });

    testWidgets('label semantik menggantikan nombor untuk pembaca skrin', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const RoundaboutExitIcon(
          exit: 2,
          size: 52,
          color: Colors.white,
          semanticsLabel: 'Bulatan, keluar 2',
        ),
      );
      expect(find.bySemanticsLabel('Bulatan, keluar 2'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ManeuverGlyph', () {
    testWidgets('bulatan -> gelang; lain -> ikon; gabung kiri dicerminkan', (
      tester,
    ) async {
      await pump(
        tester,
        const ManeuverGlyph(
          kind: ManeuverKind.roundabout,
          roundaboutExit: 4,
          size: 40,
          color: Colors.white,
        ),
      );
      expect(find.byType(RoundaboutExitIcon), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      await pump(
        tester,
        const ManeuverGlyph(
          kind: ManeuverKind.right,
          size: 40,
          color: Colors.white,
        ),
      );
      expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ManeuverGlyph),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      await pump(
        tester,
        const ManeuverGlyph(
          kind: ManeuverKind.mergeLeft,
          size: 40,
          color: Colors.white,
        ),
      );
      expect(find.byIcon(Icons.merge_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ManeuverGlyph),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    });

    testWidgets('setiap jenis manuver boleh dilukis', (tester) async {
      for (final kind in ManeuverKind.values) {
        await pump(
          tester,
          ManeuverGlyph(
            kind: kind,
            roundaboutExit: 2,
            size: 40,
            color: Colors.white,
          ),
        );
        expect(tester.takeException(), isNull, reason: kind.name);
      }
    });
  });
}
