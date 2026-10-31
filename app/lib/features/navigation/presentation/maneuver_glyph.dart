import 'package:flutter/material.dart';

import '../domain/nav_route.dart';
import 'navigation_hud.dart' show maneuverIcon;
import 'roundabout_exit_icon.dart';

/// Satu simbol = satu makna. Bulatan dilukis sendiri (gelang + nombor keluar); manuver lain guna
/// glif Material yang dipilih untuk lalu lintas sebelah kiri (lihat [maneuverIcon]).
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
    final icon = Icon(
      maneuverIcon(kind),
      size: size,
      color: color,
      semanticLabel: semanticsLabel,
    );
    // Material hanya ada satu glif gabung; cermin untuk "bergabung ke kiri".
    if (kind == ManeuverKind.mergeLeft) {
      return Transform.flip(flipX: true, child: icon);
    }
    return icon;
  }
}
