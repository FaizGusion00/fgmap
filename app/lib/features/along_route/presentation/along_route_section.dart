import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/presentation/route_format.dart';
import '../domain/along_route_category.dart';
import '../domain/along_route_poi.dart';
import 'along_route_controller.dart';

/// Bahagian "Sepanjang laluan" pada lembaran pratonton laluan.
class AlongRouteSection extends ConsumerWidget {
  const AlongRouteSection({super.key, this.onSelectPoi, this.alongNow = 0});

  final ValueChanged<AlongRoutePoi>? onSelectPoi;
  final double alongNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final state = ref.watch(alongRouteControllerProvider);
    final cats = easy
        ? const [AlongRouteCategory.restArea, AlongRouteCategory.fuel]
        : AlongRouteCategory.values;

    return Column(
      key: const ValueKey('along-route-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text(
          l10n.alongRouteTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.alongRouteDisclaimer,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cats)
              ChoiceChip(
                key: ValueKey('along-chip-${c.name}'),
                label: Text(_label(l10n, c)),
                selected: state.category == c,
                onSelected: (_) => ref
                    .read(alongRouteControllerProvider.notifier)
                    .selectCategory(c),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.alongRouteUnavailable,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(alongRouteControllerProvider.notifier)
                      .selectCategory(state.category),
                  child: Text(l10n.routeRetry),
                ),
              ],
            ),
          )
        else if (state.pois.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.alongRouteEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...state.pois.take(easy ? 5 : 8).map((p) {
            final rem = p.remainingFrom(alongNow);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onSelectPoi == null ? null : () => onSelectPoi!(p),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: easy ? 10 : 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _icon(p.category),
                        size: easy ? 28 : 24,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: easy ? 17 : null,
                              ),
                            ),
                            Text(
                              l10n.alongRouteIn(
                                formatDistance(l10n, rem.round()),
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onSelectPoi != null)
                        Tooltip(
                          message: l10n.alongRouteAddStop,
                          child: Icon(
                            Icons.add_location_alt_outlined,
                            color: theme.colorScheme.primary,
                            size: easy ? 26 : 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  String _label(AppLocalizations l10n, AlongRouteCategory c) => switch (c) {
    AlongRouteCategory.restArea => l10n.alongRouteRr,
    AlongRouteCategory.fuel => l10n.alongRouteFuel,
    AlongRouteCategory.mosque => l10n.alongRouteMosque,
    AlongRouteCategory.toilets => l10n.alongRouteToilets,
  };

  IconData _icon(AlongRouteCategory c) => switch (c) {
    AlongRouteCategory.restArea => Icons.local_parking_rounded,
    AlongRouteCategory.fuel => Icons.local_gas_station_rounded,
    AlongRouteCategory.mosque => Icons.mosque_rounded,
    AlongRouteCategory.toilets => Icons.wc_rounded,
  };
}
