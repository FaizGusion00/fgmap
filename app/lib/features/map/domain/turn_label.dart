import 'package:flutter/foundation.dart' show immutable;

import '../../../core/utils/geo.dart';
import '../../navigation/domain/nav_route.dart';

/// Label nama jalan pada titik belok.
@immutable
class NavTurnLabel {
  const NavTurnLabel(this.point, this.text);

  final GeoPoint point;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is NavTurnLabel && other.point == point && other.text == text;

  @override
  int get hashCode => Object.hash(point, text);
}

/// Label dipaparkan hanya apabila belokan cukup dekat untuk relevan; lebih jauh ia memenuhkan peta.
const turnLabelWithinM = 1000.0;

/// Panjang paling banyak label (aksara); jalan yang lebih panjang dipotong dengan elipsis kerana
/// peta membalut teks panjang kepada berbaris-baris.
const turnLabelMaxChars = 26;

/// Label untuk [next] pada jarak [distanceM]: nama jalan yang akan dimasuki, di titik belok pada
/// [route]. Null jika tiada manuver, tiada nama jalan (hanya kod jalan juga diterima), atau
/// manuver bukan belokan (mula, tiba, feri, tiada tindakan).
NavTurnLabel? turnLabelFor(
  NavRoute route,
  NavManeuver? next,
  double? distanceM,
) {
  if (next == null || distanceM == null || distanceM > turnLabelWithinM) {
    return null;
  }
  if (next.isArrival ||
      next.kind == ManeuverKind.depart ||
      next.kind == ManeuverKind.ferry ||
      next.kind == ManeuverKind.none) {
    return null;
  }
  final name = next.street?.trim();
  if (name == null || name.isEmpty) return null;
  final text = name.length <= turnLabelMaxChars
      ? name
      : '${name.substring(0, turnLabelMaxChars - 1).trimRight()}…';
  return NavTurnLabel(route.pointAt(next.startM), text);
}

/// Anak panah belokan di peta: bahagian laluan di sekitar titik belok, dilukis dengan warna berbeza
/// daripada laluan supaya pemandu nampak TEPAT di mana dan ke arah mana hendak belok.
@immutable
class NavManeuverArrow {
  const NavManeuverArrow({
    required this.key,
    required this.line,
    required this.head,
  });

  /// Identiti (laluan + manuver): peta hanya dikemas kini bila manuver bertukar.
  final String key;

  /// Garisan dari sebelum titik belok hingga selepasnya (titik paparan laluan).
  final List<GeoPoint> line;

  /// Segi tiga kepala anak panah di hujung [line] (hujung, kiri, kanan).
  final List<GeoPoint> head;

  @override
  bool operator ==(Object other) =>
      other is NavManeuverArrow && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Anak panah dipaparkan dalam jarak ini sahaja (cukup dekat untuk zum memandu).
const maneuverArrowWithinM = 600.0;

/// Anak panah untuk [next] pada [route], atau null (tiada belokan, terlalu jauh, mula/tiba/lurus).
NavManeuverArrow? maneuverArrowFor(
  NavRoute route,
  NavManeuver? next,
  double? distanceM, {
  int routeVersion = 0,
}) {
  if (next == null || distanceM == null || distanceM > maneuverArrowWithinM) {
    return null;
  }
  switch (next.kind) {
    case ManeuverKind.depart:
    case ManeuverKind.straight:
    case ManeuverKind.keepStraight:
    case ManeuverKind.ferry:
    case ManeuverKind.none:
    case ManeuverKind.arrive:
    case ManeuverKind.arriveLeft:
    case ManeuverKind.arriveRight:
      return null;
    default:
  }
  final total = route.totalM;
  final from = (next.startM - 35).clamp(0.0, total);
  // Bulatan: seluruh lingkaran hingga jalan keluar (dihadkan), bukan hanya pintu masuk.
  final after = next.kind == ManeuverKind.roundabout
      ? (next.lengthM.clamp(0.0, 220.0) + 25)
      : 30.0;
  final to = (next.startM + after).clamp(0.0, total);
  if (to - from < 10) return null;
  final line = <GeoPoint>[
    for (var d = from; d < to; d += 2) route.displayPointAt(d),
    route.displayPointAt(to),
  ];
  final end = line.last;
  final bearing = bearingDegrees(line[line.length - 2], end);
  // Kepala kecil di atas jalan (meter): jelas pada zum memandu tanpa menutup simpang.
  const headLen = 9.0, halfWidth = 5.5;
  return NavManeuverArrow(
    key: '$routeVersion:${next.index}',
    line: line,
    head: [
      destinationPoint(end, bearing, headLen),
      destinationPoint(end, bearing - 90, halfWidth),
      destinationPoint(end, bearing + 90, halfWidth),
    ],
  );
}
