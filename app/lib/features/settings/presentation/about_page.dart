import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/widgets/fade_through_route.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'changelog_page.dart';

final appPackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Versi yang diterangkan oleh kad "Baharu dalam versi". Mesti sama dengan `version:` dalam pubspec.yaml;
/// `about_page_test.dart` gagal jika berbeza.
const aboutWhatsNewVersion = '1.8.0';

/// Tarikh keluaran versi [aboutWhatsNewVersion] (dipaparkan dalam About).
final aboutReleaseDate = DateTime(2026, 11, 6);

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final packageInfo = ref.watch(appPackageInfoProvider);

    final version = packageInfo.when(
      data: (info) => info.version,
      loading: () => l10n.aboutVersionLoading,
      error: (_, _) => l10n.aboutVersionUnavailable,
    );
    final build = packageInfo.value?.buildNumber;
    final released = MaterialLocalizations.of(
      context,
    ).formatMediumDate(aboutReleaseDate);
    final sources = <(IconData, String, String)>[
      (Icons.map_rounded, l10n.aboutSrcMapTitle, l10n.aboutSrcMap),
      (
        Icons.satellite_alt_rounded,
        l10n.aboutSrcSatelliteTitle,
        l10n.aboutSrcSatellite,
      ),
      (
        Icons.alt_route_rounded,
        l10n.aboutSrcRoutingTitle,
        l10n.aboutSrcRouting,
      ),
      (Icons.search_rounded, l10n.aboutSrcSearchTitle, l10n.aboutSrcSearch),
      (Icons.toll_rounded, l10n.aboutSrcTollsTitle, l10n.aboutSrcTolls),
      (Icons.videocam_rounded, l10n.aboutSrcCctvTitle, l10n.aboutSrcCctv),
      (Icons.door_front_door_rounded, l10n.aboutSrcOsmTitle, l10n.aboutSrcOsm),
      (Icons.mosque_rounded, l10n.aboutSrcMasjidTitle, l10n.aboutSrcMasjid),
      (
        Icons.access_time_rounded,
        l10n.aboutSrcPrayerTitle,
        l10n.aboutSrcPrayer,
      ),
      (
        Icons.local_gas_station_rounded,
        l10n.aboutSrcFuelTitle,
        l10n.aboutSrcFuel,
      ),
      (
        Icons.wb_cloudy_rounded,
        l10n.aboutSrcWeatherTitle,
        l10n.aboutSrcWeather,
      ),
      (Icons.air_rounded, l10n.aboutSrcAirTitle, l10n.aboutSrcAir),
      (Icons.music_note_rounded, l10n.aboutSrcMusicTitle, l10n.aboutSrcMusic),
      (Icons.auto_awesome_rounded, l10n.aboutSrcAiTitle, l10n.aboutSrcAi),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      // Logo app sebenar (sama dengan ikon pelancar), bukan ikon generik.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/branding/fgmap-app-icon.png',
                            key: const ValueKey('about-logo'),
                            width: 96,
                            height: 96,
                            // Sumber 1024 px; nyahkod pada saiz paparan (3x) sahaja.
                            cacheWidth: 288,
                            filterQuality: FilterQuality.medium,
                            semanticLabel: l10n.appName,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.appName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.aboutDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _AboutRow(
                        icon: Icons.info_outline_rounded,
                        label: l10n.aboutVersion,
                        value: version,
                      ),
                      if (build != null && build.isNotEmpty) ...[
                        const Divider(height: 1, indent: 56, endIndent: 16),
                        _AboutRow(
                          icon: Icons.build_circle_outlined,
                          label: l10n.aboutBuild,
                          value: build,
                        ),
                      ],
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _AboutRow(
                        icon: Icons.event_rounded,
                        label: l10n.aboutReleased,
                        value: released,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _AboutRow(
                        icon: Icons.code_rounded,
                        label: l10n.aboutDeveloper,
                        value: l10n.aboutDeveloperName,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _AboutRow(
                        icon: Icons.business_rounded,
                        label: l10n.aboutOwner,
                        value: l10n.aboutOwnerName,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      key: const ValueKey('about-whats-new'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aboutWhatsNewTitle(aboutWhatsNewVersion),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final item in [
                          l10n.aboutNew1,
                          l10n.aboutNew2,
                          l10n.aboutNew3,
                          l10n.aboutNew4,
                          l10n.aboutNew5,
                          l10n.aboutNew6,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    key: const ValueKey('about-all-changes'),
                    leading: Icon(
                      Icons.compare_arrows_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.aboutAllChanges),
                    subtitle: Text(l10n.aboutAllChangesHint),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(
                      context,
                    ).push<void>(fadeThroughRoute(const ChangelogPage())),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      key: const ValueKey('about-attribution'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aboutAttributionTitle,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.aboutDataSourcesHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final (icon, title, detail) in sources)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        detail,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    key: const ValueKey('about-licenses'),
                    leading: Icon(
                      Icons.description_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(l10n.aboutLicenses),
                    subtitle: Text(l10n.aboutLicensesHint),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: l10n.appName,
                      applicationVersion: version,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.aboutCopyright(DateTime.now().year),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
