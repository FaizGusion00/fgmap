import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/navigation_settings.dart';
import '../domain/camera_planner.dart';
import '../domain/instruction_text.dart';

Future<void> showNavigationSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const NavigationSettingsSheet(),
  );
}

/// Tetapan navigasi: suara (hidup/mati dan bahasa) dan jenis paparan kamera. Berkuat kuasa serta-merta.
class NavigationSettingsSheet extends ConsumerWidget {
  const NavigationSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(navigationSettingsProvider);
    final controller = ref.read(navigationSettingsProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.navSettingsTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.navVoiceTitle),
            value: settings.voiceEnabled,
            onChanged: controller.setVoiceEnabled,
          ),
          Text(l10n.navVoiceLanguage, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<VoiceLanguage?>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: null, label: Text(l10n.navVoiceFollowApp)),
                ButtonSegment(
                  value: VoiceLanguage.ms,
                  label: Text(l10n.navVoiceMalay),
                ),
                ButtonSegment(
                  value: VoiceLanguage.en,
                  label: Text(l10n.navVoiceEnglish),
                ),
              ],
              selected: {settings.voiceLanguage},
              onSelectionChanged: (s) => controller.setVoiceLanguage(s.first),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.navCameraTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<NavCameraMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: NavCameraMode.auto,
                  icon: Icon(Icons.auto_mode_rounded),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: NavCameraMode.tilted,
                  icon: Icon(Icons.threed_rotation_rounded),
                  label: Text('3D'),
                ),
                ButtonSegment(
                  value: NavCameraMode.flat,
                  icon: Icon(Icons.map_outlined),
                  label: Text('2D'),
                ),
              ],
              selected: {settings.cameraMode},
              onSelectionChanged: (s) => controller.setCameraMode(s.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.navCameraAutoHint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
