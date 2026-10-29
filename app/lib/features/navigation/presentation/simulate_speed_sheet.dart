import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/navigation_settings.dart';

/// Pilih kelajuan jelajah simulasi. Pulang km/j (0 = auto) atau null jika dibatalkan.
Future<int?> showSimulateSpeedSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(navigationSettingsProvider).simSpeedKmh;
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => _SimulateSpeedSheet(initialKmh: current),
  );
}

class _SimulateSpeedSheet extends ConsumerStatefulWidget {
  const _SimulateSpeedSheet({required this.initialKmh});

  final int initialKmh;

  @override
  ConsumerState<_SimulateSpeedSheet> createState() =>
      _SimulateSpeedSheetState();
}

class _SimulateSpeedSheetState extends ConsumerState<_SimulateSpeedSheet> {
  late int _selected = widget.initialKmh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.navSimSpeedTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.navSimSpeedHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kmh in NavigationSettings.simSpeedChoices)
                  ChoiceChip(
                    key: ValueKey('sim-speed-$kmh'),
                    label: Text(
                      kmh == 0 ? l10n.navSimSpeedAuto : l10n.navSimSpeedKmh(kmh),
                    ),
                    selected: _selected == kmh,
                    onSelected: (_) => setState(() => _selected = kmh),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('sim-speed-start'),
              onPressed: () async {
                await ref
                    .read(navigationSettingsProvider.notifier)
                    .setSimSpeedKmh(_selected);
                if (context.mounted) Navigator.pop(context, _selected);
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.navSimulate),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.settingsConfirmCancel),
            ),
          ],
        ),
      ),
    );
  }
}
