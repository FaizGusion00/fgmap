import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/muslim_ai_settings.dart';
import '../domain/local_llm.dart';
import 'assistant_controller.dart';
import 'muslim_terms_sheet.dart';

/// Suis muat turun / padam model + opt-in FGMuslim AI dalam Tetapan.
class AssistantSettingsSection extends ConsumerWidget {
  const AssistantSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(assistantControllerProvider);
    final muslim = ref.watch(muslimAiSettingsProvider);
    final ready = state.modelReady;
    final downloading = state.modelStatus == AssistantModelStatus.downloading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.smart_toy_rounded,
            color: theme.colorScheme.primary,
          ),
          title: Text(l10n.assistantSettingsTitle),
          subtitle: Text(
            ready
                ? l10n.assistantSettingsReady
                : downloading
                ? l10n.assistantDownloading(
                    (state.downloadProgress * 100).round(),
                  )
                : l10n.assistantSettingsMissing,
          ),
        ),
        if (downloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              value: state.downloadProgress <= 0
                  ? null
                  : state.downloadProgress,
            ),
          ),
        if (!ready && !downloading)
          FilledButton.tonalIcon(
            key: const ValueKey('assistant-settings-download'),
            onPressed: () => unawaited(
              ref.read(assistantControllerProvider.notifier).downloadModel(),
            ),
            icon: const Icon(Icons.download_rounded),
            label: Text(l10n.assistantDownloadAction),
          ),
        if (ready)
          OutlinedButton.icon(
            key: const ValueKey('assistant-settings-delete'),
            onPressed: () => unawaited(
              ref.read(assistantControllerProvider.notifier).deleteModel(),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l10n.assistantDeleteModel),
          ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('muslim-ai-toggle'),
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            Icons.menu_book_rounded,
            color: theme.colorScheme.tertiary,
          ),
          title: Text(l10n.muslimAiSettingsTitle),
          subtitle: Text(
            muslim.isActive
                ? l10n.muslimAiSettingsOn
                : l10n.muslimAiSettingsOff,
          ),
          value: muslim.isActive,
          onChanged: (on) async {
            if (on) {
              await showMuslimTermsSheet(context, ref);
            } else {
              await ref.read(muslimAiSettingsProvider.notifier).disable();
            }
          },
        ),
      ],
    );
  }
}
