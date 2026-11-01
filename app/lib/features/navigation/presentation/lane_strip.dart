import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/domain/route_option.dart';
import '../domain/lane_guidance.dart';
import '../domain/lane_plan.dart';
import '../domain/nav_route.dart';

/// Panduan lorong di bawah arahan pada kad manuver.
///
/// Dua lapisan: jika Valhalla memberi data lorong sebenar (`turn:lanes`), setiap lorong dilukis
/// sebagai anak panah dan lorong yang betul diserlahkan; jika tidak (kebiasaan di Malaysia), satu
/// baris ringkas "Guna lorong kanan" diterbitkan daripada jenis manuver. Dipaparkan dalam 700 m
/// supaya pemandu sempat bertukar lorong.
class LaneGuidance extends StatelessWidget {
  const LaneGuidance({
    super.key,
    required this.maneuver,
    required this.distanceM,
    required this.color,
    this.compact = false,
    this.showStrip = true,
  });

  final NavManeuver maneuver;
  final double distanceM;
  final Color color;
  final bool compact;

  /// Palsu apabila kotak lorong besar sudah dipaparkan: hanya ayat ("Guna lorong paling kanan")
  /// dikekalkan supaya lorong tidak dilukis dua kali.
  final bool showStrip;

  /// Benar jika ada sesuatu untuk ditunjukkan bagi [maneuver] pada [distanceM].
  static bool shows(NavManeuver maneuver, double distanceM) {
    if (maneuver.isArrival || distanceM > laneHintWithinM) return false;
    return maneuver.lanes.isNotEmpty || laneSideFor(maneuver) != null;
  }

  @override
  Widget build(BuildContext context) {
    if (!shows(maneuver, distanceM)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = lanePlanFor(maneuver);
    if (maneuver.lanes.isNotEmpty && plan != null && showStrip) {
      return _LaneStrip(lanes: maneuver.lanes, color: color, compact: compact);
    }
    final hint = plan?.hint;
    final side = laneSideFor(maneuver);
    final String? text;
    if (hint != null) {
      text = laneHintText(l10n, hint);
    } else if (maneuver.lanes.isEmpty && side != null) {
      text = side == LaneSide.left
          ? l10n.navLaneLeftmost
          : l10n.navLaneRightmost;
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('lane-hint'),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            (side ?? LaneSide.right) == LaneSide.left
                ? Icons.subdirectory_arrow_left_rounded
                : Icons.subdirectory_arrow_right_rounded,
            size: compact ? 16 : 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ayat petunjuk lorong ("Guna lorong paling kanan") daripada [hint].
String laneHintText(AppLocalizations l10n, LaneHint hint) =>
    switch (hint.kind) {
      LaneHintKind.rightmost =>
        hint.count == 1
            ? l10n.navLaneRightmost
            : l10n.navLaneRightmostN(hint.count),
      LaneHintKind.leftmost =>
        hint.count == 1
            ? l10n.navLaneLeftmost
            : l10n.navLaneLeftmostN(hint.count),
      LaneHintKind.nthFromLeft => l10n.navLaneNthFromLeft(hint.count),
      LaneHintKind.nthFromRight => l10n.navLaneNthFromRight(hint.count),
    };

class _LaneStrip extends StatelessWidget {
  const _LaneStrip({
    required this.lanes,
    required this.color,
    required this.compact,
  });

  final List<Lane> lanes;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = compact ? 22.0 : 28.0;
    final anyActive = lanes.any((l) => l.isActive || l.isValid);
    final label = [
      for (final l in lanes)
        '${laneArrows(l.shownDirections).map((a) => a.name).join('/')}'
            '${l.isActive || l.isValid ? ' ✓' : ''}',
    ].join(', ');
    return Semantics(
      label: l10n.navLaneStripSemantics(label),
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('lane-strip'),
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lanes.length; i++) ...[
              if (i > 0) SizedBox(width: compact ? 4 : 6),
              _LaneCell(
                lane: lanes[i],
                size: size,
                color: color,
                dimOthers: anyActive,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LaneCell extends StatelessWidget {
  const _LaneCell({
    required this.lane,
    required this.size,
    required this.color,
    required this.dimOthers,
  });

  final Lane lane;
  final double size;
  final Color color;
  final bool dimOthers;

  @override
  Widget build(BuildContext context) {
    final highlight = lane.isActive || lane.isValid;
    final fg = highlight || !dimOthers ? color : color.withValues(alpha: 0.35);
    final arrows = laneArrows(lane.shownDirections);
    return Container(
      key: ValueKey('lane-cell-${highlight ? 'on' : 'off'}'),
      width: size * 1.15,
      height: size * 1.15,
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.6)),
      ),
      child: Center(
        child: arrows.isEmpty
            ? Icon(Icons.remove_rounded, size: size * 0.6, color: fg)
            : arrows.length == 1
            ? Icon(_iconFor(arrows.first), size: size * 0.8, color: fg)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in arrows.take(2))
                    Icon(_iconFor(a), size: size * 0.5, color: fg),
                ],
              ),
      ),
    );
  }

  static IconData _iconFor(LaneArrow a) => switch (a) {
    LaneArrow.sharpLeft => Icons.turn_sharp_left_rounded,
    LaneArrow.left => Icons.turn_left_rounded,
    LaneArrow.slightLeft => Icons.turn_slight_left_rounded,
    LaneArrow.through => Icons.straight_rounded,
    LaneArrow.slightRight => Icons.turn_slight_right_rounded,
    LaneArrow.right => Icons.turn_right_rounded,
    LaneArrow.sharpRight => Icons.turn_sharp_right_rounded,
    LaneArrow.reverse => Icons.u_turn_right_rounded,
  };
}
