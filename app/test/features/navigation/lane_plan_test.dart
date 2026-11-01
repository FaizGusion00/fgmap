import 'package:fgmap/features/navigation/domain/lane_guidance.dart';
import 'package:fgmap/features/navigation/domain/lane_plan.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hud_widgets_test.dart' show m;

NavManeuver withLanes(
  List<Lane> lanes, {
  ManeuverKind kind = ManeuverKind.right,
}) => NavManeuver(
  index: 1,
  kind: kind,
  startM: 0,
  lengthM: 100,
  timeS: 10,
  streetNames: const [],
  lanes: lanes,
);

void main() {
  group('lanePlanFor: anggaran daripada jenis manuver (tiada data lorong)', () {
    test('belok kanan: lorong kanan disyorkan, lalu lintas kiri', () {
      final plan = lanePlanFor(m(1, ManeuverKind.right, 0))!;
      expect(plan.estimated, isTrue);
      expect(plan.lanes, hasLength(2));
      expect(plan.lanes[0].recommended, isFalse);
      expect(plan.lanes[1].recommended, isTrue);
      expect(plan.lanes[1].arrows, [LaneArrow.right]);
      expect(plan.lanes[1].highlighted, [LaneArrow.right]);
      expect(plan.lanes[0].highlighted, isEmpty);
      expect(plan.hint!.kind, LaneHintKind.rightmost);
    });

    test('belok kiri: lorong kiri disyorkan', () {
      final plan = lanePlanFor(m(1, ManeuverKind.left, 0))!;
      expect(plan.lanes[0].recommended, isTrue);
      expect(plan.lanes[0].arrows, [LaneArrow.left]);
      expect(plan.hint!.kind, LaneHintKind.leftmost);
    });

    test('kekal kanan/kiri: dua cabang, hanya satu disyorkan', () {
      final keepRight = lanePlanFor(m(1, ManeuverKind.keepRight, 0))!;
      expect(keepRight.lanes.map((l) => l.recommended), [false, true]);
      expect(keepRight.lanes.map((l) => l.arrows.single), [
        LaneArrow.slightLeft,
        LaneArrow.slightRight,
      ]);
      final keepLeft = lanePlanFor(m(1, ManeuverKind.keepLeft, 0))!;
      expect(keepLeft.lanes.map((l) => l.recommended), [true, false]);
    });

    test('susur keluar dan pusingan U ikut sisi laluan', () {
      expect(
        lanePlanFor(m(1, ManeuverKind.exitLeft, 0))!.hint!.kind,
        LaneHintKind.leftmost,
      );
      expect(
        lanePlanFor(m(1, ManeuverKind.rampRight, 0))!.hint!.kind,
        LaneHintKind.rightmost,
      );
      final u = lanePlanFor(m(1, ManeuverKind.uTurn, 0))!;
      expect(u.lanes.last.arrows, [LaneArrow.reverse]);
      expect(u.lanes.last.recommended, isTrue);
    });

    test('tiada kotak untuk lurus, bergabung, mula, tiba, bulatan', () {
      for (final k in [
        ManeuverKind.straight,
        ManeuverKind.keepStraight,
        ManeuverKind.merge,
        ManeuverKind.mergeLeft,
        ManeuverKind.mergeRight,
        ManeuverKind.depart,
        ManeuverKind.arrive,
        ManeuverKind.arriveRight,
        ManeuverKind.roundabout,
        ManeuverKind.ferry,
        ManeuverKind.none,
      ]) {
        expect(lanePlanFor(m(1, k, 0)), isNull, reason: k.name);
      }
    });

    test('setiap anggaran sepadan dengan sisi petunjuk lama (laneSideFor)', () {
      for (final k in ManeuverKind.values) {
        final plan = lanePlanFor(m(1, k, 0));
        if (plan == null) continue;
        final hint = plan.hint!;
        final side = laneSideFor(m(1, k, 0))!;
        expect(
          hint.kind,
          side == LaneSide.left
              ? LaneHintKind.leftmost
              : LaneHintKind.rightmost,
          reason: k.name,
        );
      }
    });
  });

  group('lanePlanFor: data lorong sebenar Valhalla', () {
    test('lorong sah/aktif disorot dan bukan anggaran', () {
      final plan = lanePlanFor(
        withLanes(const [
          Lane(directions: Lane.through),
          Lane(directions: Lane.through | Lane.right, valid: Lane.right),
          Lane(directions: Lane.right, active: Lane.right),
        ]),
      )!;
      expect(plan.estimated, isFalse);
      expect(plan.lanes.map((l) => l.recommended), [false, true, true]);
      expect(plan.lanes[1].arrows, [LaneArrow.through, LaneArrow.right]);
      expect(plan.hint!.kind, LaneHintKind.rightmost);
      expect(plan.hint!.count, 2);
      // Dalam lorong "lurus + kanan" hanya arah sah ("kanan") menyala; "lurus" dimalapkan.
      expect(plan.lanes[1].highlighted, [LaneArrow.right]);
      expect(plan.lanes[0].highlighted, isEmpty);
      // Arah aktif didahulukan daripada arah sah.
      final active = lanePlanFor(
        withLanes(const [
          Lane(directions: Lane.through | Lane.slightRight | Lane.right),
          Lane(
            directions: Lane.slightRight | Lane.right,
            valid: Lane.slightRight | Lane.right,
            active: Lane.right,
          ),
        ]),
      )!;
      expect(active.lanes[1].highlighted, [LaneArrow.right]);
    });

    test('satu lorong sahaja: tiada pilihan, tiada kotak', () {
      expect(
        lanePlanFor(
          withLanes(const [Lane(directions: Lane.right, valid: Lane.right)]),
        ),
        isNull,
      );
    });

    test(
      'data tanpa sah/aktif: dilukis tetapi tiada sorotan dan tiada ayat',
      () {
        final plan = lanePlanFor(
          withLanes(const [
            Lane(directions: Lane.through),
            Lane(directions: Lane.right),
          ]),
        )!;
        expect(plan.hasHighlight, isFalse);
        expect(plan.hint, isNull);
      },
    );

    test('lorong tengah disebut dari sisi yang lebih dekat', () {
      LaneHint? hintFor(int n, int picked) => lanePlanFor(
        withLanes([
          for (var i = 0; i < n; i++)
            Lane(
              directions: Lane.through,
              valid: i == picked ? Lane.through : 0,
            ),
        ]),
      )?.hint;
      expect(hintFor(5, 1)!.kind, LaneHintKind.nthFromLeft);
      expect(hintFor(5, 1)!.count, 2);
      expect(hintFor(5, 3)!.kind, LaneHintKind.nthFromRight);
      expect(hintFor(5, 3)!.count, 2);
      expect(hintFor(5, 0)!.kind, LaneHintKind.leftmost);
      expect(hintFor(5, 4)!.kind, LaneHintKind.rightmost);
    });

    test('lorong tidak bersebelahan atau semua sah: tiada ayat palsu', () {
      final split = lanePlanFor(
        withLanes(const [
          Lane(directions: Lane.left, valid: Lane.left),
          Lane(directions: Lane.through),
          Lane(directions: Lane.left, valid: Lane.left),
        ]),
      )!;
      expect(split.hint, isNull);
      final all = lanePlanFor(
        withLanes(const [
          Lane(directions: Lane.through, valid: Lane.through),
          Lane(directions: Lane.through, valid: Lane.through),
        ]),
      )!;
      expect(all.hint, isNull);
    });
  });

  group('roundaboutPlanFor', () {
    test('keluar diambil; sekurang-kurangnya tiga keluar dilukis', () {
      final p = roundaboutPlanFor(
        m(1, ManeuverKind.roundabout, 0, roundaboutExit: 1),
      )!;
      expect(p.exit, 1);
      expect(p.exits, 3);
      final big = roundaboutPlanFor(
        m(1, ManeuverKind.roundabout, 0, roundaboutExit: 5),
      )!;
      expect(big.exits, 5);
    });

    test('tiada nombor keluar atau bukan bulatan: null', () {
      expect(roundaboutPlanFor(m(1, ManeuverKind.roundabout, 0)), isNull);
      expect(
        roundaboutPlanFor(m(1, ManeuverKind.roundabout, 0, roundaboutExit: 0)),
        isNull,
      );
      expect(
        roundaboutPlanFor(m(1, ManeuverKind.right, 0, roundaboutExit: 2)),
        isNull,
      );
    });
  });

  group('laneViewWithinM', () {
    test('lebih jauh pada kelajuan tinggi; dihad; motosikal lebih awal', () {
      double car(double v) => laneViewWithinM(speedMps: v, motorcycle: false);
      double bike(double v) => laneViewWithinM(speedMps: v, motorcycle: true);
      expect(car(0), 200);
      expect(car(13.9), closeTo(278, 1));
      expect(car(40), 500);
      expect(bike(0), 260);
      expect(bike(40), 650);
      for (final v in [0.0, 5.0, 13.9, 25.0, 40.0]) {
        expect(bike(v), greaterThan(car(v)), reason: '$v m/s');
      }
    });

    test('kelajuan tidak sah (NaN, negatif) tidak merosakkan', () {
      expect(laneViewWithinM(speedMps: double.nan, motorcycle: false), 200);
      expect(laneViewWithinM(speedMps: -5, motorcycle: true), 260);
    });
  });
}
