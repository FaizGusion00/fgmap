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
    required this.onAvoidTollsChanged,
    required this.onRetry,
    required this.onClear,
    this.onOpenOfflineMaps,
  });

  final RoutePreviewState state;
  final ValueChanged<int> onSelect;
  final ValueChanged<bool> onAvoidTollsChanged;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  /// Dipaparkan sebagai tindakan bila kegagalan boleh diatasi dengan peta offline.
  final VoidCallback? onOpenOfflineMaps;

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
                  RouteLoading() => const _LoadingBody(
                    key: ValueKey('loading'),
                  ),
                  RouteReady() => _ReadyBody(
                    key: const ValueKey('ready'),
                    state: state as RouteReady,
                    onSelect: onSelect,
                    onAvoidTollsChanged: onAvoidTollsChanged,
                    onClear: onClear,
                  ),
                  RouteFailed() => _FailedBody(
                    key: const ValueKey('failed'),
                    state: state as RouteFailed,
                    onRetry: onRetry,
                    onClear: onClear,
                    onOpenOfflineMaps: onOpenOfflineMaps,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 150, height: 36),
            const SizedBox(height: 12),
            const SkeletonBox(width: 210, height: 16, radius: 8),
            const SizedBox(height: 16),
            Text(
              l10n.routeCalculating,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
    required this.onAvoidTollsChanged,
    required this.onClear,
  });

  final RouteReady state;
  final ValueChanged<int> onSelect;
  final ValueChanged<bool> onAvoidTollsChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = context.fg;
    final route = state.selected;

    final destinationLabel = state.query.destinationLabel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (destinationLabel != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Text(
              l10n.routeFromTo(state.query.originLabel ?? l10n.myLocation, destinationLabel),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            IconButton(
              tooltip: l10n.routeClear,
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (state.options.length > 1)
              for (var i = 0; i < state.options.length; i++)
                ChoiceChip(
                  label: Text(
                    '${l10n.routeOptionLabel(i + 1)} · ${formatDuration(l10n, state.options[i].durationS)}',
                  ),
                  selected: i == state.selectedIndex,
                  onSelected: (_) => onSelect(i),
                ),
            FilterChip(
              label: Text(l10n.routeAvoidTolls),
              selected: state.query.avoidTolls,
              onSelected: onAvoidTollsChanged,
            ),
          ],
        ),
        if (state.query.originIsMapCenter) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.routeFromMapCenter,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
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
