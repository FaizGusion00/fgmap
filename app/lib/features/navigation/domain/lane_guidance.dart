import '../../route_preview/domain/route_option.dart';
import 'nav_route.dart';

/// Sisi jalan yang patut diambil pemandu sebelum manuver. Data lorong sebenar (`turn:lanes`) jarang
/// ada di Malaysia, jadi petunjuk ini diterbitkan daripada jenis manuver supaya pemandu tahu "sediakan
/// lorong mana" walaupun tanpa data lorong.
enum LaneSide { left, right }

/// Sisi untuk bersedia bagi [m]; null jika tiada petunjuk berguna (lurus, tiba di hadapan).
///
/// Bulatan (lalu lintas kiri, ikut jam): keluar pertama = lorong kiri; keluar ketiga atau lebih
/// (pusing balik) = lorong kanan; keluar kedua (lurus) tiada petunjuk.
LaneSide? laneSideFor(NavManeuver m) => switch (m.kind) {
  ManeuverKind.left ||
  ManeuverKind.slightLeft ||
  ManeuverKind.sharpLeft ||
  ManeuverKind.exitLeft ||
  ManeuverKind.rampLeft ||
  ManeuverKind.keepLeft ||
  ManeuverKind.mergeLeft ||
  ManeuverKind.arriveLeft => LaneSide.left,
  ManeuverKind.right ||
  ManeuverKind.slightRight ||
  ManeuverKind.sharpRight ||
  ManeuverKind.exitRight ||
  ManeuverKind.rampRight ||
  ManeuverKind.keepRight ||
  ManeuverKind.mergeRight ||
  ManeuverKind.arriveRight ||
  ManeuverKind.uTurn => LaneSide.right,
  ManeuverKind.roundabout => switch (m.roundaboutExit) {
    1 => LaneSide.left,
    final n? when n >= 3 => LaneSide.right,
    _ => null,
  },
  _ => null,
};

/// Dalam jarak ini petunjuk lorong dipaparkan (cukup awal untuk bertukar lorong dengan selamat).
const laneHintWithinM = 700.0;

/// Arah anak panah yang digambarkan untuk satu lorong, daripada topeng bit Valhalla; susunan dari
/// kiri ke kanan supaya lukisan konsisten.
enum LaneArrow {
  sharpLeft,
  left,
  slightLeft,
  through,
  slightRight,
  right,
  sharpRight,
  reverse,
}

List<LaneArrow> laneArrows(int mask) => [
  if (mask & Lane.reverse != 0) LaneArrow.reverse,
  if (mask & Lane.sharpLeft != 0) LaneArrow.sharpLeft,
  if (mask & (Lane.left | Lane.mergeToLeft) != 0) LaneArrow.left,
  if (mask & Lane.slightLeft != 0) LaneArrow.slightLeft,
  if (mask & Lane.through != 0) LaneArrow.through,
  if (mask & Lane.slightRight != 0) LaneArrow.slightRight,
  if (mask & (Lane.right | Lane.mergeToRight) != 0) LaneArrow.right,
  if (mask & Lane.sharpRight != 0) LaneArrow.sharpRight,
];
