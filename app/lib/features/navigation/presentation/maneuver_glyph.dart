import 'package:flutter/material.dart';

import '../domain/nav_route.dart';
import 'navigation_hud.dart' show maneuverIcon;
import 'maneuver_diagram.dart';
import 'roundabout_exit_icon.dart';

/// Satu simbol = satu makna. Bulatan dilukis sendiri (gelang + nombor keluar); belok, kekal, susur,
/// gabung dan pusingan U dilukis sebagai gambar rajah simpang ([ManeuverDiagram]); mula, tiba dan
/// feri guna glif Material (lihat [maneuverIcon]).
class ManeuverGlyph extends StatelessWidget {
  const ManeuverGlyph({
    super.key,
    required this.kind,
    required this.size,
    required this.color,
    this.roundaboutExit,
    this.semanticsLabel,
  });

  final ManeuverKind kind;
  final int? roundaboutExit;
  final double size;
  final Color color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (kind == ManeuverKind.roundabout) {
      return RoundaboutExitIcon(
        exit: roundaboutExit,
        size: size,
        color: color,
        semanticsLabel: semanticsLabel,
      );
    }
    if (ManeuverDiagram.draws(kind)) {
      return ManeuverDiagram(kind: kind, size: size, color: color);
    }
    return Icon(
      maneuverIcon(kind),
      size: size,
      color: color,
      semanticLabel: semanticsLabel,
    );
  }
}
