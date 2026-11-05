import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/changelog.dart';

/// Log perubahan penuh mengikut bahasa (`ms` atau `en`), dibaca daripada aset yang dibundel.
final changelogProvider = FutureProvider.family<List<ChangelogRelease>, String>(
  (ref, language) async => parseChangelog(
    await rootBundle.loadString('assets/changelog/changelog.$language.md'),
  ),
);

/// "Semua perubahan": setiap versi FGMaps dengan perbandingan sebelum dan selepas bagi setiap perubahan,
/// supaya pengguna tahu apa yang berubah dan cara menggunakannya.
class ChangelogPage extends ConsumerWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode == 'ms'
        ? 'ms'
        : 'en';
    final releases = ref.watch(changelogProvider(language));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changelogTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: releases.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.changelogLoadFailed,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (list) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Text(
                    l10n.changelogIntro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  for (var r = 0; r < list.length; r++)
                    _Release(release: list[r], latest: r == 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Release extends StatelessWidget {
  const _Release({required this.release, required this.latest});

  final ChangelogRelease release;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = release.date;
    return Column(
      key: ValueKey('changelog-release-${release.version}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              l10n.changelogVersion(release.version),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (latest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.changelogLatest,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (date != null)
              Text(
                MaterialLocalizations.of(context).formatFullDate(date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (release.summary != null) ...[
          const SizedBox(height: 6),
          Text(release.summary!, style: theme.textTheme.bodyMedium),
        ],
        for (var i = 0; i < release.entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _EntryCard(
              key: ValueKey('changelog-entry-${release.version}-$i'),
              entry: release.entries[i],
            ),
          ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({super.key, required this.entry});

  final ChangelogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tip = entry.tip;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _Side(
              icon: Icons.history_rounded,
              label: l10n.changelogBefore,
              text: entry.before,
              accent: scheme.onSurfaceVariant,
              background: scheme.onSurface.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.07 : 0.045,
              ),
            ),
            const SizedBox(height: 8),
            _Side(
              icon: Icons.auto_awesome_rounded,
              label: l10n.changelogAfter,
              text: entry.after,
              accent: scheme.primary,
              background: scheme.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08,
              ),
            ),
            if (tip != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${l10n.changelogTip}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: tip),
                        ],
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu sisi perbandingan ("Sebelum" atau "Selepas").
class _Side extends StatelessWidget {
  const _Side({
    required this.icon,
    required this.label,
    required this.text,
    required this.accent,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String text;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
