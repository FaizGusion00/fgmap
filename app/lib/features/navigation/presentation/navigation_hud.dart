import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/presentation/route_format.dart';
import '../domain/camera_planner.dart';
import '../domain/instruction_text.dart';
import '../domain/nav_route.dart';
import '../domain/navigation_session.dart';
import 'lane_strip.dart';
import 'maneuver_glyph.dart';
import 'navigation_controller.dart';
import '../../../core/widgets/press_scale.dart';

/// Ikon Material bagi setiap jenis manuver. Dipilih untuk lalu lintas sebelah kiri (Malaysia):
/// pusingan U membelok ke kanan. Bulatan dilukis sendiri oleh [ManeuverGlyph], jadi nilai di sini
/// hanya sandaran. Satu simbol = satu makna; tiada hiasan.
IconData maneuverIcon(ManeuverKind kind) => switch (kind) {
  ManeuverKind.depart => Icons.navigation_rounded,
  ManeuverKind.straight || ManeuverKind.keepStraight => Icons.straight_rounded,
  ManeuverKind.slightRight => Icons.turn_slight_right_rounded,
  ManeuverKind.right => Icons.turn_right_rounded,
  ManeuverKind.sharpRight => Icons.turn_sharp_right_rounded,
  ManeuverKind.slightLeft => Icons.turn_slight_left_rounded,
  ManeuverKind.left => Icons.turn_left_rounded,
  ManeuverKind.sharpLeft => Icons.turn_sharp_left_rounded,
  ManeuverKind.uTurn => Icons.u_turn_right_rounded,
  ManeuverKind.rampStraight => Icons.straight_rounded,
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

/// Saiz elemen HUD mengikut paparan. Telefon mendatar hanya ada kira-kira 390 px tinggi: kad yang
/// selesa dalam potret akan menelan separuh skrin dan menutup kereta. Semua elemen HUD membaca saiz
/// daripada sini supaya mengecil bersama dan serentak.
@immutable
class NavHudMetrics {
  const NavHudMetrics._({
    required this.landscape,
    required this.bannerIcon,
    required this.thenIcon,
    required this.distanceSize,
    required this.padH,
    required this.padV,
    required this.radius,
    required this.button,
    required this.speedSize,
    required this.limitSize,
    required this.bannerMaxWidth,
  });

  factory NavHudMetrics.of(BuildContext context) => NavHudMetrics.forSize(
    MediaQuery.sizeOf(context),
    easy: EasyModeScope.of(context),
  );

  /// [easy]: Mod mudah membesarkan ikon, nombor dan butang (bukan padding atau lebar kad) supaya
  /// kad kekal di bawah had ketinggian yang menjaga pandangan kereta.
  factory NavHudMetrics.forSize(Size size, {bool easy = false}) {
    final base = NavHudMetrics._forSize(size);
    return easy ? base._scaled(icon: 1.25, number: 1.15) : base;
  }

  NavHudMetrics _scaled({required double icon, required double number}) =>
      NavHudMetrics._(
        landscape: landscape,
        bannerIcon: bannerIcon * icon,
        thenIcon: thenIcon * icon,
        distanceSize: distanceSize * number,
        padH: padH,
        padV: padV,
        radius: radius,
        button: button * icon,
        speedSize: speedSize * number,
        limitSize: limitSize * number,
        bannerMaxWidth: bannerMaxWidth,
      );

  factory NavHudMetrics._forSize(Size size) {
    final landscape = size.width > size.height;
    final narrow = size.width < 360;
    if (landscape) {
      return NavHudMetrics._(
        landscape: true,
        bannerIcon: 38,
        thenIcon: 20,
        distanceSize: 26,
        padH: 10,
        padV: 8,
        radius: 16,
        button: 42,
        speedSize: 54,
        limitSize: 42,
        bannerMaxWidth: (size.width * 0.4).clamp(250.0, 330.0),
      );
    }
    return NavHudMetrics._(
      landscape: false,
      bannerIcon: narrow ? 44 : 52,
      thenIcon: 26,
      distanceSize: narrow ? 26 : 30,
      padH: narrow ? 12 : 14,
      padV: 10,
      radius: 18,
      button: 46,
      speedSize: 58,
      limitSize: 46,
      bannerMaxWidth: 440,
    );
  }

  final bool landscape;

  /// Sisi ikon manuver utama; nombor keluar bulatan dilukis pada saiz ini juga.
  final double bannerIcon;

  /// Sisi ikon pada jalur "Kemudian".
  final double thenIcon;
  final double distanceSize;
  final double padH;
  final double padV;
  final double radius;

  /// Sisi minimum butang bulat sisi.
  final double button;
  final double speedSize;
  final double limitSize;
  final double bannerMaxWidth;
}

/// Warna kad manuver. Pada peta gelap kad biru cerah dengan teks gelap terlalu terang dan menyilaukan;
/// kad biru tua dengan teks putih (kontras >= 7:1) dan garis tepi biru lebih jelas dan lebih tenang.
@immutable
class BannerColors {
  const BannerColors({
    required this.background,
    required this.foreground,
    required this.border,
    this.borderWidth = 1,
  });

  /// [highContrast] (Mod mudah): biru tua pekat + putih pada tema cerah, hitam + kuning pada tema
  /// gelap (kontras >= 12:1), dengan sempadan putih 2 px supaya kad terpisah jelas daripada peta.
  factory BannerColors.of(
    ThemeData theme,
    Color glassBorder, {
    bool highContrast = false,
  }) {
    if (highContrast) {
      final dark = theme.brightness == Brightness.dark;
      return BannerColors(
        background: dark ? Colors.black : const Color(0xFF0B2A6F),
        foreground: dark ? const Color(0xFFFFE57F) : Colors.white,
        border: Colors.white.withValues(alpha: 0.9),
        borderWidth: 2,
      );
    }
    if (theme.brightness == Brightness.dark) {
      return BannerColors(
        background: const Color(0xFF14284F),
        foreground: Colors.white,
        border: theme.colorScheme.primary.withValues(alpha: 0.6),
      );
    }
    return BannerColors(
      background: theme.colorScheme.primary,
      foreground: theme.colorScheme.onPrimary,
      // Sempadan lebih jelas di bawah silau (bukan alpha 0.4 yang hilang di luar rumah).
      border: glassBorder.withValues(alpha: 0.75),
    );
  }

  final Color background;
  final Color foreground;
  final Color border;
  final double borderWidth;
}

/// Mengekang penskalaan teks sistem pada HUD: teks yang membesar tanpa had menolak kad manuver sehingga
/// menutup jalan. Sedikit pembesaran (115%; 130% dalam Mod mudah) masih dihormati.
Widget _clampTextScale(BuildContext context, Widget child) =>
    MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: EasyModeScope.of(context) ? 1.3 : 1.15,
      child: child,
    );

/// Kad manuver di atas skrin: ikon, jarak ke manuver, tindakan dan nama jalan, serta "kemudian" untuk
/// manuver rapat berikutnya. Padat (potret) dan lebih kecil lagi (mendatar). Beranimasi (slaid + skala)
/// bila manuver bertukar.
class ManeuverBanner extends StatelessWidget {
  const ManeuverBanner({super.key, required this.progress, this.liveAlongM});

  final NavProgress progress;

  /// Kedudukan sepanjang laluan yang dikemas kini setiap bingkai; jika ada, jarak ke manuver
  /// dikira daripadanya (bukan daripada fix GPS 1 Hz) supaya kiraan turun lancar.
  final ValueListenable<double?>? liveAlongM;

  @override
  Widget build(BuildContext context) {
    final next = progress.next;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = instructionTextFor(l10n);
    final fg = context.fg;
    final metrics = NavHudMetrics.of(context);
    final colors = BannerColors.of(
      theme,
      fg.glassBorder,
      highContrast: EasyModeScope.of(context),
    );

    final child = next == null
        ? const SizedBox.shrink(key: ValueKey('none'))
        : ValueListenableBuilder<double?>(
            key: ValueKey('m${next.index}'),
            valueListenable: liveAlongM ?? _noLiveAlong,
            builder: (context, along, _) {
              final then = _thenManeuver(progress);
              return _BannerContent(
                maneuver: next,
                distanceM: along == null
                    ? (progress.distanceToNextM ?? 0)
                    : math.max(0.0, next.startM - along),
                following: then,
                thenGapM: then == null ? null : then.startM - next.startM,
                text: text,
                metrics: metrics,
                colors: colors,
              );
            },
          );

    // Bukan liveRegion di sini: jarak berubah setiap saat dan TalkBack akan membacanya terus,
    // bertindih dengan suara arahan. Hanya teks tindakan (berubah bila manuver bertukar) yang live.
    return _clampTextScale(
      context,
      Semantics(
        container: true,
        child: Material(
          color: colors.background,
          elevation: 4,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(metrics.radius),
            side: BorderSide(color: colors.border, width: colors.borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.normal),
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.2),
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
      ),
    );
  }

  static final ValueListenable<double?> _noLiveAlong = ValueNotifier<double?>(
    null,
  );

  /// Jarak (m) dari manuver seterusnya ke yang selepasnya; "Kemudian" ditunjuk jika <= nilai ini.
  static const thenWithinM = 800.0;

  /// "Kemudian" hanya jika manuver berikutnya cukup dekat untuk dirancang (<= 800 m selepas yang
  /// seterusnya) dan bukan ketibaan.
  static NavManeuver? _thenManeuver(NavProgress p) {
    final next = p.next;
    final following = p.following;
    if (next == null || following == null) return null;
    return following.startM - next.startM <= thenWithinM && !following.isArrival
        ? following
        : null;
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.maneuver,
    required this.distanceM,
    required this.following,
    required this.thenGapM,
    required this.text,
    required this.metrics,
    required this.colors,
  });

  final BannerColors colors;

  /// Dalam jarak ini bar "bersedia" muncul dan memenuh sehingga manuver.
  static const readyWithinM = 300.0;

  /// Dalam jarak ini perkataan "Bersedia" muncul: isyarat terakhir sebelum bertindak.
  static const getReadyWithinM = 150.0;

  final NavManeuver maneuver;
  final double distanceM;
  final NavManeuver? following;

  /// Jarak antara manuver ini dan [following]; null jika tiada "Kemudian".
  final double? thenGapM;
  final InstructionText text;
  final NavHudMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onPrimary = colors.foreground;
    final street = maneuver.isArrival ? null : maneuver.street;
    final followingStreet = following?.street;
    final ready = distanceM <= readyWithinM && !maneuver.isArrival;
    final getReady = distanceM <= getReadyWithinM && !maneuver.isArrival;

    final exitNo = maneuver.roundaboutExit;
    final glyphLabel =
        maneuver.kind == ManeuverKind.roundabout && exitNo != null && exitNo > 0
        ? l10n.navRoundaboutExitSemantics(exitNo)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.padH,
            vertical: metrics.padV,
          ),
          child: Row(
            children: [
              ManeuverGlyph(
                kind: maneuver.kind,
                roundaboutExit: exitNo,
                size: metrics.bannerIcon,
                color: onPrimary,
                semanticsLabel: glyphLabel,
              ),
              SizedBox(width: metrics.landscape ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Jarak mengecil sendiri jika rentetan panjang atau teks sistem besar, bukan
                    // melimpah keluar kad.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatDistance(l10n, distanceM.round()),
                        maxLines: 1,
                        style: FgTypography.metricLarge.copyWith(
                          color: onPrimary,
                          fontSize: metrics.distanceSize,
                          height: 1.05,
                        ),
                      ),
                    ),
                    // container: nod sendiri (tidak digabung ke kad), supaya bendera live tidak
                    // menjalar ke jarak yang berubah setiap saat.
                    Semantics(
                      container: true,
                      liveRegion: true,
                      child: Text(
                        text.cardAction(maneuver),
                        maxLines: metrics.landscape ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (street != null)
                      Text(
                        street,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onPrimary.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                      ),
                    // Panduan lorong: lorong sebenar jika ada data, jika tidak "Guna lorong kanan".
                    LaneGuidance(
                      maneuver: maneuver,
                      distanceM: distanceM,
                      color: onPrimary,
                      compact: metrics.landscape,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (getReady)
          // Satu perkataan sahaja, 150 m sebelum belok: isyarat yang boleh dibaca sekilas.
          Padding(
            padding: EdgeInsets.fromLTRB(metrics.padH, 0, metrics.padH, 4),
            child: Text(
              l10n.navGetReady,
              key: const ValueKey('nav-get-ready'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: onPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        if (ready)
          // Bar "bersedia": kosong pada 300 m, penuh di titik belok.
          LinearProgressIndicator(
            value: (1 - distanceM / readyWithinM).clamp(0.0, 1.0),
            minHeight: 5,
            color: onPrimary,
            backgroundColor: onPrimary.withValues(alpha: 0.2),
          ),
        if (following != null && thenGapM != null)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.22),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.padH,
                vertical: metrics.landscape ? 4 : 6,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.navThen,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ManeuverGlyph(
                    kind: following!.kind,
                    roundaboutExit: following!.roundaboutExit,
                    size: metrics.thenIcon,
                    color: onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDistance(l10n, thenGapM!.round()),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (followingStreet != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        followingStreet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
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
    this.floating = false,
    this.vehicleIcon,
  });

  /// Ikon jenis kenderaan (kereta/motosikal) di sebelah masa baki; null = tiada.
  final IconData? vehicleIcon;

  final NavProgress progress;
  final DateTime now;
  final bool simulated;
  final VoidCallback onEnd;

  /// Kad terapung bulat penuh (mendatar), bukan lembaran yang melekat pada tepi bawah.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eta = now.add(Duration(seconds: progress.remainingS.round()));
    final etaText = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(eta));

    final metrics = NavHudMetrics.of(context);
    return _clampTextScale(
      context,
      Material(
        color: theme.colorScheme.surface,
        elevation: floating ? 4 : 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: floating
              ? BorderRadius.circular(metrics.radius)
              : const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          bottom: !floating,
          left: !floating,
          right: !floating,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              floating ? 14 : 18,
              floating ? 8 : 10,
              floating ? 8 : 10,
              floating ? 8 : 6,
            ),
            child: Row(
              children: [
                if (vehicleIcon != null) ...[
                  ExcludeSemantics(
                    child: Icon(
                      vehicleIcon,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
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
                                formatDuration(
                                  l10n,
                                  progress.remainingS.round(),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FgTypography.metricMedium.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 20,
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
                    minimumSize: Size.square(metrics.button),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
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
    this.onReport,
    this.onChangeRoute,
    this.onMusic,
    this.compact = false,
  });

  /// Buka Muzik; tersembunyi jika null.
  final VoidCallback? onMusic;

  /// Mod mudah: hanya Laporkan, suara dan tetapan; lihat laluan, mod kamera dan tukar laluan
  /// disembunyikan (masih ada dalam tetapan navigasi).
  final bool compact;

  final bool voiceEnabled;
  final NavCameraMode cameraMode;
  final VoidCallback onToggleVoice;
  final VoidCallback onCycleCamera;
  final VoidCallback onOverview;
  final VoidCallback onSettings;

  /// Laporkan sesuatu di jalan (penumpang atau berhenti); tersembunyi jika null.
  final VoidCallback? onReport;

  /// Pilih laluan lain dari kedudukan semasa; tersembunyi jika null.
  final VoidCallback? onChangeRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onReport != null) ...[
          _GlassButton(
            icon: Icons.add_alert_rounded,
            tooltip: l10n.reportButtonTooltip,
            onPressed: onReport!,
          ),
          const SizedBox(height: 6),
        ],
        if (!compact) ...[
          _GlassButton(
            icon: Icons.route_rounded,
            tooltip: l10n.navOverview,
            onPressed: onOverview,
          ),
          const SizedBox(height: 6),
        ],
        if (onChangeRoute != null && !compact) ...[
          _GlassButton(
            icon: Icons.alt_route_rounded,
            tooltip: l10n.navChangeRoute,
            onPressed: onChangeRoute!,
          ),
          const SizedBox(height: 6),
        ],
        if (!compact) ...[
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
          const SizedBox(height: 6),
        ],
        _GlassButton(
          icon: voiceEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          tooltip: voiceEnabled ? l10n.navMute : l10n.navUnmute,
          onPressed: onToggleVoice,
        ),
        const SizedBox(height: 6),
        if (onMusic != null) ...[
          _GlassButton(
            icon: Icons.music_note_rounded,
            tooltip: l10n.musicOpen,
            onPressed: onMusic!,
          ),
          const SizedBox(height: 6),
        ],
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
    final side = NavHudMetrics.of(context).button;
    return PressScale(
      child: Material(
        color: fg.glassSurface,
        elevation: 3,
        shape: CircleBorder(side: BorderSide(color: fg.glassBorder)),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: EasyModeScope.of(context) ? 28 : 22),
          color: Theme.of(context).colorScheme.onSurface,
          constraints: BoxConstraints(minWidth: side, minHeight: side),
        ),
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

/// Kelajuan semasa (km/j) dengan tanda had laju di atasnya apabila diketahui. Melebihi had: bulatan
/// kelajuan menjadi merah (bukan hanya warna: tanda had tetap kelihatan sebagai perbandingan nombor).
class SpeedBubble extends StatelessWidget {
  const SpeedBubble({
    super.key,
    required this.speedMps,
    this.limitKmh,
    this.overspeed = false,
  });

  final double speedMps;
  final int? limitKmh;
  final bool overspeed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = context.fg;
    final metrics = NavHudMetrics.of(context);
    final kmh = (speedMps * 3.6).round();
    final limit = limitKmh;
    final background = overspeed ? theme.colorScheme.error : fg.glassSurface;
    final foreground = overspeed
        ? theme.colorScheme.onError
        : theme.colorScheme.onSurface;

    // Lingkaran bersaiz tetap: teks sistem yang besar tidak boleh melimpahkannya.
    return _clampTextScale(
      context,
      Semantics(
        label:
            '${l10n.navSpeedLabel}: $kmh ${l10n.navSpeedUnit}'
            '${limit == null ? '' : ', ${l10n.navSpeedLimit}: $limit'}',
        liveRegion: overspeed,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (limit != null) ...[
              _SpeedLimitSign(limitKmh: limit, size: metrics.limitSize),
              const SizedBox(height: 6),
            ],
            Material(
              type: MaterialType.transparency,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: metrics.speedSize,
                height: metrics.speedSize,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: overspeed ? theme.colorScheme.error : fg.glassBorder,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$kmh',
                      style: FgTypography.metricMedium.copyWith(
                        color: foreground,
                        fontSize: 20,
                        height: 1,
                      ),
                    ),
                    Text(
                      l10n.navSpeedUnit,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tanda had laju gaya Malaysia/Eropah: bulatan putih bergelang merah.
class _SpeedLimitSign extends StatelessWidget {
  const _SpeedLimitSign({required this.limitKmh, required this.size});

  final int limitKmh;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        key: const ValueKey('speed-limit-sign'),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD62828), width: 4.5),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              '$limitKmh',
              style: FgTypography.metricMedium.copyWith(
                // Sentiasa hitam di atas putih, tidak mengikut tema (tanda jalan sebenar).
                color: Colors.black,
                fontSize: limitKmh >= 100 ? 16 : 19,
                height: 1,
              ),
            ),
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
    } else if (state.progress?.signalLost ?? false) {
      message = l10n.navGpsEstimating;
      icon = Icons.gps_off_rounded;
      tint = fg.warning;
    } else if (state.progress?.gpsWeak ?? false) {
      message = l10n.navGpsWeak;
      icon = Icons.gps_not_fixed_rounded;
      tint = fg.warning;
    }
    // Mod mudah: satu baris tenang tentang apa yang perlu dibuat, bukan hanya nama masalah.
    final gpsTrouble =
        (state.progress?.signalLost ?? false) ||
        (state.progress?.gpsWeak ?? false);
    if (message != null &&
        gpsTrouble &&
        !state.rerouting &&
        !state.locationError &&
        EasyModeScope.of(context)) {
      message = '$message\n${l10n.navGpsWeakHint}';
    }

    return _clampTextScale(
      context,
      AnimatedSwitcher(
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
                    shape: StadiumBorder(
                      side: BorderSide(color: fg.glassBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
      ),
    );
  }
}

/// Kad ketibaan: dipaparkan di tengah bawah apabila destinasi dicapai.
class ArrivalCard extends StatelessWidget {
  const ArrivalCard({super.key, required this.onDone, this.floating = false});

  final VoidCallback onDone;

  /// Kad terapung bulat penuh (mendatar), bukan lembaran yang melekat pada tepi bawah.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _clampTextScale(
      context,
      Semantics(
        liveRegion: true,
        container: true,
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: floating
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            bottom: !floating,
            left: !floating,
            right: !floating,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, floating ? 12 : 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: floating ? 32 : 44,
                    color: context.fg.destination,
                  ),
                  const SizedBox(height: 6),
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
                  SizedBox(height: floating ? 10 : 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDone,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(l10n.navDone),
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

/// Butang untuk kembali mengikut kenderaan selepas pengguna menggerakkan peta.
class RecenterButton extends StatelessWidget {
  const RecenterButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final side = NavHudMetrics.of(context).button + 4;
    return IconButton.filled(
      tooltip: l10n.navRecenter,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        minimumSize: Size.square(side),
        elevation: 4,
        shadowColor: Colors.black54,
      ),
      icon: const Icon(Icons.navigation_rounded),
    );
  }
}

/// Chip 1×–4× untuk mempercepat masa simulasi semasa main.
class SimSpeedMultiplierBar extends StatelessWidget {
  const SimSpeedMultiplierBar({
    super.key,
    required this.multiplier,
    required this.onChanged,
  });

  final ValueListenable<double> multiplier;
  final ValueChanged<double> onChanged;

  static const choices = [1.0, 2.0, 3.0, 4.0];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = context.fg;
    return ValueListenableBuilder<double>(
      valueListenable: multiplier,
      builder: (context, value, _) {
        return Material(
          color: fg.glassSurface,
          elevation: 2,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: fg.glassBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in choices)
                  _MultChip(
                    label: l10n.navSimSpeedMult(m.round()),
                    selected: (value - m).abs() < 0.01,
                    onTap: () => onChanged(m),
                    theme: theme,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MultChip extends StatelessWidget {
  const _MultChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surface.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
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
