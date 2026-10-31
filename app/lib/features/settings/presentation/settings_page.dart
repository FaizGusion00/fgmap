import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_log.dart';
import '../../../core/location/location_service.dart';
import '../../../core/settings/app_preferences.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/fade_through_route.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../azan/presentation/azan_settings_section.dart';
import '../../music/presentation/music_settings_section.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/presentation/navigation_settings_sheet.dart';
import '../../offline_maps/presentation/offline_maps_sheet.dart';
import '../../onboarding/data/onboarding_controller.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../fuel/presentation/fuel_settings_group.dart';
import '../../legal/presentation/legal_page.dart';
import '../data/data_eraser.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../saved_places/presentation/assign_place_flow.dart';
import '../../saved_places/presentation/save_place_sheet.dart';
import '../../search/presentation/search_history_controller.dart';
import '../../trip_history/presentation/trip_history_page.dart';
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
              // Susunan untuk warga emas: paparan dan suara dahulu (yang paling kerap diubah),
              // kemudian ciri, dan privasi/bantuan di akhir.
              children: const [
                FadeSlideIn(index: 0, child: _AppearanceGroup()),
                FadeSlideIn(index: 1, child: _NavigationGroup()),
                FadeSlideIn(index: 2, child: _AzanGroup()),
                FadeSlideIn(index: 3, child: _MusicGroup()),
                FadeSlideIn(index: 4, child: _SavedPlacesGroup()),
                FadeSlideIn(index: 5, child: _FuelGroup()),
                FadeSlideIn(index: 6, child: _TripHistoryGroup()),
                FadeSlideIn(index: 7, child: _ReportsGroup()),
                FadeSlideIn(index: 8, child: _MapsGroup()),
                FadeSlideIn(index: 9, child: _PrivacyGroup()),
                FadeSlideIn(index: 10, child: _HelpGroup()),
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
          // Material (bukan DecoratedBox): ListTile/SwitchListTile melukis ink pada
          // nenek Material terdekat; DecoratedBox berwarna di tengah menyembunyikannya
          // dan Flutter 3.47+ menegaskan ralat.
          Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
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

class _Option<T> {
  const _Option(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Bar pilihan sama lebar. Label satu baris supaya "System" tidak terputus.
class _OptionBar<T> extends StatelessWidget {
  const _OptionBar({
    super.key,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final T selected;
  final List<_Option<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: _OptionCell(
                  option: option,
                  selected: option.value == selected,
                  onTap: () => onChanged(option.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionCell<T> extends StatelessWidget {
  const _OptionCell({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _Option<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 18, color: fg),
                  const SizedBox(height: 2),
                ],
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(icon, size: 20, color: tint),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
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
          _OptionBar<AppThemeMode>(
            key: const ValueKey('theme-mode'),
            selected: settings.mode,
            onChanged: controller.setMode,
            options: [
              _Option(
                AppThemeMode.system,
                l10n.themeSystemShort,
                icon: Icons.brightness_auto_rounded,
              ),
              _Option(
                AppThemeMode.light,
                l10n.themeLight,
                icon: Icons.light_mode_rounded,
              ),
              _Option(
                AppThemeMode.dark,
                l10n.themeDark,
                icon: Icons.dark_mode_rounded,
              ),
              _Option(
                AppThemeMode.sun,
                l10n.themeSun,
                icon: Icons.wb_twilight_rounded,
              ),
            ],
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
          _CompactSwitch(
            key: const ValueKey('amoled-switch'),
            icon: Icons.contrast_rounded,
            tint: const Color(0xFF94A3B8),
            title: l10n.themeAmoled,
            subtitle: l10n.themeAmoledHint,
            value: settings.amoled,
            onChanged: controller.setAmoled,
          ),
          _CompactSwitch(
            key: const ValueKey('easy-mode-switch'),
            icon: Icons.accessibility_new_rounded,
            tint: const Color(0xFF8B5CF6),
            title: l10n.settingsEasyMode,
            subtitle: l10n.settingsEasyModeHint,
            value: prefs.easyMode,
            onChanged: prefsController.setEasyMode,
          ),
          _Label(l10n.settingsTextSize, hint: l10n.settingsTextSizeHint),
          _OptionBar<double>(
            key: const ValueKey('text-scale'),
            selected: prefs.textScale,
            onChanged: prefsController.setTextScale,
            options: [
              for (final v in AppPreferences.textScales)
                _Option(v, scaleLabel(v)),
            ],
          ),
          _CompactSwitch(
            key: const ValueKey('reduce-motion-switch'),
            icon: Icons.motion_photos_off_rounded,
            tint: const Color(0xFF0EA5E9),
            title: l10n.settingsReduceMotion,
            subtitle: l10n.settingsReduceMotionHint,
            value: prefs.reduceMotion,
            onChanged: prefsController.setReduceMotion,
          ),
          _CompactSwitch(
            key: const ValueKey('haptics-switch'),
            icon: Icons.vibration_rounded,
            tint: const Color(0xFF22C55E),
            title: l10n.settingsHaptics,
            value: prefs.haptics,
            onChanged: prefsController.setHaptics,
          ),
          _Label(l10n.settingsLanguage),
          _OptionBar<String?>(
            key: const ValueKey('app-language'),
            selected: prefs.languageCode,
            onChanged: prefsController.setLanguage,
            options: [
              _Option(null, l10n.settingsLanguageSystem),
              _Option('ms', l10n.settingsLanguageMalay),
              _Option('en', l10n.settingsLanguageEnglish),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Waktu Azan: notifikasi waktu solat untuk lokasi semasa (dikira pada peranti).
class _AzanGroup extends StatelessWidget {
  const _AzanGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Group(
      icon: Icons.mosque_rounded,
      title: l10n.settingsAzan,
      child: const AzanSettingsSection(),
    );
  }
}

/// Muzik: tingkah laku semasa suara navigasi, penyama, dan pintasan membuka pemain.
class _MusicGroup extends StatelessWidget {
  const _MusicGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Group(
      icon: Icons.music_note_rounded,
      title: l10n.settingsMusic,
      child: const MusicSettingsSection(),
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

class _FuelGroup extends StatelessWidget {
  const _FuelGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Group(
      icon: Icons.local_gas_station_outlined,
      title: l10n.settingsFuel,
      child: const FuelSettingsSection(),
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

class _TripHistoryGroup extends StatelessWidget {
  const _TripHistoryGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Group(
      icon: Icons.history_rounded,
      title: l10n.tripHistoryTitle,
      child: ListTile(
        key: const ValueKey('trip-history-open'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.route_rounded),
        title: Text(l10n.tripHistoryTitle),
        subtitle: Text(l10n.tripHistoryMonth),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => unawaited(showTripHistoryPage(context)),
      ),
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
          ListTile(
            key: const ValueKey('privacy-policy'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.policy_outlined),
            title: Text(l10n.legalPrivacyTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => unawaited(showLegalPage(context, LegalDoc.privacy)),
          ),
          ListTile(
            key: const ValueKey('terms-of-use'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.legalTermsTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => unawaited(showLegalPage(context, LegalDoc.terms)),
          ),
          const Divider(height: 24),
          ListTile(
            key: const ValueKey('clear-all'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.settingsClearAll,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(l10n.settingsClearAllHint),
            onTap: () => _clear(context, () => eraseAllUserData(ref)),
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
            key: const ValueKey('copy-error-report'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l10n.settingsCopyErrorReport),
            subtitle: Text(l10n.settingsCopyErrorReportHint),
            onTap: () async {
              final log = ref.read(errorLogProvider);
              final messenger = ScaffoldMessenger.maybeOf(context);
              if (log.length == 0) {
                messenger?.showSnackBar(
                  SnackBar(content: Text(l10n.settingsErrorReportEmpty)),
                );
                return;
              }
              final info = ref.read(appPackageInfoProvider).value;
              await Clipboard.setData(
                ClipboardData(
                  text: log.report(
                    appVersion: info == null
                        ? null
                        : '${info.version}+${info.buildNumber}',
                  ),
                ),
              );
              messenger?.showSnackBar(
                SnackBar(content: Text(l10n.settingsErrorReportCopied)),
              );
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
