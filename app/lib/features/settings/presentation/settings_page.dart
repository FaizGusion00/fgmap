import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/settings/app_preferences.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/fade_through_route.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/presentation/navigation_settings_sheet.dart';
import '../../offline_maps/presentation/offline_maps_sheet.dart';
import '../../onboarding/data/onboarding_controller.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../saved_places/presentation/assign_place_flow.dart';
import '../../saved_places/presentation/save_place_sheet.dart';
import '../../search/presentation/search_history_controller.dart';
import 'about_page.dart';

/// Membuka halaman Tetapan (skrin penuh). Nama lama dikekalkan supaya panggilan sedia ada tidak berubah.
Future<void> showSettingsSheet(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));

Future<void> showAppearanceSheet(BuildContext context) =>
    showSettingsSheet(context);

/// Tetapan lengkap dalam kumpulan (Bahagian 17): paparan, navigasi dan suara, laporan, peta,
/// privasi, bantuan. Semua pilihan berkuat kuasa serta-merta dan disimpan setempat.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: const [
                FadeSlideIn(index: 0, child: _AppearanceGroup()),
                FadeSlideIn(index: 1, child: _SavedPlacesGroup()),
                FadeSlideIn(index: 2, child: _NavigationGroup()),
                FadeSlideIn(index: 3, child: _ReportsGroup()),
                FadeSlideIn(index: 4, child: _MapsGroup()),
                FadeSlideIn(index: 5, child: _PrivacyGroup()),
                FadeSlideIn(index: 6, child: _HelpGroup()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleSmall),
          if (hint != null)
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final prefs = ref.watch(appPreferencesProvider);
    final prefsController = ref.read(appPreferencesProvider.notifier);

    String scaleLabel(double v) => switch (v) {
      0.9 => 'A−',
      1.15 => 'A+',
      1.3 => 'A++',
      _ => 'A',
    };

    return _Group(
      icon: Icons.palette_outlined,
      title: l10n.settingsAppearance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppThemeMode>(
              key: const ValueKey('theme-mode'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_rounded),
                  label: Text(l10n.themeSystemShort),
                ),
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
              ],
              selected: {settings.mode},
              onSelectionChanged: (s) => controller.setMode(s.first),
            ),
          ),
          if (settings.mode == AppThemeMode.sun)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.themeSunHint,
                key: const ValueKey('sun-hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
          _Label(l10n.settingsTextSize, hint: l10n.settingsTextSizeHint),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<double>(
              key: const ValueKey('text-scale'),
              showSelectedIcon: false,
              segments: [
                for (final v in AppPreferences.textScales)
                  ButtonSegment(value: v, label: Text(scaleLabel(v))),
              ],
              selected: {prefs.textScale},
              onSelectionChanged: (s) => prefsController.setTextScale(s.first),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('reduce-motion-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsReduceMotion),
            subtitle: Text(l10n.settingsReduceMotionHint),
            value: prefs.reduceMotion,
            onChanged: prefsController.setReduceMotion,
          ),
          SwitchListTile(
            key: const ValueKey('haptics-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsHaptics),
            value: prefs.haptics,
            onChanged: prefsController.setHaptics,
          ),
          _Label(l10n.settingsLanguage),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String?>(
              key: const ValueKey('app-language'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: null,
                  label: Text(l10n.settingsLanguageSystem),
                ),
                ButtonSegment(
                  value: 'ms',
                  label: Text(l10n.settingsLanguageMalay),
                ),
                ButtonSegment(
                  value: 'en',
                  label: Text(l10n.settingsLanguageEnglish),
                ),
              ],
              selected: {prefs.languageCode},
              onSelectionChanged: (s) => prefsController.setLanguage(s.first),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Rumah dan Kerja: boleh ditetapkan dengan carian atau lokasi semasa, ditukar, atau dipadam.
class _SavedPlacesGroup extends ConsumerWidget {
  const _SavedPlacesGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(savedPlacesControllerProvider);
    SavedPlace? byId(String id) {
      for (final s in saved) {
        if (s.id == id) return s;
      }
      return null;
    }

    Widget row(SavedKind kind, String id) {
      final item = byId(id);
      void assign() => unawaited(assignSavedPlace(context, ref, kind));
      return ListTile(
        key: ValueKey('saved-row-${kind.name}'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(savedKindIcon(kind)),
        title: Text(savedKindLabel(l10n, kind)),
        subtitle: Text(
          item?.place.name ?? l10n.savedNotSet,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(item == null ? Icons.add_rounded : Icons.edit_outlined),
        onTap: item == null
            ? assign
            : () => unawaited(
                manageSavedPlace(context, ref, item, onChange: assign),
              ),
      );
    }

    return _Group(
      icon: Icons.home_outlined,
      title: l10n.settingsSavedPlaces,
      child: Column(
        children: [
          row(SavedKind.home, SavedPlace.homeId),
          row(SavedKind.work, SavedPlace.workId),
        ],
      ),
    );
  }
}

class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Group(
      icon: Icons.navigation_outlined,
      title: l10n.settingsNavigation,
      child: const NavigationSettingsSection(),
    );
  }
}

class _ReportsGroup extends ConsumerWidget {
  const _ReportsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(navigationSettingsProvider);
    return _Group(
      icon: Icons.add_alert_outlined,
      title: l10n.settingsReports,
      child: SwitchListTile(
        key: const ValueKey('report-alerts-switch'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.settingsReportAlerts),
        subtitle: Text(l10n.settingsReportAlertsHint),
        value: settings.reportAlerts,
        onChanged: ref
            .read(navigationSettingsProvider.notifier)
            .setReportAlerts,
      ),
    );
  }
}

class _MapsGroup extends StatelessWidget {
  const _MapsGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Group(
      icon: Icons.map_outlined,
      title: l10n.settingsMaps,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.cloud_download_outlined),
        title: Text(l10n.offlineMapsOpen),
        subtitle: Text(l10n.settingsOfflineHint),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => unawaited(showOfflineMapsSheet(context)),
      ),
    );
  }
}

class _PrivacyGroup extends ConsumerWidget {
  const _PrivacyGroup();

  Future<void> _clear(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsConfirmTitle),
        content: Text(l10n.settingsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.settingsConfirmCancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsConfirmDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await action();
    messenger?.showSnackBar(SnackBar(content: Text(l10n.settingsDeleted)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final access = ref.watch(locationAccessProvider);
    final status = switch (access) {
      LocationAccess.granted => l10n.settingsLocationAllowed,
      LocationAccess.serviceDisabled => l10n.settingsLocationOff,
      _ => l10n.settingsLocationNotAllowed,
    };

    return _Group(
      icon: Icons.shield_outlined,
      title: l10n.settingsPrivacy,
      child: Column(
        children: [
          ListTile(
            key: const ValueKey('location-status'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              access == LocationAccess.granted
                  ? Icons.my_location_rounded
                  : Icons.location_disabled_rounded,
            ),
            title: Text(status),
            subtitle: Text(l10n.settingsLocationOpen),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () =>
                unawaited(ref.read(locationServiceProvider).openAppSettings()),
          ),
          ListTile(
            key: const ValueKey('clear-history'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_toggle_off_rounded),
            title: Text(l10n.settingsClearHistory),
            onTap: () => _clear(
              context,
              ref.read(searchHistoryControllerProvider.notifier).clear,
            ),
          ),
          ListTile(
            key: const ValueKey('clear-saved'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.star_border_rounded),
            title: Text(l10n.settingsClearSaved),
            onTap: () => _clear(
              context,
              ref.read(savedPlacesControllerProvider.notifier).clear,
            ),
          ),
          ListTile(
            key: const ValueKey('clear-reports'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(l10n.settingsClearReports),
            onTap: () => _clear(
              context,
              ref.read(reportsControllerProvider.notifier).clear,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpGroup extends ConsumerWidget {
  const _HelpGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _Group(
      icon: Icons.help_outline_rounded,
      title: l10n.settingsHelp,
      child: Column(
        children: [
          ListTile(
            key: const ValueKey('welcome-again'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.waving_hand_outlined),
            title: Text(l10n.settingsWelcomeAgain),
            onTap: () async {
              final navigator = Navigator.of(context);
              await ref.read(onboardingDoneProvider.notifier).reset();
              // Tutup Tetapan supaya penghala (yang kini mengalihkan ke sambutan) kelihatan.
              if (navigator.mounted && navigator.canPop()) navigator.pop();
            },
          ),
          ListTile(
            key: const ValueKey('licences'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.settingsLicences),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appName,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.aboutTitle),
            subtitle: Text(l10n.settingsAboutHint),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(
              context,
            ).push<void>(fadeThroughRoute(const AboutPage())),
          ),
        ],
      ),
    );
  }
}
