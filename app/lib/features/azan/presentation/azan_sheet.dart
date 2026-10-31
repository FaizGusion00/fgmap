import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/azan_settings.dart';
import '../domain/malaysia_cities.dart';
import '../domain/prayer.dart';
import 'azan_controller.dart';
import 'azan_l10n.dart';
import 'azan_settings_section.dart';

/// Lembaran waktu solat hari ini: senarai besar, waktu seterusnya ditonjolkan, suis notifikasi, dan
/// tetapan lanjut di bawah.
Future<void> showAzanSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const AzanSheet(),
);

class AzanSheet extends ConsumerWidget {
  const AzanSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final azan = ref.watch(azanControllerProvider);
    final settings = ref.watch(azanSettingsProvider);
    final today = azan.today;
    final now = ref.watch(azanClockProvider)();
    final city = cityNamed(settings.cityName);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            l10n.azanTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            city == null
                ? l10n.azanForCurrentLocation
                : l10n.azanForCity(city.name),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (today != null)
            for (final p in Prayer.values)
              _PrayerRow(
                prayer: p,
                time: today.timeOf(p),
                isNext: p == azan.next,
                passed: today.timeOf(p)?.isBefore(now) ?? false,
                easy: easy,
              ),
          const SizedBox(height: 8),
          if (azan.next != null && azan.nextAt != null)
            Text(
              l10n.azanNextPrayer(
                prayerName(l10n, azan.next!),
                formatClock(context, azan.nextAt!),
              ),
              key: const ValueKey('azan-next-line'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              l10n.azanAllDone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            l10n.azanEstimateNote(azanMethodName(l10n, settings.method)),
            key: const ValueKey('azan-estimate-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 32),
          const AzanSettingsSection(),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.isNext,
    required this.passed,
    required this.easy,
  });

  final Prayer prayer;
  final DateTime? time;
  final bool isNext;
  final bool passed;
  final bool easy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = prayer == Prayer.sunrise || (passed && !isNext);
    final color = isNext
        ? theme.colorScheme.onPrimaryContainer
        : muted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final nameStyle =
        (easy ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
            ?.copyWith(
              color: color,
              fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
            );
    final timeStyle =
        (easy ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)
            ?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
    return Semantics(
      key: ValueKey('azan-row-${prayer.name}'),
      label:
          '${prayerName(l10n, prayer)} ${time == null ? '' : formatClock(context, time!)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: isNext
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: easy ? 14 : 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(prayerName(l10n, prayer), style: nameStyle),
                ),
                Text(
                  time == null ? '--:--' : formatClock(context, time!),
                  style: timeStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
