import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/music_settings.dart';
import 'equalizer_sheet.dart';
import 'music_sheet.dart';

/// Tetapan Muzik dalam halaman Tetapan: apa berlaku semasa suara navigasi, penyama, buka Muzik.
class MusicSettingsSection extends ConsumerWidget {
  const MusicSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(musicSettingsProvider);
    final controller = ref.read(musicSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(l10n.musicDuckTitle, style: theme.textTheme.titleSmall),
        ),
        RadioGroup<DuckMode>(
          groupValue: settings.duckMode,
          onChanged: (m) => m == null ? null : controller.setDuckMode(m),
          child: Column(
            children: [
              RadioListTile<DuckMode>(
                key: const ValueKey('music-duck-lower'),
                contentPadding: EdgeInsets.zero,
                value: DuckMode.duck,
                title: Text(l10n.musicDuckLower),
                subtitle: Text(l10n.musicDuckLowerHint),
              ),
              RadioListTile<DuckMode>(
                key: const ValueKey('music-duck-pause'),
                contentPadding: EdgeInsets.zero,
                value: DuckMode.pause,
                title: Text(l10n.musicDuckPause),
                subtitle: Text(l10n.musicDuckPauseHint),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('music-eq-open'),
                onPressed: () => showEqualizerSheet(context),
                icon: const Icon(Icons.equalizer_rounded),
                label: Text(l10n.musicEqualizer),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                key: const ValueKey('music-open'),
                onPressed: () => showMusicSheet(context),
                icon: const Icon(Icons.music_note_rounded),
                label: Text(l10n.musicOpenPlayer),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
