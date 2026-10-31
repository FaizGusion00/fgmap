@Tags(['golden'])
library;

import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/presentation/maneuver_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Lembaran semua gambar rajah manuver pada warna kad sebenar (biru tua + putih), supaya setiap simbol
/// boleh disemak sekilas: bentuk simpang, cabang yang tidak diambil (pudar) dan anak panah tebal.
void main() {
  setUpAll(loadAppFonts);

  const kinds = [
    ManeuverKind.straight,
    ManeuverKind.right,
    ManeuverKind.left,
    ManeuverKind.slightRight,
    ManeuverKind.slightLeft,
    ManeuverKind.sharpRight,
    ManeuverKind.sharpLeft,
    ManeuverKind.uTurn,
    ManeuverKind.keepRight,
    ManeuverKind.keepLeft,
    ManeuverKind.exitRight,
    ManeuverKind.exitLeft,
    ManeuverKind.rampRight,
    ManeuverKind.rampLeft,
    ManeuverKind.mergeRight,
    ManeuverKind.mergeLeft,
    ManeuverKind.roundabout,
    ManeuverKind.depart,
    ManeuverKind.arrive,
    ManeuverKind.ferry,
  ];

  testWidgets('lembaran gambar rajah manuver', (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: ColoredBox(
          color: const Color(0xFF14284F),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final k in kinds)
                  SizedBox(
                    width: 82,
                    child: Column(
                      children: [
                        ManeuverGlyph(
                          kind: k,
                          size: 72,
                          color: Colors.white,
                          roundaboutExit: 2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          k.name,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        // Saiz jalur "Kemudian".
                        const SizedBox(height: 4),
                        ManeuverGlyph(
                          kind: k,
                          size: 26,
                          color: Colors.white,
                          roundaboutExit: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/maneuver_diagrams.png'),
    );
  });
}
