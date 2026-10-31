import 'dart:convert';

import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/lane_guidance.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/presentation/lane_strip.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:fgmap/features/route_preview/data/valhalla_codec.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'hud_widgets_test.dart' show m, progress;

void main() {
  group('laneSideFor', () {
    test(
      'belok dan keluar mengikut sisi; pusingan U kanan (lalu lintas kiri)',
      () {
        expect(laneSideFor(m(1, ManeuverKind.left, 0)), LaneSide.left);
        expect(laneSideFor(m(1, ManeuverKind.exitLeft, 0)), LaneSide.left);
        expect(laneSideFor(m(1, ManeuverKind.keepLeft, 0)), LaneSide.left);
        expect(laneSideFor(m(1, ManeuverKind.right, 0)), LaneSide.right);
        expect(laneSideFor(m(1, ManeuverKind.rampRight, 0)), LaneSide.right);
        expect(laneSideFor(m(1, ManeuverKind.uTurn, 0)), LaneSide.right);
        expect(laneSideFor(m(1, ManeuverKind.straight, 0)), isNull);
        expect(laneSideFor(m(1, ManeuverKind.arrive, 0)), isNull);
        expect(laneSideFor(m(1, ManeuverKind.depart, 0)), isNull);
      },
    );

    test('bulatan: keluar 1 kiri, keluar 2 tiada, keluar 3+ kanan', () {
      expect(
        laneSideFor(m(1, ManeuverKind.roundabout, 0, roundaboutExit: 1)),
        LaneSide.left,
      );
      expect(
        laneSideFor(m(1, ManeuverKind.roundabout, 0, roundaboutExit: 2)),
        isNull,
      );
      expect(
        laneSideFor(m(1, ManeuverKind.roundabout, 0, roundaboutExit: 3)),
        LaneSide.right,
      );
      expect(laneSideFor(m(1, ManeuverKind.roundabout, 0)), isNull);
    });
  });

  test(
    'frasa lorong dalam ayat awal sahaja; kekal/bergabung/tiba tidak diulang',
    () {
      const ms = InstructionText(VoiceLanguage.ms);
      const en = InstructionText(VoiceLanguage.en);
      expect(ms.lanePhrase(m(1, ManeuverKind.right, 0)), 'Guna lorong kanan.');
      expect(
        en.lanePhrase(m(1, ManeuverKind.exitLeft, 0)),
        'Use the left lane.',
      );
      expect(ms.lanePhrase(m(1, ManeuverKind.keepLeft, 0)), isNull);
      expect(ms.lanePhrase(m(1, ManeuverKind.mergeRight, 0)), isNull);
      expect(ms.lanePhrase(m(1, ManeuverKind.arriveRight, 0)), isNull);
      expect(ms.lanePhrase(m(1, ManeuverKind.straight, 0)), isNull);
      expect(
        ms.lanePhrase(m(1, ManeuverKind.roundabout, 0, roundaboutExit: 3)),
        'Guna lorong kanan.',
      );
    },
  );

  group('Lane (data Valhalla)', () {
    test('topeng bit -> anak panah, kiri ke kanan; aktif > sah > semua', () {
      expect(laneArrows(Lane.through), [LaneArrow.through]);
      expect(laneArrows(Lane.left | Lane.through), [
        LaneArrow.left,
        LaneArrow.through,
      ]);
      expect(laneArrows(Lane.reverse | Lane.sharpRight), [
        LaneArrow.reverse,
        LaneArrow.sharpRight,
      ]);
      expect(laneArrows(Lane.none), isEmpty);
      const l = Lane(
        directions: Lane.through | Lane.right,
        valid: Lane.right,
        active: Lane.right,
      );
      expect(l.shownDirections, Lane.right);
      expect(const Lane(directions: 2, valid: 2).shownDirections, 2);
      expect(const Lane(directions: 66).shownDirections, 66);
    });

    test('JSON pergi balik (bentuk Valhalla dan bentuk ringkas)', () {
      final a = Lane.fromJson({'directions': 2});
      expect(a, const Lane(directions: 2));
      final b = Lane.fromJson({'directions': 66, 'valid': 64, 'active': 64})!;
      expect(b.isActive, isTrue);
      expect(Lane.fromJson(b.toJson()), b);
      expect(Lane.fromJson({'x': 1}), isNull);
      expect(Lane.fromJson('bukan'), isNull);
    });

    test('codec Valhalla menghurai lanes; tiada lanes -> kosong', () {
      final json = {
        'trip': {
          'status': 0,
          'units': 'kilometers',
          'summary': {'length': 1.0, 'time': 60},
          'legs': [
            {
              'summary': {'length': 1.0, 'time': 60},
              'shape': r'_p~iF~ps|U_ulLnnqC',
              'maneuvers': [
                {
                  'type': 1,
                  'street_names': ['Jalan A'],
                  'length': 0.5,
                  'time': 30,
                  'begin_shape_index': 0,
                },
                {
                  'type': 10,
                  'street_names': ['Jalan B'],
                  'length': 0.5,
                  'time': 30,
                  'begin_shape_index': 1,
                  'lanes': [
                    {'directions': 2},
                    {'directions': 66, 'valid': 64, 'active': 64},
                  ],
                },
              ],
            },
          ],
        },
      };
      final route = parseRouteResponse(
        jsonEncode(json),
        source: RouteSource.online,
      ).first;
      expect(route.maneuvers.first.lanes, isEmpty);
      expect(route.maneuvers[1].lanes, hasLength(2));
      expect(route.maneuvers[1].lanes[1].isActive, isTrue);
    });
  });

  group('LaneGuidance pada kad', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      usePhoneSurface(tester);
      reduceMotion(tester);
      await pumpApp(tester, Scaffold(body: Center(child: child)));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('petunjuk sisi dalam 700 m sahaja', (tester) async {
      final right = m(1, ManeuverKind.right, 1000, streets: ['Jalan Ampang']);
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: right, distance: 900)),
      );
      expect(find.byKey(const ValueKey('lane-hint')), findsNothing);
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: right, distance: 480)),
      );
      expect(find.byKey(const ValueKey('lane-hint')), findsOneWidget);
      expect(find.text('Guna lorong kanan'), findsOneWidget);
      // Lurus: tiada petunjuk.
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(1, ManeuverKind.keepStraight, 300),
            distance: 200,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('lane-hint')), findsNothing);
    });

    testWidgets('data lorong sebenar: jalur lorong, lorong betul diserlahkan', (
      tester,
    ) async {
      const withLanes = NavManeuver(
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
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: withLanes, distance: 250)),
      );
      expect(find.byKey(const ValueKey('lane-strip')), findsOneWidget);
      expect(find.byKey(const ValueKey('lane-hint')), findsNothing);
      expect(find.byKey(const ValueKey('lane-cell-on')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('lane-cell-off')), findsOneWidget);
      expect(LaneGuidance.shows(withLanes, 250), isTrue);
      expect(LaneGuidance.shows(withLanes, 900), isFalse);
    });
  });
}
