import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../../route_preview/domain/route_option.dart';
import 'lane_guidance.dart';
import 'nav_route.dart';

/// Satu lorong yang dilukis pada paparan lorong: anak panah yang dibenarkan dan sama ada pemandu
/// patut menggunakannya.
@immutable
class LaneSlot {
  const LaneSlot({
    required this.arrows,
    this.recommended = false,
    this.highlighted = const [],
  });

  final List<LaneArrow> arrows;
  final bool recommended;

  /// Anak panah dalam lorong ini yang sebenarnya disyorkan (cth. hanya "kanan" dalam lorong
  /// "lurus + kanan"); kosong jika lorong tidak disyorkan. Subset [arrows].
  final List<LaneArrow> highlighted;
}

/// Lorong yang disyorkan, diterangkan supaya boleh diayatkan ("paling kanan", "lorong 2 dari kiri").
enum LaneHintKind { leftmost, rightmost, nthFromLeft, nthFromRight }

@immutable
class LaneHint {
  const LaneHint(this.kind, this.count);

  final LaneHintKind kind;

  /// Bilangan lorong bersebelahan yang disyorkan (leftmost/rightmost), atau nombor lorong
  /// (nthFrom*, mulai 1).
  final int count;
}

/// Susunan lorong untuk satu manuver, kiri ke kanan, untuk dilukis oleh `LaneView`.
///
/// Dua sumber: data lorong sebenar Valhalla (`turn:lanes`; [estimated] palsu) dan, apabila tiada
/// (kebiasaan di Malaysia), satu susunan ringkas yang diterbitkan daripada jenis manuver ([estimated]
/// benar). Susunan anggaran hanya menyatakan SISI lorong (kiri/kanan), bukan lorong tertentu,
/// kerana bilangan lorong sebenar tidak diketahui: paparan menandakannya jelas sebagai anggaran.
@immutable
class LanePlan {
  const LanePlan({required this.lanes, required this.estimated});

  final List<LaneSlot> lanes;
  final bool estimated;

  bool get hasHighlight => lanes.any((l) => l.recommended);

  /// Penerangan lorong yang disyorkan; null jika tiada sorotan, semua lorong sah, atau lorong yang
  /// disyorkan tidak bersebelahan (tiada ayat ringkas yang jujur).
  LaneHint? get hint {
    final picked = [
      for (var i = 0; i < lanes.length; i++)
        if (lanes[i].recommended) i,
    ];
    if (picked.isEmpty || picked.length == lanes.length) return null;
    final first = picked.first;
    final last = picked.last;
    if (last - first + 1 != picked.length) return null;
    final n = lanes.length;
    if (last == n - 1) return LaneHint(LaneHintKind.rightmost, picked.length);
    if (first == 0) return LaneHint(LaneHintKind.leftmost, picked.length);
    if (picked.length != 1) return null;
    // Lorong tengah: dikira dari sisi yang lebih dekat supaya nombornya kecil.
    final fromLeft = first + 1;
    final fromRight = n - first;
    return fromLeft <= fromRight
        ? LaneHint(LaneHintKind.nthFromLeft, fromLeft)
        : LaneHint(LaneHintKind.nthFromRight, fromRight);
  }
}

/// Pelan lorong bagi [m]; null jika tiada pilihan lorong untuk ditunjukkan (lurus, ketibaan,
/// bergabung, bulatan, atau satu lorong sahaja).
LanePlan? lanePlanFor(NavManeuver m) {
  if (m.isArrival || m.kind == ManeuverKind.roundabout) return null;
  if (m.lanes.isNotEmpty) return _realPlan(m.lanes);
  return _estimatedPlan(m.kind);
}

LanePlan? _realPlan(List<Lane> lanes) {
  // Satu lorong tiada pilihan untuk dibuat.
  if (lanes.length < 2) return null;
  return LanePlan(
    estimated: false,
    lanes: [
      for (final l in lanes)
        LaneSlot(
          arrows: laneArrows(l.directions),
          recommended: l.isActive || l.isValid,
          highlighted: [
            if (l.isActive || l.isValid)
              for (final a in laneArrows(l.active != 0 ? l.active : l.valid))
                if (laneArrows(l.directions).contains(a)) a,
          ],
        ),
    ],
  );
}

/// Lalu lintas sebelah kiri (Malaysia): belok kiri dari lorong paling kiri, belok kanan dari lorong
/// paling kanan, pusingan U dari lorong paling kanan. Dua lorong cukup untuk menunjuk sisi tanpa
/// mengaku tahu bilangan lorong sebenar.
LanePlan? _estimatedPlan(ManeuverKind kind) {
  LanePlan turn(LaneArrow arrow, {required bool right}) {
    const through = LaneSlot(arrows: [LaneArrow.through]);
    final turning = LaneSlot(
      arrows: [arrow],
      recommended: true,
      highlighted: [arrow],
    );
    return LanePlan(
      estimated: true,
      lanes: right ? [through, turning] : [turning, through],
    );
  }

  LanePlan fork({required bool right}) => LanePlan(
    estimated: true,
    lanes: [
      LaneSlot(
        arrows: const [LaneArrow.slightLeft],
        recommended: !right,
        highlighted: right ? const [] : const [LaneArrow.slightLeft],
      ),
      LaneSlot(
        arrows: const [LaneArrow.slightRight],
        recommended: right,
        highlighted: right ? const [LaneArrow.slightRight] : const [],
      ),
    ],
  );

  return switch (kind) {
    ManeuverKind.left => turn(LaneArrow.left, right: false),
    ManeuverKind.slightLeft => turn(LaneArrow.slightLeft, right: false),
    ManeuverKind.sharpLeft => turn(LaneArrow.sharpLeft, right: false),
    ManeuverKind.right => turn(LaneArrow.right, right: true),
    ManeuverKind.slightRight => turn(LaneArrow.slightRight, right: true),
    ManeuverKind.sharpRight => turn(LaneArrow.sharpRight, right: true),
    ManeuverKind.exitLeft ||
    ManeuverKind.rampLeft => turn(LaneArrow.slightLeft, right: false),
    ManeuverKind.exitRight ||
    ManeuverKind.rampRight => turn(LaneArrow.slightRight, right: true),
    ManeuverKind.keepLeft => fork(right: false),
    ManeuverKind.keepRight => fork(right: true),
    ManeuverKind.uTurn => turn(LaneArrow.reverse, right: true),
    _ => null,
  };
}

/// Bulatan untuk dilukis: keluar ke berapa dan berapa banyak jalan keluar yang digambarkan.
///
/// Valhalla hanya memberitahu nombor keluar yang diambil, bukan jumlah keluar bulatan itu. Jadi
/// jalan lain dilukis sebagai skema (sekurang-kurangnya tiga keluar, empat jalan termasuk jalan
/// masuk) dan hanya keluar yang diambil ditonjolkan; tidak ada bilangan palsu dipaparkan sebagai fakta.
@immutable
class RoundaboutPlan {
  const RoundaboutPlan({required this.exit, required this.exits});

  /// Keluar yang diambil (mulai 1, dikira ikut arah lalu lintas dari jalan masuk).
  final int exit;

  /// Bilangan jalan keluar yang dilukis (tidak termasuk jalan masuk).
  final int exits;
}

RoundaboutPlan? roundaboutPlanFor(NavManeuver m) {
  final exit = m.roundaboutExit;
  if (m.kind != ManeuverKind.roundabout || exit == null || exit < 1) {
    return null;
  }
  return RoundaboutPlan(exit: exit, exits: math.max(3, exit));
}

/// Jarak (m) dari manuver di mana paparan lorong besar muncul. Lebih awal pada kelajuan tinggi
/// supaya sempat bertukar lorong; motosikal lebih awal lagi kerana bertukar lorong antara kenderaan
/// lain lebih berisiko bagi penunggang, jadi mereka perlukan lebih masa untuk bersedia.
double laneViewWithinM({required double speedMps, required bool motorcycle}) {
  final v = speedMps.isFinite ? math.max(0.0, speedMps) : 0.0;
  return motorcycle
      ? (v * 26).clamp(260.0, 650.0)
      : (v * 20).clamp(200.0, 500.0);
}
