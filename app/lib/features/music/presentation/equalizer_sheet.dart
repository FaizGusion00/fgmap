import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/music_settings.dart';
import '../domain/eq.dart';
import 'player_controller.dart';

Future<void> showEqualizerSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const SheetBottomInset(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: EqualizerPanel(),
        ),
      ),
    );

String eqPresetName(AppLocalizations l10n, EqPreset p) => switch (p) {
  EqPreset.normal => l10n.musicEqPresetNormal,
  EqPreset.bass => l10n.musicEqPresetBass,
  EqPreset.treble => l10n.musicEqPresetTreble,
  EqPreset.vocal => l10n.musicEqPresetVocal,
  EqPreset.custom => l10n.musicEqPresetCustom,
};

const _bandLabels = ['60', '230', '910', '3.6k', '14k'];

/// Pratetap (Normal/Bes/Trebel/Suara/Tersuai) dan lima peluncur jalur (aktif dalam Tersuai).
/// iOS: just_audio tiada penyama; panel menerangkannya dengan jujur dan kawalan dilumpuhkan.
class EqualizerPanel extends ConsumerWidget {
  const EqualizerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eq = ref.watch(musicSettingsProvider.select((s) => s.eq));
    final settings = ref.read(musicSettingsProvider.notifier);
    final supported = ref.watch(musicEngineProvider).equalizerSupported;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.musicEqualizer,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (!supported)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.musicEqUnsupported,
              key: const ValueKey('eq-unsupported'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        SwitchListTile(
          key: const ValueKey('eq-enable'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.musicEqEnable),
          value: eq.enabled,
          onChanged: supported ? settings.setEqEnabled : null,
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<EqPreset>(
            key: const ValueKey('eq-preset'),
            showSelectedIcon: false,
            segments: [
              for (final p in EqPreset.values)
                ButtonSegment(value: p, label: Text(eqPresetName(l10n, p))),
            ],
            selected: {eq.preset},
            onSelectionChanged: supported
                ? (s) => settings.setEqPreset(s.first)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < eqBands; i++)
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(_bandLabels[i], style: theme.textTheme.labelMedium),
              ),
              Expanded(
                child: Slider(
                  key: ValueKey('eq-band-$i'),
                  min: eqMinDb,
                  max: eqMaxDb,
                  divisions: 20,
                  value: eq.gainsDb[i].clamp(eqMinDb, eqMaxDb),
                  label: '${eq.gainsDb[i].round()} dB',
                  onChanged:
                      supported && eq.enabled && eq.preset == EqPreset.custom
                      ? (v) => settings.setCustomGain(i, v)
                      : null,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${eq.gainsDb[i].round()} dB',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
