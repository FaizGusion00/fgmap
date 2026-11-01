import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../offline_maps/presentation/offline_map_controller.dart';
import '../../offline_maps/presentation/offline_maps_sheet.dart';

/// Mengapa paparkan petunjuk muat turun/kemas kini indeks carian offline.
enum OfflinePlacesPromptKind { none, download, update }

/// Indeks tempat offline hilang atau ketinggalan berbanding manifest terkini.
/// Tiada suis tetapan kosong: petunjuk membuka lembaran pek yang sama (Settings → Peta offline).
final offlinePlacesPromptProvider = Provider<OfflinePlacesPromptKind>((ref) {
  final state = ref.watch(offlineMapControllerProvider);
  if (!state.configured) return OfflinePlacesPromptKind.none;
  final installed = state.installed;
  final latest = state.latest;
  if (installed == null) return OfflinePlacesPromptKind.download;
  final hasPlaces =
      installed.placesPath != null &&
      installed.placesPath!.isNotEmpty &&
      installed.placesVersion != null;
  if (!hasPlaces) {
    // Pek laluan ada tetapi indeks carian belum — sama aliran muat turun/kemas kini.
    return latest?.places != null
        ? OfflinePlacesPromptKind.update
        : OfflinePlacesPromptKind.download;
  }
  if (latest?.places != null && installed.placesVersion != latest!.version) {
    return OfflinePlacesPromptKind.update;
  }
  return OfflinePlacesPromptKind.none;
});

/// Baris padat di atas hasil carian: muat turun/kemas kini pek supaya tempat baharu sampai.
class OfflinePlacesPromptBanner extends ConsumerWidget {
  const OfflinePlacesPromptBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(offlinePlacesPromptProvider);
    if (kind == OfflinePlacesPromptKind.none) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = kind == OfflinePlacesPromptKind.update
        ? l10n.searchOfflinePackUpdate
        : l10n.searchOfflinePackPrompt;
    return Material(
      key: const ValueKey('offline-places-prompt'),
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => showOfflineMapsSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                Icons.download_for_offline_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: theme.textTheme.bodySmall),
              ),
              TextButton(
                onPressed: () => showOfflineMapsSheet(context),
                child: Text(l10n.searchOfflinePackAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
