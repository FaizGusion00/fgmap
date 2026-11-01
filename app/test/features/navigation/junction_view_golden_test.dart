@Tags(['golden'])
library;

import 'package:fgmap/features/navigation/domain/junction.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/presentation/lane_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Gambar simpang sebenar (laporan penguji 2026-11-02): simpang 4, simpang 3, simpang Y dan bulatan,
/// setiap jalan pada sudut sebenarnya dan laluan biru dengan anak panah ke jalan yang diambil.
void main() {
  setUpAll(loadAppFonts);

  NavManeuver m(ManeuverKind kind, {int? exit}) => NavManeuver(
    index: 1,
    kind: kind,
    startM: 300,
    lengthM: 100,
    timeS: 10,
    streetNames: const ['Jalan B'],
    roundaboutExit: exit,
  );

  final cases = <(String, NavManeuver, Junction)>[
    (
      'simpang 4, belok kanan',
      m(ManeuverKind.right),
      const Junction(
        kind: JunctionKind.cross,
        exitDeg: 88,
        otherArmsDeg: [-2, -91],
      ),
    ),
    (
      'simpang 3, belok kiri',
      m(ManeuverKind.left),
      const Junction(kind: JunctionKind.tee, exitDeg: -90, otherArmsDeg: [92]),
    ),
    (
      'simpang 3 (lurus ada), belok kanan serong',
      m(ManeuverKind.slightRight),
      const Junction(kind: JunctionKind.tee, exitDeg: 40, otherArmsDeg: [-3]),
    ),
    (
      'bulatan, keluar ke-2 (lurus)',
      m(ManeuverKind.roundabout, exit: 2),
      const Junction(
        kind: JunctionKind.roundabout,
        exitDeg: 4,
        otherArmsDeg: [-95],
        roundaboutExit: 2,
      ),
    ),
    (
      'bulatan, keluar ke-3 (kanan)',
      m(ManeuverKind.roundabout, exit: 3),
      const Junction(
        kind: JunctionKind.roundabout,
        exitDeg: 85,
        otherArmsDeg: [-80, 10],
        roundaboutExit: 3,
      ),
    ),
  ];

  testWidgets('lembaran gambar simpang', (tester) async {
    tester.view.physicalSize = const Size(800, 1900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: ColoredBox(
          color: const Color(0xFF14284F),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final (label, maneuver, junction) in cases) ...[
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  LanePanel(
                    maneuver: maneuver,
                    background: const Color(0xFF14284F),
                    foreground: Colors.white,
                    junction: junction,
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Simpang 4'), findsOneWidget);
    expect(find.text('Bulatan · keluar ke-2'), findsOneWidget);
    expect(find.text('Anggaran lorong'), findsNothing);
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/junction_views.png'),
    );
  });
}
