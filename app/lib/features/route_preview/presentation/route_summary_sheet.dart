import 'package:flutter/material.dart';

import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/route_option.dart';
import '../domain/routing_failure.dart';
import 'route_format.dart';
import 'route_preview_controller.dart';

/// Lembaran ringkasan laluan di bahagian bawah peta. Widget ini tulen (tiada Riverpod) supaya
/// mudah diuji golden dalam setiap tema; [RoutePreviewSheet] di map_screen menyambungkannya.
class RouteSummarySheet extends StatelessWidget {
  const RouteSummarySheet({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onVehicleChanged,
    required this.onRetry,
    required this.onClear,
    this.onOpenOfflineMaps,
    this.onStart,
    this.onSimulate,
    this.onSave,
    this.now,
  });

  final RoutePreviewState state;
  final ValueChanged<int> onSelect;
  final ValueChanged<RouteVehicle> onVehicleChanged;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  /// Dipaparkan sebagai tindakan bila kegagalan boleh diatasi dengan peta offline.
  final VoidCallback? onOpenOfflineMaps;

  /// Tindakan utama pada laluan siap: mula navigasi dan simulasi. Kedua-duanya tersembunyi jika null.
  final VoidCallback? onStart;
  final VoidCallback? onSimulate;

  /// Simpan destinasi (Rumah/Kerja/Kegemaran); butang bintang tersembunyi jika null.
  final VoidCallback? onSave;

  /// Masa semasa untuk mengira waktu tiba; lalai `DateTime.now()`. Ujian golden menetapkannya.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: l10n.routeSheetSemantics,
      child: Material(
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
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            // Skrin pendek (telefon mendatar): kandungan digulung, bukan melimpah. Pada skrin tinggi
            // kandungan muat dan tiada apa yang berubah.
            child: SingleChildScrollView(
              child: _AnimatedHeight(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  // Lalai AnimatedSwitcher memusatkan kandungan; lembaran mesti rata kiri-atas.
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
                  ),
                  child: switch (state) {
                    RouteIdle() => const SizedBox.shrink(key: ValueKey('idle')),
                    RouteLoading() => _LoadingBody(
                      key: const ValueKey('loading'),
                      destinationLabel:
                          (state as RouteLoading).destinationLabel,
                      onClear: onClear,
                    ),
                    RouteReady() => _ReadyBody(
                      key: const ValueKey('ready'),
                      state: state as RouteReady,
                      onSelect: onSelect,
                      onVehicleChanged: onVehicleChanged,
                      onClear: onClear,
                      onStart: onStart,
                      onSimulate: onSimulate,
                      onSave: onSave,
                      now: now ?? DateTime.now(),
                    ),
                    RouteFailed() => _FailedBody(
                      key: const ValueKey('failed'),
                      state: state as RouteFailed,
                      onRetry: onRetry,
                      onClear: onClear,
                      onOpenOfflineMaps: onOpenOfflineMaps,
                    ),
                    RouteLocationUnavailable() => _LocationUnavailableBody(
                      key: const ValueKey('location-unavailable'),
                      onRetry: onRetry,
                      onClear: onClear,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({super.key, required this.onClear, this.destinationLabel});

  final VoidCallback onClear;
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = destinationLabel;
    return Semantics(
      liveRegion: true,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label == null
                        ? l10n.routeCalculating
                        : l10n.routeFindingTo(label),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                // Pengguna mesti boleh membatalkan semasa menunggu GPS atau pelayan.
                IconButton(
                  key: const ValueKey('route-cancel'),
                  tooltip: l10n.routeClear,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const SkeletonBox(width: 150, height: 36),
            const SizedBox(height: 12),
            const SkeletonBox(width: 210, height: 16, radius: 8),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onVehicleChanged,
    required this.onClear,
    required this.now,
    this.onStart,
    this.onSimulate,
    this.onSave,
  });

  final RouteReady state;
  final ValueChanged<int> onSelect;
  final ValueChanged<RouteVehicle> onVehicleChanged;
  final VoidCallback onClear;
  final VoidCallback? onStart;
  final VoidCallback? onSimulate;
  final VoidCallback? onSave;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = context.fg;
    final route = state.selected;
    final via = route.via;

    final destinationLabel = state.query.destinationLabel;
    final fastestS = state.options
        .map((o) => o.durationS)
        .reduce((a, b) => a < b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (destinationLabel != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Text(
              l10n.routeFromTo(l10n.myLocation, destinationLabel),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDuration(l10n, route.durationS),
                    style: FgTypography.metricLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (via != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.routeVia(via),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatDistance(l10n, route.distanceM),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (route.source == RouteSource.offline)
                        _SourceBadge(label: l10n.routeSourceOffline),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.toll_rounded,
                            size: 18,
                            // Ikon sahaja berwarna amaran; teks kekal neutral kerana warna amaran
                            // tidak lulus kontras AA sebagai teks di atas permukaan cerah.
                            color: route.hasTolls
                                ? fg.warning
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            route.hasTolls
                                ? l10n.routeHasTolls
                                : l10n.routeNoTolls,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onSave != null)
              IconButton(
                key: const ValueKey('save-destination'),
                tooltip: l10n.savedSaveTooltip,
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
            IconButton(
              tooltip: l10n.routeClear,
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (state.options.length > 1) ...[
          _RouteOptionCards(
            options: state.options,
            fastestS: fastestS,
            selectedIndex: state.selectedIndex,
            onSelect: onSelect,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            SegmentedButton<RouteVehicle>(
              key: const ValueKey('route-vehicle'),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                // Tona utama app, bukan warna sekunder lalai Material.
                selectedBackgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.14,
                ),
                selectedForegroundColor: theme.colorScheme.primary,
              ),
              segments: [
                ButtonSegment(
                  value: RouteVehicle.car,
                  icon: const Icon(Icons.directions_car_rounded),
                  tooltip: l10n.routeVehicleCar,
                ),
                ButtonSegment(
                  value: RouteVehicle.motorcycle,
                  icon: const Icon(Icons.two_wheeler_rounded),
                  tooltip: l10n.routeVehicleMotorcycle,
                ),
              ],
              selected: {state.query.vehicle},
              onSelectionChanged: (v) => onVehicleChanged(v.single),
            ),
            const Spacer(),
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  l10n.navEta(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(
                        now.add(Duration(seconds: route.durationS)),
                      ),
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (onStart != null || onSimulate != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                if (onSimulate != null)
                  TextButton.icon(
                    key: const ValueKey('nav-simulate'),
                    onPressed: onSimulate,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(l10n.navSimulate),
                  ),
                if (onSimulate != null && onStart != null)
                  const SizedBox(width: 8),
                if (onStart != null)
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('nav-start'),
                      onPressed: onStart,
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(l10n.navStart),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        textStyle: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Senarai kad pilihan. Jika semua muat pada lebar yang ada, ia berkongsi lebar sama rata (tiada kad
/// terpotong di tepi); jika tidak (cth. 4 pilihan atau teks sistem besar) ia boleh digulung ke sisi.
class _RouteOptionCards extends StatelessWidget {
  const _RouteOptionCards({
    required this.options,
    required this.fastestS,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<RouteOption> options;
  final int fastestS;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _gap = 8.0;
  static const _minCardWidth = 106.0;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            options.length * _minCardWidth * textScale.clamp(1.0, 1.5) +
            (options.length - 1) * _gap;
        final fits = needed <= constraints.maxWidth;

        Widget card(int i) => _RouteOptionCard(
          key: ValueKey('route-option-$i'),
          option: options[i],
          slowerByS: options[i].durationS - fastestS,
          selected: i == selectedIndex,
          onTap: () => onSelect(i),
        );

        // Tinggi mengikut kandungan (bukan nilai tetap) supaya saiz teks sistem yang besar tidak
        // memotong kad; IntrinsicHeight menyamakan tinggi semua kad.
        if (fits) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(child: card(i)),
                ],
              ],
            ),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  card(i),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String routeLabelText(AppLocalizations l10n, RouteLabel label) {
  return switch (label) {
    RouteLabel.fastest => l10n.routeFastest,
    RouteLabel.shortest => l10n.routeShortest,
    RouteLabel.noTolls => l10n.routeNoTolls,
    RouteLabel.noHighways => l10n.routeNoHighways,
    RouteLabel.alternative => l10n.routeAlternative,
  };
}

IconData _routeLabelIcon(RouteLabel label) {
  return switch (label) {
    RouteLabel.fastest => Icons.bolt_rounded,
    RouteLabel.shortest => Icons.straighten_rounded,
    RouteLabel.noTolls => Icons.money_off_rounded,
    RouteLabel.noHighways => Icons.alt_route_rounded,
    RouteLabel.alternative => Icons.alt_route_rounded,
  };
}

/// Kad pilihan laluan: label (terpantas, tanpa tol, ...), masa, beza masa dengan yang terpantas dan
/// jarak. Dipilih = sempadan dan tona utama.
class _RouteOptionCard extends StatelessWidget {
  const _RouteOptionCard({
    super.key,
    required this.option,
    required this.slowerByS,
    required this.selected,
    required this.onTap,
  });

  final RouteOption option;

  /// Beza masa berbanding laluan terpantas (0 untuk yang terpantas sendiri).
  final int slowerByS;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = context.fg;
    final primary = theme.colorScheme.primary;
    final label = routeLabelText(l10n, option.label);
    final duration = formatDuration(l10n, option.durationS);
    final distance = formatDistance(l10n, option.distanceM);
    // Beza di bawah semenit tidak bermakna kepada pemandu.
    final slower = slowerByS >= 60
        ? '+${formatDuration(l10n, slowerByS)}'
        : null;
    final tollText = option.hasTolls ? l10n.routeHasTolls : l10n.routeNoTolls;

    return Semantics(
      button: true,
      selected: selected,
      label: [label, duration, ?slower, distance, tollText].join(', '),
      excludeSemantics: true,
      child: Material(
        color: selected
            ? primary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? primary : theme.colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 106, maxWidth: 190),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _routeLabelIcon(option.label),
                        size: 15,
                        color: selected
                            ? primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected
                                ? primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Wrap: masa + beza masa tidak muat satu baris pada teks sistem besar atau tempoh panjang.
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        duration,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (slower != null)
                        Text(slower, style: theme.textTheme.labelSmall),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(distance, style: theme.textTheme.bodySmall),
                      if (option.hasTolls) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.toll_rounded, size: 14, color: fg.warning),
                      ],
                    ],
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

class _LocationUnavailableBody extends StatelessWidget {
  const _LocationUnavailableBody({
    super.key,
    required this.onRetry,
    required this.onClear,
  });

  final VoidCallback onRetry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.routeLocationUnavailable,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(onPressed: onClear, child: Text(l10n.routeClear)),
              FilledButton(onPressed: onRetry, child: Text(l10n.routeRetry)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onClear,
    this.onOpenOfflineMaps,
  });

  final RouteFailed state;
  final VoidCallback onRetry;
  final VoidCallback onClear;
  final VoidCallback? onOpenOfflineMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Mengulang tidak membantu jika tiada laluan atau permintaan memang tidak sah.
    final retryable =
        state.kind != RoutingFailureKind.noRoute &&
        state.kind != RoutingFailureKind.invalidRequest;
    final offerOfflineMaps =
        state.kind == RoutingFailureKind.offlineRequired &&
        onOpenOfflineMaps != null;

    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    failureMessage(l10n, state.kind),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Wrap (bukan Row): teks BM yang lebih panjang atau saiz teks sistem yang besar boleh
          // membuat dua butang tidak muat dalam satu baris pada telefon kecil.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(onPressed: onClear, child: Text(l10n.routeClear)),
              if (offerOfflineMaps)
                OutlinedButton(
                  onPressed: onOpenOfflineMaps,
                  child: Text(l10n.offlineMapsOpen),
                ),
              if (retryable)
                FilledButton(onPressed: onRetry, child: Text(l10n.routeRetry)),
            ],
          ),
        ],
      ),
    );
  }
}

String failureMessage(AppLocalizations l10n, RoutingFailureKind kind) {
  return switch (kind) {
    RoutingFailureKind.noRoute => l10n.routeErrorNoRoute,
    RoutingFailureKind.unavailable => l10n.routeErrorUnavailable,
    RoutingFailureKind.timeout => l10n.routeErrorTimeout,
    RoutingFailureKind.network => l10n.routeErrorNetwork,
    RoutingFailureKind.rateLimited => l10n.routeErrorRateLimited,
    RoutingFailureKind.offlineRequired => l10n.routeErrorOfflineRequired,
    RoutingFailureKind.offlineEngine => l10n.routeErrorOfflineEngine,
    RoutingFailureKind.invalidRequest ||
    RoutingFailureKind.generic => l10n.routeErrorGeneric,
  };
}

/// Menganimasikan perubahan tinggi kandungan lembaran. Apabila Reduce Motion aktif (tempoh sifar),
/// `AnimatedSize` dielakkan sepenuhnya: dengan tempoh sifar ia mengubah dirinya semasa layout dan
/// melanggar pengesahan rangka kerja.
class _AnimatedHeight extends StatelessWidget {
  const _AnimatedHeight({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.normal);
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Lencana kecil "Offline": pengguna perlu tahu laluan dikira daripada pek peta yang dimuat turun
/// (mungkin kurang terkini) dan bukan data online semasa.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
