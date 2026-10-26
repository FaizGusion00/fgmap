import 'package:flutter/material.dart';

import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/presentation/route_format.dart';
import '../domain/camera_planner.dart';
import '../domain/instruction_text.dart';
import '../domain/nav_route.dart';
import '../domain/navigation_session.dart';
import 'navigation_controller.dart';

/// Ikon Material bagi setiap jenis manuver.
IconData maneuverIcon(ManeuverKind kind) => switch (kind) {
  ManeuverKind.depart => Icons.navigation_rounded,
  ManeuverKind.straight || ManeuverKind.keepStraight => Icons.straight_rounded,
  ManeuverKind.slightRight => Icons.turn_slight_right_rounded,
  ManeuverKind.right => Icons.turn_right_rounded,
  ManeuverKind.sharpRight => Icons.turn_sharp_right_rounded,
  ManeuverKind.slightLeft => Icons.turn_slight_left_rounded,
  ManeuverKind.left => Icons.turn_left_rounded,
  ManeuverKind.sharpLeft => Icons.turn_sharp_left_rounded,
  ManeuverKind.uTurn => Icons.u_turn_left_rounded,
  ManeuverKind.rampStraight => Icons.ramp_right_rounded,
  ManeuverKind.rampRight || ManeuverKind.exitRight => Icons.ramp_right_rounded,
  ManeuverKind.rampLeft || ManeuverKind.exitLeft => Icons.ramp_left_rounded,
  ManeuverKind.keepRight => Icons.fork_right_rounded,
  ManeuverKind.keepLeft => Icons.fork_left_rounded,
  ManeuverKind.merge => Icons.merge_rounded,
  ManeuverKind.mergeRight => Icons.merge_rounded,
  ManeuverKind.mergeLeft => Icons.merge_rounded,
  ManeuverKind.roundabout => Icons.roundabout_right_rounded,
  ManeuverKind.ferry => Icons.directions_boat_rounded,
  ManeuverKind.arrive ||
  ManeuverKind.arriveRight ||
  ManeuverKind.arriveLeft => Icons.flag_rounded,
  ManeuverKind.none => Icons.arrow_upward_rounded,
};

InstructionText instructionTextFor(AppLocalizations l10n) =>
    InstructionText(VoiceLanguage.fromCode(l10n.localeName));

/// Kad manuver di atas skrin: ikon besar, jarak ke manuver, tindakan dan nama jalan, serta "kemudian"
/// untuk manuver rapat berikutnya. Beranimasi (slaid + skala) bila manuver bertukar.
class ManeuverBanner extends StatelessWidget {
  const ManeuverBanner({super.key, required this.progress});

  final NavProgress progress;

  @override
  Widget build(BuildContext context) {
    final next = progress.next;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = instructionTextFor(l10n);
    final fg = context.fg;

    final child = next == null
        ? const SizedBox.shrink(key: ValueKey('none'))
        : _BannerContent(
            key: ValueKey('m${next.index}'),
            maneuver: next,
            distanceM: progress.distanceToNextM ?? 0,
            following: _thenManeuver(progress),
            text: text,
          );

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: theme.colorScheme.primary,
        elevation: 6,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: fg.glassBorder.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.normal),
          switchInCurve: Motion.enter,
          switchOutCurve: Motion.exit,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(animation),
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, -0.25),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: child,
        ),
      ),
    );
  }

  /// "Kemudian" hanya jika manuver berikutnya rapat (< 400 m selepas yang seterusnya).
  static NavManeuver? _thenManeuver(NavProgress p) {
    final next = p.next;
    final following = p.following;
    if (next == null || following == null) return null;
    return following.startM - next.startM < 400 && !following.isArrival
        ? following
        : null;
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({
    super.key,
    required this.maneuver,
    required this.distanceM,
    required this.following,
    required this.text,
  });

  final NavManeuver maneuver;
  final double distanceM;
  final NavManeuver? following;
  final InstructionText text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final street = maneuver.isArrival ? null : maneuver.street;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(maneuverIcon(maneuver.kind), size: 56, color: onPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDistance(l10n, distanceM.round()),
                      style: FgTypography.metricLarge.copyWith(
                        color: onPrimary,
                      ),
                    ),
                    Text(
                      text.action(maneuver),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onPrimary,
                      ),
                    ),
                    if (street != null)
                      Text(
                        street,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (following != null) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: onPrimary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.navThen,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      maneuverIcon(following!.kind),
                      size: 22,
                      color: onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bar maklumat perjalanan di bawah: masa baki, jarak baki, masa tiba, serta tindakan.
class NavBottomPanel extends StatelessWidget {
  const NavBottomPanel({
    super.key,
    required this.progress,
    required this.now,
    required this.onEnd,
    this.simulated = false,
  });

  final NavProgress progress;
  final DateTime now;
  final bool simulated;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eta = now.add(Duration(seconds: progress.remainingS.round()));
    final etaText = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(eta));

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              formatDuration(l10n, progress.remainingS.round()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FgTypography.metricMedium.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (simulated) ...[
                            const SizedBox(width: 8),
                            _Badge(label: l10n.navSimulatedBadge),
                          ],
                        ],
                      ),
                      Text(
                        '${formatDistance(l10n, progress.remainingM.round())} · ${l10n.navEta(etaText)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: l10n.navEnd,
                onPressed: onEnd,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  minimumSize: const Size(52, 52),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Butang sampingan di atas peta: lihat keseluruhan laluan, mod kamera, suara, tetapan.
class NavSideButtons extends StatelessWidget {
  const NavSideButtons({
    super.key,
    required this.voiceEnabled,
    required this.cameraMode,
    required this.onToggleVoice,
    required this.onCycleCamera,
    required this.onOverview,
    required this.onSettings,
  });

  final bool voiceEnabled;
  final NavCameraMode cameraMode;
  final VoidCallback onToggleVoice;
  final VoidCallback onCycleCamera;
  final VoidCallback onOverview;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlassButton(
          icon: Icons.route_rounded,
          tooltip: l10n.navOverview,
          onPressed: onOverview,
        ),
        const SizedBox(height: 8),
        _GlassButton(
          icon: switch (cameraMode) {
            NavCameraMode.auto => Icons.auto_mode_rounded,
            NavCameraMode.flat => Icons.map_outlined,
            NavCameraMode.tilted => Icons.threed_rotation_rounded,
          },
          tooltip: switch (cameraMode) {
            NavCameraMode.auto => l10n.navCameraAuto,
            NavCameraMode.flat => l10n.navCameraFlat,
            NavCameraMode.tilted => l10n.navCameraTilted,
          },
          onPressed: onCycleCamera,
        ),
        const SizedBox(height: 8),
        _GlassButton(
          icon: voiceEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          tooltip: voiceEnabled ? l10n.navMute : l10n.navUnmute,
          onPressed: onToggleVoice,
        ),
        const SizedBox(height: 8),
        _GlassButton(
          icon: Icons.tune_rounded,
          tooltip: l10n.navSettingsOpen,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = context.fg;
    return Material(
      color: fg.glassSurface,
      elevation: 3,
      shape: CircleBorder(side: BorderSide(color: fg.glassBorder)),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: Theme.of(context).colorScheme.onSurface,
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(label, style: theme.textTheme.labelSmall),
      ),
    );
  }
}

/// Bulatan kelajuan semasa (km/j).
class SpeedBubble extends StatelessWidget {
  const SpeedBubble({super.key, required this.speedMps});

  final double speedMps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = context.fg;
    final kmh = (speedMps * 3.6).round();
    return Semantics(
      label: '${l10n.navSpeedLabel}: $kmh ${l10n.navSpeedUnit}',
      excludeSemantics: true,
      child: Material(
        color: fg.glassSurface,
        elevation: 3,
        shape: CircleBorder(side: BorderSide(color: fg.glassBorder)),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$kmh',
                style: FgTypography.metricMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1,
                ),
              ),
              Text(l10n.navSpeedUnit, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jalur status ringkas di bawah kad manuver: mengira semula laluan, GPS lemah, dsb.
class NavStatusChip extends StatelessWidget {
  const NavStatusChip({super.key, required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fg = context.fg;

    String? message;
    IconData icon = Icons.info_outline_rounded;
    Color? tint;
    if (state.progress == null && !state.locationError) {
      message = l10n.navAcquiring;
      icon = Icons.gps_not_fixed_rounded;
    } else if (state.locationError) {
      message = l10n.navLocationLost;
      icon = Icons.location_off_rounded;
      tint = Theme.of(context).colorScheme.error;
    } else if (state.rerouting) {
      message = l10n.navRerouting;
      icon = Icons.alt_route_rounded;
    } else if (state.rerouteFailure != null &&
        state.progress?.status == NavStatus.offRoute) {
      message = l10n.navRerouteRetry;
      icon = Icons.wifi_off_rounded;
      tint = fg.warning;
    } else if (state.progress?.gpsWeak ?? false) {
      message = l10n.navGpsWeak;
      icon = Icons.gps_not_fixed_rounded;
      tint = fg.warning;
    }

    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.normal),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('no-status'))
          : Padding(
              key: ValueKey(message),
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  // Tanpa bayang: SizeTransition memotong bayang di tepi dan kelihatan tersilap.
                  color: fg.glassSurface,
                  elevation: 0,
                  shape: StadiumBorder(side: BorderSide(color: fg.glassBorder)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.rerouting || state.progress == null)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(icon, size: 18, color: tint),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Kad ketibaan: dipaparkan di tengah bawah apabila destinasi dicapai.
class ArrivalCard extends StatelessWidget {
  const ArrivalCard({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 8,
        shadowColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 44,
                  color: context.fg.destination,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.navArrived,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.navArrivalSub,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.navDone),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Butang untuk kembali mengikut kenderaan selepas pengguna menggerakkan peta.
class RecenterButton extends StatelessWidget {
  const RecenterButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return FloatingActionButton(
      heroTag: null,
      tooltip: l10n.navRecenter,
      onPressed: onPressed,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      child: const Icon(Icons.navigation_rounded),
    );
  }
}

/// Butang "Mula" dan "Simulasi" yang dipaparkan di atas lembaran ringkasan laluan.
class NavStartBar extends StatelessWidget {
  const NavStartBar({
    super.key,
    required this.onStart,
    required this.onSimulate,
  });

  final VoidCallback onStart;
  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('nav-simulate'),
          onPressed: onSimulate,
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: Text(l10n.navSimulate),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const ValueKey('nav-start'),
          onPressed: onStart,
          icon: const Icon(Icons.navigation_rounded),
          label: Text(l10n.navStart),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
