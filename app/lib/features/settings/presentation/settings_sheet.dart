import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../navigation/presentation/navigation_settings_sheet.dart';
import '../../offline_maps/presentation/offline_maps_sheet.dart';
import 'about_page.dart';

/// Membuka hab Tetapan. Nama dikekalkan supaya panggilan sedia ada tidak berubah.
Future<void> showAppearanceSheet(BuildContext context) =>
    showSettingsSheet(context);

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const SettingsSheet(),
  );
}

/// Hab tetapan: paparan (tema), navigasi (suara dan kamera), peta offline, dan tentang app.
/// Semua pilihan berkuat kuasa serta-merta; tiada butang Simpan (Bahagian 17.1).
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final navigator = Navigator.of(context);

    // Tutup lembaran ini dahulu, kemudian buka sasaran: dua lembaran bertindan mengelirukan.
    void openAfterClose(VoidCallback open) {
      navigator.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted) open();
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.palette_outlined,
            label: l10n.settingsAppearance,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_rounded),
                  label: Text(l10n.themeSystemShort),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_rounded),
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_rounded),
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.mode},
              onSelectionChanged: (s) => controller.setMode(s.first),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('amoled-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.themeAmoled),
            subtitle: Text(l10n.themeAmoledHint),
            value: settings.amoled,
            onChanged: controller.setAmoled,
          ),
          const SizedBox(height: 12),
          _SectionTitle(
            icon: Icons.navigation_outlined,
            label: l10n.settingsNavigation,
          ),
          const SizedBox(height: 4),
          const NavigationSettingsSection(),
          const SizedBox(height: 20),
          _SectionTitle(icon: Icons.map_outlined, label: l10n.settingsMaps),
          const SizedBox(height: 4),
          _LinkTile(
            icon: Icons.cloud_download_outlined,
            title: l10n.offlineMapsOpen,
            subtitle: l10n.settingsOfflineHint,
            onTap: () =>
                openAfterClose(() => showOfflineMapsSheet(navigator.context)),
          ),
          _LinkTile(
            icon: Icons.info_outline_rounded,
            title: l10n.aboutTitle,
            subtitle: l10n.settingsAboutHint,
            onTap: () => openAfterClose(
              () => navigator.push<void>(
                PageRouteBuilder<void>(
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (_, _, _) => const AboutPage(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
