import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/external_actions.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/map_links.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Lembaran kecemasan: dail 999 / 112 (dengan pengesahan) dan kongsi lokasi tepat.
///
/// [locate] memulangkan kedudukan semasa (kedudukan penjejak jika ada, jika tidak GPS). App tidak pernah
/// membuat panggilan sendiri: papan nombor dibuka dan pengguna menekan butang panggil.
Future<void> showEmergencySheet(
  BuildContext context, {
  required Future<GeoPoint?> Function() locate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EmergencySheet(locate: locate),
  );
}

class EmergencySheet extends ConsumerWidget {
  const EmergencySheet({super.key, required this.locate});

  final Future<GeoPoint?> Function() locate;

  Future<void> _confirmAndDial(
    BuildContext context,
    WidgetRef ref,
    String number,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final dialer = ref.read(phoneDialerProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.emergency_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(l10n.emergencyConfirmTitle(number)),
        content: Text(l10n.emergencyConfirmBody),
        actions: [
          TextButton(
            key: const ValueKey('emergency-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.autoStartCancel),
          ),
          FilledButton(
            key: const ValueKey('emergency-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.emergencyConfirmCall),
          ),
        ],
      ),
    );
    if (ok != true) return;
    unawaited(Haptics.heavy());
    final opened = await dialer.dial(number);
    if (!opened) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.emergencyDialFailed(number))),
      );
    }
  }

  Future<void> _shareLocation(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final share = ref.read(shareServiceProvider);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    messenger?.showSnackBar(SnackBar(content: Text(l10n.savedLocating)));
    final point = await locate();
    messenger?.hideCurrentSnackBar();
    if (point == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.emergencyNoLocation)),
      );
      return;
    }
    try {
      await share.shareText(
        l10n.emergencyShareText(
          coordinateText(point),
          osmPointLink(point, zoom: 18),
        ),
        origin: origin,
      );
    } on Object {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_rounded, color: error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.emergencyTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emergencyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _CallTile(
            tileKey: const ValueKey('emergency-999'),
            number: '999',
            title: l10n.emergencyCall999,
            subtitle: l10n.emergencyCall999Hint,
            onTap: () => _confirmAndDial(context, ref, '999'),
          ),
          const SizedBox(height: 8),
          _CallTile(
            tileKey: const ValueKey('emergency-112'),
            number: '112',
            title: l10n.emergencyCall112,
            subtitle: l10n.emergencyCall112Hint,
            onTap: () => _confirmAndDial(context, ref, '112'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('emergency-share'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => unawaited(_shareLocation(context, ref)),
            // Label boleh dibungkus pada teks sistem besar (OutlinedButton.icon memaksa satu baris).
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share_location_rounded),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l10n.emergencyShareLocation,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({
    required this.tileKey,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key tileKey;
  final String number;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: tileKey,
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.call_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
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
