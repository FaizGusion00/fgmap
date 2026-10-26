import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/domain/route_option.dart';
import '../../route_preview/presentation/route_format.dart';
import '../../route_preview/presentation/route_summary_sheet.dart'
    show routeLabelText;
import 'nav_alternatives.dart';
import 'navigation_controller.dart';

/// Lembaran "Tukar laluan" semasa dalam perjalanan. Mengembalikan true jika laluan ditukar.
Future<bool?> showNavRoutesSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const NavRoutesSheet(),
  );
}

class NavRoutesSheet extends ConsumerWidget {
  const NavRoutesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final alt = ref.watch(navAlternativesProvider);
    final remainingS = ref.watch(
      navigationControllerProvider.select((n) => n.progress?.remainingS),
    );

    final Widget body = switch (alt.status) {
      NavAlternativesStatus.idle || NavAlternativesStatus.loading => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(l10n.navRoutesLoading)),
          ],
        ),
      ),
      NavAlternativesStatus.failed => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 14),
            Expanded(child: Text(l10n.navRoutesError)),
            TextButton(
              onPressed: () =>
                  ref.read(navAlternativesProvider.notifier).load(),
              child: Text(l10n.routeRetry),
            ),
          ],
        ),
      ),
      NavAlternativesStatus.ready => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < alt.options.length; i++)
            _RouteTile(
              key: ValueKey('nav-route-$i'),
              option: alt.options[i],
              isCurrent: i == alt.currentIndex,
              deltaS: remainingS == null
                  ? null
                  : alt.options[i].durationS - remainingS.round(),
              onTap: () {
                if (i == alt.currentIndex) {
                  Navigator.of(context).pop(false);
                  return;
                }
                final ok = ref
                    .read(navigationControllerProvider.notifier)
                    .switchRoute(alt.options[i]);
                Navigator.of(context).pop(ok);
              },
            ),
          if (alt.options.length == 1 && alt.currentIndex == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.navRoutesNone,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.navRoutesTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    super.key,
    required this.option,
    required this.isCurrent,
    required this.deltaS,
    required this.onTap,
  });

  final RouteOption option;
  final bool isCurrent;

  /// Beza masa dengan baki laluan semasa (negatif = lebih cepat); null jika tidak diketahui.
  final int? deltaS;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final title = isCurrent
        ? l10n.navRoutesCurrent
        : routeLabelText(l10n, option.label);
    final via = option.via;
    final delta = deltaS;
    final String? deltaText = isCurrent || delta == null
        ? null
        : delta.abs() < 60
        ? l10n.navRoutesSame
        : delta < 0
        ? l10n.navRoutesFaster(formatDuration(l10n, -delta))
        : l10n.navRoutesSlower(formatDuration(l10n, delta));
    final subtitle = [
      formatDistance(l10n, option.distanceM),
      ?(via == null ? null : l10n.routeVia(via)),
      option.hasTolls ? l10n.routeHasTolls : l10n.routeNoTolls,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCurrent
            ? primary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isCurrent ? primary : theme.colorScheme.outline,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isCurrent
                                ? primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDuration(l10n, option.durationS),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (deltaText != null)
                        Text(
                          deltaText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: delta! < -59
                                ? primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
