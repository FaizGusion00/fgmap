import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/data/route_planner.dart';
import '../domain/offline_models.dart';
import 'offline_map_controller.dart';

Future<void> showOfflineMapsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const OfflineMapsSheet(),
  );
}

/// Benar jika sambungan semasa berkemungkinan berkuota (data mudah alih tanpa Wi-Fi/Ethernet).
/// Disediakan sebagai provider supaya ujian boleh menggantikannya.
final isMeteredConnectionProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final results = await Connectivity().checkConnectivity();
    final unmetered =
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    return !unmetered && results.contains(ConnectivityResult.mobile);
  };
});

/// "242 MB" / "1.2 GB" (perpuluhan SI, seperti yang dipaparkan sistem pengendalian).
String formatBytes(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  }
  return '${(bytes / 1e6).round()} MB';
}

/// Versi pek (YYYYMMDD) sebagai tarikh setempat, atau teks asal jika tidak boleh dihurai.
String formatPackDate(String version, String locale) {
  final parsed = DateTime.tryParse(version);
  return parsed == null ? version : DateFormat.yMMMd(locale).format(parsed);
}

/// Pengurusan peta offline dan pilihan sumber laluan (Bahagian 17.5 dan 17.9 pelan).
class OfflineMapsSheet extends ConsumerWidget {
  const OfflineMapsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(offlineMapControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.offlineMapsTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.offlineMapsIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          _StatusCard(state: state),
          const SizedBox(height: 24),
          Text(l10n.routingModeTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const _RoutingModeSelector(),
        ],
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.state});

  final OfflineMapState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(offlineMapControllerProvider.notifier);

    final installed = state.installed;
    final latest = state.latest;

    final String headline;
    if (!state.configured) {
      headline = l10n.offlineMapsNotConfigured;
    } else if (installed == null) {
      headline = l10n.offlineMapsNotInstalled;
    } else {
      headline = l10n.offlineMapsInstalled(
        formatPackDate(installed.version, l10n.localeName),
      );
    }

    final String? subline;
    if (!state.configured || state.busy) {
      subline = null;
    } else if (state.updateAvailable) {
      subline = l10n.offlineMapsUpdateAvailable(
        formatPackDate(latest!.version, l10n.localeName),
      );
    } else if (installed != null && latest != null) {
      subline = l10n.offlineMapsUpToDate;
    } else if (latest != null) {
      subline = l10n.offlineMapsSize(formatBytes(latest.sizeBytes));
    } else {
      subline = null;
    }

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    installed != null
                        ? Icons.offline_pin_rounded
                        : Icons.cloud_download_outlined,
                    color: installed != null
                        ? context.accentColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(headline, style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
              if (subline != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(subline, style: theme.textTheme.bodySmall),
                ),
              ],
              if (state.busy) ...[
                const SizedBox(height: 16),
                _ProgressBlock(state: state),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 12),
                _ErrorText(kind: state.error!),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (state.busy && state.op == OfflineOp.downloading)
                    TextButton(
                      onPressed: controller.cancel,
                      child: Text(l10n.offlineMapsCancel),
                    ),
                  if (!state.busy && installed != null)
                    TextButton(
                      onPressed: () => _confirmDelete(context, ref),
                      child: Text(l10n.offlineMapsDelete),
                    ),
                  if (state.canDownload)
                    FilledButton(
                      onPressed: () => _startDownload(context, ref, state),
                      child: Text(
                        installed == null
                            ? l10n.offlineMapsDownload
                            : l10n.offlineMapsUpdate,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDownload(
    BuildContext context,
    WidgetRef ref,
    OfflineMapState state,
  ) async {
    final l10n = AppLocalizations.of(context);
    final metered = await ref.read(isMeteredConnectionProvider)();
    if (metered && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.offlineMapsMobileDataTitle),
          content: Text(
            l10n.offlineMapsMobileDataBody(
              formatBytes(state.latest!.sizeBytes),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.offlineMapsCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.offlineMapsDownload),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(offlineMapControllerProvider.notifier).download();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.offlineMapsDeleteTitle),
        content: Text(l10n.offlineMapsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.offlineMapsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.offlineMapsDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(offlineMapControllerProvider.notifier).delete();
    }
  }
}

extension on BuildContext {
  Color get accentColor => Theme.of(this).colorScheme.secondary;
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.state});

  final OfflineMapState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = state.progress;
    final label = switch (state.op) {
      OfflineOp.downloading => l10n.offlineMapsDownloading(
        ((progress ?? 0) * 100).floor(),
      ),
      OfflineOp.verifying => l10n.offlineMapsVerifying,
      OfflineOp.installing => l10n.offlineMapsInstalling,
      OfflineOp.checking || OfflineOp.idle => l10n.offlineMapsChecking,
    };

    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // null = tidak tentu (menyemak, mengesahkan, memasang): kita tiada peratusan sebenar.
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.kind});

  final OfflineMapFailure kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = switch (kind) {
      OfflineMapFailure.network => l10n.offlineMapsErrorNetwork,
      OfflineMapFailure.storage => l10n.offlineMapsErrorStorage,
      OfflineMapFailure.checksum => l10n.offlineMapsErrorChecksum,
      OfflineMapFailure.incompatible => l10n.offlineMapsErrorIncompatible,
      OfflineMapFailure.manifestInvalid => l10n.offlineMapsErrorInvalid,
      OfflineMapFailure.notConfigured => l10n.offlineMapsNotConfigured,
      OfflineMapFailure.cancelled ||
      OfflineMapFailure.generic => l10n.offlineMapsErrorGeneric,
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _RoutingModeSelector extends ConsumerWidget {
  const _RoutingModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(routingModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<RoutingMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: RoutingMode.auto,
                label: Text(l10n.routingModeAuto),
              ),
              ButtonSegment(
                value: RoutingMode.onlineOnly,
                label: Text(l10n.routingModeOnline),
              ),
              ButtonSegment(
                value: RoutingMode.offlineOnly,
                label: Text(l10n.routingModeOffline),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(routingModeProvider.notifier).set(s.first),
          ),
        ),
        if (mode == RoutingMode.auto) ...[
          const SizedBox(height: 8),
          Text(
            l10n.routingModeAutoHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
