import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/prayer.dart';
import 'azan_controller.dart';
import 'azan_l10n.dart';

/// Sepanduk besar di atas peta apabila azan dimainkan dalam app (bukan semasa navigasi).
class AzanNowBanner extends ConsumerWidget {
  const AzanNowBanner({super.key, required this.prayer});

  final Prayer prayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        key: const ValueKey('azan-now-banner'),
        color: theme.colorScheme.primaryContainer,
        elevation: 6,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: [
              Icon(
                Icons.mosque_rounded,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.azanNowTitle(prayerName(l10n, prayer)),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.azanNowBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: const ValueKey('azan-stop'),
                onPressed: () =>
                    ref.read(azanControllerProvider.notifier).dismiss(),
                style: FilledButton.styleFrom(minimumSize: const Size(56, 48)),
                child: Text(l10n.azanStopListening),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cip kecil di bawah kad manuver semasa navigasi: "Waktu Zohor" + Berhenti. Tidak menutup peta.
class AzanNavChip extends ConsumerWidget {
  const AzanNavChip({super.key, required this.prayer});

  final Prayer prayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fg = context.fg;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Material(
          key: const ValueKey('azan-nav-chip'),
          color: fg.glassSurface,
          shape: StadiumBorder(side: BorderSide(color: fg.glassBorder)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mosque_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.azanNowTitle(prayerName(l10n, prayer)),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () =>
                      ref.read(azanControllerProvider.notifier).dismiss(),
                  child: Text(l10n.azanStopListening),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
