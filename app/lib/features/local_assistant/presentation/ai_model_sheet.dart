import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../offline_maps/presentation/offline_maps_sheet.dart'
    show formatBytes;
import '../domain/assistant_models.dart';
import '../domain/local_llm.dart';
import 'assistant_controller.dart';
import '../../../core/settings/device_tier.dart';

/// Helaian "Pilih model AI": lima model mengikut tahap (asas, sederhana, tinggi). Muat turun,
/// guna atau padam; hanya satu digunakan pada satu masa.
Future<void> showAiModelSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const SheetBottomInset(child: AiModelSheet()),
    );

class AiModelSheet extends ConsumerWidget {
  const AiModelSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            l10n.aiModelsTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.aiModelsIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          for (final tier in AiModelTier.values) ...[
            const SizedBox(height: 18),
            Text(
              switch (tier) {
                AiModelTier.basic => l10n.aiModelTierBasic,
                AiModelTier.medium => l10n.aiModelTierMedium,
                AiModelTier.high => l10n.aiModelTierHigh,
              },
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            for (final m in aiModelOptions.where((m) => m.tier == tier)) ...[
              const SizedBox(height: 8),
              _ModelCard(model: m),
            ],
          ],
        ],
      ),
    );
  }
}

String aiModelDescription(AppLocalizations l10n, AiModelOption m) =>
    switch (aiModelOptions.indexOf(m)) {
      0 => l10n.aiModelDescQwen3,
      1 => l10n.aiModelDescQwen35Small,
      2 => l10n.aiModelDescGemma4E2b,
      3 => l10n.aiModelDescQwen35Big,
      _ => l10n.aiModelDescGemma4E4b,
    };

class _ModelCard extends ConsumerWidget {
  const _ModelCard({required this.model});

  final AiModelOption model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Hanya medan yang kad ini perlukan: kad lain tidak dibina semula bila kemajuan muat turun berubah.
    final status = ref.watch(
      assistantControllerProvider.select((s) => s.modelStatus),
    );
    final downloadingId = ref.watch(
      assistantControllerProvider.select((s) => s.downloadingModelId),
    );
    final busy = ref.watch(assistantControllerProvider.select((s) => s.busy));
    final selected = ref.watch(selectedAiModelProvider);
    final installed =
        ref.watch(installedAiModelsProvider).value ?? const <String>{};
    final controller = ref.read(assistantControllerProvider.notifier);

    final isInstalled = installed.contains(model.id);
    final ramGb = ref.watch(deviceInfoProvider).totalMemGb;
    final recommended = ramGb > 0 && recommendedAiModel(ramGb).id == model.id;
    // Model yang memerlukan lebih RAM daripada telefon ini: boleh ditutup sistem atau sangat perlahan.
    final tooHeavy = ramGb > 0 && model.minRamGb > ramGb + 0.4;
    final inUse = selected.id == model.id && isInstalled;
    final downloadingThis =
        status == AssistantModelStatus.downloading && downloadingId == model.id;
    final anyDownloading = status == AssistantModelStatus.downloading;
    // Kemajuan diperhati oleh kad yang sedang memuat turun sahaja.
    final progress = downloadingThis
        ? ref.watch(
            assistantControllerProvider.select((s) => s.downloadProgress),
          )
        : 0.0;

    Future<void> use() async {
      await controller.selectModel(model.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.aiModelSwitched(model.name))),
        );
    }

    Future<void> download() async {
      if (tooHeavy) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.aiModelTooHeavyTitle),
            content: Text(
              l10n.aiModelTooHeavyBody(model.name, ramGb.toStringAsFixed(1)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.offlineMapsCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.aiModelDownload),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
      await controller.downloadModel(id: model.id);
    }

    Future<void> delete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.aiModelDeleteTitle(model.name)),
          content: Text(l10n.aiModelDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.offlineMapsCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.aiModelDelete),
            ),
          ],
        ),
      );
      if (ok == true) await controller.deleteModel(id: model.id);
    }

    return AnimatedContainer(
      key: ValueKey('ai-model-${model.id}'),
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: inUse
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(
          color: inUse ? scheme.primary : scheme.outlineVariant,
          width: inUse ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (inUse)
                _Badge(
                  text: l10n.aiModelInUse,
                  color: scheme.primary,
                  icon: Icons.check_circle_rounded,
                )
              else if (isInstalled)
                _Badge(
                  text: l10n.aiModelDownloaded,
                  color: scheme.tertiary,
                  icon: Icons.download_done_rounded,
                ),
            ],
          ),
          if (recommended || tooHeavy) ...[
            const SizedBox(height: 6),
            _Badge(
              text: recommended
                  ? l10n.aiModelRecommended
                  : l10n.aiModelTooHeavy(ramGb.toStringAsFixed(1)),
              color: recommended ? scheme.primary : scheme.error,
              icon: recommended
                  ? Icons.thumb_up_alt_rounded
                  : Icons.warning_amber_rounded,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            aiModelDescription(l10n, model),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                icon: Icons.sd_storage_rounded,
                text: formatBytes(model.sizeBytes),
              ),
              _Chip(
                icon: Icons.memory_rounded,
                text: l10n.aiModelRam('${model.minRamGb}'),
              ),
            ],
          ),
          if (downloadingThis) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress <= 0 ? null : progress,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.assistantDownloading((progress * 100).round()),
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (!isInstalled)
                  FilledButton.tonalIcon(
                    key: ValueKey('ai-model-download-${model.id}'),
                    onPressed: anyDownloading
                        ? null
                        : () => unawaited(download()),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(l10n.aiModelDownloadUse),
                  )
                else if (!inUse)
                  FilledButton.icon(
                    key: ValueKey('ai-model-use-${model.id}'),
                    onPressed: busy ? null : () => unawaited(use()),
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(l10n.aiModelUse),
                  ),
                const Spacer(),
                if (isInstalled)
                  TextButton.icon(
                    key: ValueKey('ai-model-delete-${model.id}'),
                    onPressed: () => unawaited(delete()),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l10n.aiModelDelete),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
