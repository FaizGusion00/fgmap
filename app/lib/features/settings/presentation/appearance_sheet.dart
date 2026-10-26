import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'about_page.dart';

Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const AppearanceSheet(),
  );
}

/// Pilihan tema (Bahagian 17.1): berkuat kuasa serta-merta, tiada butang Simpan.
/// "Auto ikut matahari" dijadualkan dalam Fasa 3.
class AppearanceSheet extends ConsumerWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final navigator = Navigator.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.mode},
              onSelectionChanged: (selection) =>
                  controller.setMode(selection.first),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.themeAmoled),
            subtitle: Text(l10n.themeAmoledHint),
            value: settings.amoled,
            onChanged: controller.setAmoled,
          ),
          const Divider(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.aboutTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              navigator.pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!navigator.mounted) return;
                navigator.push<void>(
                  PageRouteBuilder<void>(
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, _, _) => const AboutPage(),
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }
}
