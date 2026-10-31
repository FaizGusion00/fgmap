import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/navigation_settings.dart';
import '../domain/camera_planner.dart';
import '../domain/instruction_text.dart';

Future<void> showNavigationSettingsSheet(
  BuildContext context, {
  VoidCallback? onShareEta,
  VoidCallback? onEmergency,
  VoidCallback? onMusic,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NavigationSettingsSheet(
      onShareEta: onShareEta,
      onEmergency: onEmergency,
      onMusic: onMusic,
    ),
  );
}

/// Tetapan navigasi sebagai lembaran sendiri (dibuka dari butang sisi semasa memandu).
class NavigationSettingsSheet extends StatelessWidget {
  const NavigationSettingsSheet({
    super.key,
    this.onShareEta,
    this.onEmergency,
    this.onMusic,
  });

  /// Buka Muzik (tiada butang sendiri pada HUD supaya skrin tidak sesak).
  final VoidCallback? onMusic;

  /// Tindakan pantas di bahagian atas (kongsi masa tiba, kecemasan); tersembunyi jika null. Lembaran
  /// ditutup dahulu, kemudian tindakan dijalankan.
  final VoidCallback? onShareEta;
  final VoidCallback? onEmergency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.navSettingsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (onShareEta != null || onEmergency != null || onMusic != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onShareEta != null)
                  ActionChip(
                    key: const ValueKey('nav-share-eta'),
                    avatar: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(l10n.shareEtaAction),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onShareEta!();
                    },
                  ),
                if (onMusic != null)
                  ActionChip(
                    key: const ValueKey('nav-music'),
                    avatar: const Icon(Icons.music_note_rounded, size: 18),
                    label: Text(l10n.musicOpen),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onMusic!();
                    },
                  ),
                if (onEmergency != null)
                  ActionChip(
                    key: const ValueKey('nav-emergency'),
                    avatar: Icon(
                      Icons.emergency_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(l10n.emergencyTitle),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEmergency!();
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const NavigationSettingsSection(showTheme: true),
        ],
      ),
    );
  }
}

/// Kandungan tetapan navigasi: suara (hidup/mati dan bahasa) dan jenis paparan kamera. Berkuat kuasa
/// serta-merta. Digunakan oleh lembaran navigasi dan hab Tetapan.
///
/// [showTheme]: tambah pilihan paparan siang/malam/auto (matahari). Hanya dalam lembaran navigasi
/// kerana halaman Tetapan sudah mempunyai kumpulan Paparan sendiri. Pilihan ini ialah tema global app.
class NavigationSettingsSection extends ConsumerWidget {
  const NavigationSettingsSection({super.key, this.showTheme = false});

  final bool showTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(navigationSettingsProvider);
    final controller = ref.read(navigationSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTheme) ...[
          Text(l10n.navThemeTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          const _NavThemeRow(),
          const SizedBox(height: 20),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            settings.voiceEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
          ),
          title: Text(l10n.navVoiceTitle),
          value: settings.voiceEnabled,
          onChanged: controller.setVoiceEnabled,
        ),
        const SizedBox(height: 8),
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
        Text(l10n.settingsVoiceVolume, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<double>(
            key: const ValueKey('voice-volume'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0.5, label: Text(l10n.settingsVolumeLow)),
              ButtonSegment(
                value: 0.75,
                label: Text(l10n.settingsVolumeMedium),
              ),
              ButtonSegment(value: 1.0, label: Text(l10n.settingsVolumeHigh)),
            ],
            selected: {settings.voiceVolume},
            onSelectionChanged: (s) => controller.setVoiceVolume(s.first),
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.settingsSpeechRate, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<double>(
            key: const ValueKey('speech-rate'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0.42, label: Text(l10n.settingsRateSlow)),
              ButtonSegment(value: 0.5, label: Text(l10n.settingsRateNormal)),
              ButtonSegment(value: 0.58, label: Text(l10n.settingsRateFast)),
            ],
            selected: {settings.speechRate},
            onSelectionChanged: (s) => controller.setSpeechRate(s.first),
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
        const SizedBox(height: 20),
        Text(l10n.navOverspeedTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            key: const ValueKey('overspeed-tolerance'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: -1, label: Text(l10n.navOverspeedOff)),
              const ButtonSegment(value: 0, label: Text('+0')),
              const ButtonSegment(value: 5, label: Text('+5')),
              const ButtonSegment(value: 10, label: Text('+10')),
            ],
            selected: {settings.overspeedToleranceKmh},
            onSelectionChanged: (s) =>
                controller.setOverspeedTolerance(s.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.navOverspeedHint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Pilihan paparan cepat semasa memandu: Siang, Malam, Auto (matahari) dan Sistem. Berkuat kuasa
/// serta-merta pada app dan peta.
class _NavThemeRow extends ConsumerWidget {
  const _NavThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeControllerProvider.select((s) => s.mode));
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AppThemeMode>(
        key: const ValueKey('nav-theme-mode'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: AppThemeMode.light,
            icon: const Icon(Icons.light_mode_rounded),
            label: Text(l10n.themeLight),
          ),
          ButtonSegment(
            value: AppThemeMode.dark,
            icon: const Icon(Icons.dark_mode_rounded),
            label: Text(l10n.themeDark),
          ),
          ButtonSegment(
            value: AppThemeMode.sun,
            icon: const Icon(Icons.wb_twilight_rounded),
            label: Text(l10n.themeSun),
          ),
          ButtonSegment(
            value: AppThemeMode.system,
            icon: const Icon(Icons.brightness_auto_rounded),
            label: Text(l10n.themeSystemShort),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) =>
            ref.read(themeControllerProvider.notifier).setMode(s.first),
      ),
    );
  }
}
