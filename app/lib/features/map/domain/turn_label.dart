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
