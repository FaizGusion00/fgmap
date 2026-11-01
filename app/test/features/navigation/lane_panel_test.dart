import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/presentation/lane_view.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'hud_widgets_test.dart' show m, progress;

void main() {
  const realLanes = NavManeuver(
    index: 1,
    kind: ManeuverKind.right,
    startM: 300,
    lengthM: 100,
    timeS: 10,
    streetNames: ['Jalan B'],
    lanes: [
      Lane(directions: Lane.through),
      Lane(directions: Lane.through | Lane.right, valid: Lane.right),
      Lane(directions: Lane.right, valid: Lane.right, active: Lane.right),
    ],
  );
  final estimated = m(
    1,
    ManeuverKind.right,
    300,
    streets: ['Persiaran Bestari'],
  );
  final roundabout = m(1, ManeuverKind.roundabout, 300, roundaboutExit: 2);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size? size,
    Locale locale = const Locale('ms'),
  }) async {
    if (size == null) {
      usePhoneSurface(tester);
    } else {
      usePhoneSurface(tester, size: size);
    }
    reduceMotion(tester);
    await pumpApp(
      tester,
      Scaffold(body: Center(child: child)),
      locale: locale,
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder panel() => find.byKey(const ValueKey('lane-panel'));

  group('LanePanel.shows', () {
    test('jarak mengikut kelajuan dan kenderaan', () {
      bool shows(NavManeuver mv, double d, double v, {bool bike = false}) =>
          LanePanel.shows(mv, distanceM: d, speedMps: v, motorcycle: bike);
      expect(shows(estimated, 130, 13.9), isTrue);
      expect(shows(estimated, 300, 13.9), isFalse);
      // Motosikal dengan kelajuan sama nampak lebih awal (361 m).
      expect(shows(estimated, 300, 13.9, bike: true), isTrue);
      expect(shows(estimated, 400, 13.9, bike: true), isFalse);
      // Laju: lebih awal, tetapi tidak melebihi 500 m (kereta).
      expect(shows(estimated, 480, 30), isTrue);
      expect(shows(estimated, 520, 30), isFalse);
    });

    test('bulatan dengan nombor keluar ada kotak; tanpa nombor tiada', () {
      bool shows(NavManeuver mv) => LanePanel.shows(
        mv,
        distanceM: 100,
        speedMps: 13.9,
        motorcycle: false,
      );
      expect(shows(roundabout), isTrue);
      expect(shows(m(1, ManeuverKind.roundabout, 0)), isFalse);
      expect(shows(m(1, ManeuverKind.straight, 0)), isFalse);
      expect(shows(m(1, ManeuverKind.arriveRight, 0)), isFalse);
    });
  });

  group('kad manuver', () {
    testWidgets('anggaran: kotak dengan cip "Anggaran lorong" dan ayat sisi', (
      tester,
    ) async {
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: estimated, distance: 130)),
      );
      expect(panel(), findsOneWidget);
      expect(find.byKey(const ValueKey('lane-estimate-chip')), findsOneWidget);
      expect(find.text('Anggaran lorong'), findsOneWidget);
      expect(find.text('Guna lorong paling kanan'), findsOneWidget);
      // Jalur kecil tidak dilukis dua kali bersama kotak besar.
      expect(find.byKey(const ValueKey('lane-strip')), findsNothing);
    });

    testWidgets('data sebenar: kotak tanpa cip anggaran', (tester) async {
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: realLanes, distance: 200)),
      );
      expect(panel(), findsOneWidget);
      expect(find.byKey(const ValueKey('lane-estimate-chip')), findsNothing);
      expect(find.text('Guna 2 lorong paling kanan'), findsOneWidget);
    });

    testWidgets('semantik kotak menyebut lorong yang disyorkan', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: realLanes, distance: 200)),
      );
      expect(
        find.bySemanticsLabel('Paparan lorong. Guna 2 lorong paling kanan'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('English', (tester) async {
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: estimated, distance: 130)),
        locale: const Locale('en'),
      );
      expect(find.text('Estimated lane'), findsOneWidget);
      expect(find.text('Use the rightmost lane'), findsOneWidget);
    });

    testWidgets('terlalu jauh: tiada kotak, hanya ayat', (tester) async {
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: estimated, distance: 450)),
      );
      expect(panel(), findsNothing);
      expect(find.text('Guna lorong paling kanan'), findsOneWidget);
    });

    testWidgets('motosikal nampak kotak lebih awal daripada kereta', (
      tester,
    ) async {
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: estimated, distance: 330)),
      );
      expect(panel(), findsNothing);
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(next: estimated, distance: 330),
          motorcycle: true,
        ),
      );
      expect(panel(), findsOneWidget);
    });

    testWidgets('mendatar: tiada kotak besar (jaga pandangan jalan)', (
      tester,
    ) async {
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: estimated, distance: 100)),
        size: const Size(844, 390),
      );
      expect(panel(), findsNothing);
      expect(find.byKey(const ValueKey('lane-hint')), findsOneWidget);
    });

    testWidgets('bulatan: kotak ada tetapi tidak diumumkan dua kali', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: roundabout, distance: 120)),
      );
      expect(panel(), findsOneWidget);
      expect(find.byKey(const ValueKey('lane-estimate-chip')), findsNothing);
      expect(
        find.bySemanticsLabel('Bulatan, ambil simpang keluar ke-2'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('ketinggian kad dengan kotak masih muat pada telefon kecil', (
      tester,
    ) async {
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: estimated, distance: 100)),
        size: const Size(360, 640),
      );
      final card = tester.getSize(find.byType(ManeuverBanner));
      // Kad tidak boleh menelan lebih separuh skrin 640 px.
      expect(card.height, lessThan(320));
      expect(tester.takeException(), isNull);
    });
  });
}
