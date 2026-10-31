import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../core/settings/easy_mode_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/music_settings.dart';
import '../data/radio_favorites.dart';
import '../data/radio_health.dart';
import '../domain/apple_music.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';
import 'apple_music_controller.dart';
import 'mini_player.dart';
import 'music_search_controller.dart';
import 'music_widgets.dart';
import 'player_controller.dart';

Future<void> showMusicSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const SheetBottomInset(child: MusicSheet()),
);

/// Lembaran Muzik: satu medan carian besar, tiga tab (Lagu / Radio / Fail saya) dengan ikon +
/// teks, senarai hasil, dan pemain kecil di bawah. "Cari lagu -> main" dalam dua ketukan.
class MusicSheet extends ConsumerStatefulWidget {
  const MusicSheet({super.key});

  @override
  ConsumerState<MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends ConsumerState<MusicSheet> {
  final _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    final search = ref.read(musicSearchProvider.notifier);
    final tab = MusicTab.values[ref.read(musicSettingsProvider).lastTab];
    _field.text = ref.read(musicSearchProvider).query;
    WidgetsBinding.instance.addPostFrameCallback((_) => search.setTab(tab));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final state = ref.watch(musicSearchProvider);
    final search = ref.read(musicSearchProvider.notifier);
    final current = ref.watch(
      playerControllerProvider.select((s) => s.current),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const ValueKey('music-search'),
              controller: _field,
              textInputAction: TextInputAction.search,
              style: easy
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: l10n.musicSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _field.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.searchClear,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _field.clear();
                          search.setQuery('');
                        },
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: easy ? 20 : 14),
              ),
              onChanged: (q) {
                setState(() {});
                search.setQuery(q);
              },
              onSubmitted: (_) => search.refresh(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<MusicTab>(
                key: const ValueKey('music-tabs'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: MusicTab.songs,
                    icon: const Icon(Icons.music_note_rounded),
                    label: Text(l10n.musicTabSongs),
                  ),
                  ButtonSegment(
                    value: MusicTab.radio,
                    icon: const Icon(Icons.radio_rounded),
                    label: Text(l10n.musicTabRadio),
                  ),
                  ButtonSegment(
                    value: MusicTab.local,
                    icon: const Icon(Icons.folder_rounded),
                    label: Text(l10n.musicTabLocal),
                  ),
                ],
                selected: {state.tab},
                onSelectionChanged: (s) {
                  search.setTab(s.first);
                  ref
                      .read(musicSettingsProvider.notifier)
                      .setLastTab(s.first.index);
                },
              ),
            ),
          ),
          if (state.tab == MusicTab.radio)
            _ChipRow(
              key: const ValueKey('music-regions'),
              wrap: true,
              children: [
                for (final r in RadioRegion.values)
                  ChoiceChip(
                    key: ValueKey('music-region-${r.name}'),
                    avatar: r == RadioRegion.favorites
                        ? const Icon(Icons.star_rounded, size: 18)
                        : null,
                    label: Text(_regionLabel(l10n, r)),
                    selected: state.region == r,
                    onSelected: (_) => search.setRegion(r),
                  ),
              ],
            )
          else if (state.tab == MusicTab.songs)
            _ChipRow(
              key: const ValueKey('music-suggestions'),
              children: [
                for (final q in _songSuggestions)
                  ActionChip(
                    key: ValueKey('music-suggest-$q'),
                    label: Text(q),
                    onPressed: () {
                      _field.text = q;
                      _field.selection = TextSelection.collapsed(
                        offset: q.length,
                      );
                      setState(() {});
                      search.searchFor(q);
                    },
                  ),
              ],
            )
          else
            const SizedBox(height: 4),
          if (state.tab == MusicTab.songs) const _AppleMusicCard(),
          Expanded(
            child: _Results(state: state, scroll: scroll, easy: easy),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              l10n.musicAttribution,
              key: const ValueKey('music-attribution'),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (current != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: MiniPlayer(),
            ),
        ],
      ),
    );
  }
}

/// Ajakan menyambung Apple Music (iOS sahaja). Tidak dipaparkan di Android, apabila ciri ditutup,
/// atau apabila lagu penuh sudah boleh dimain.
class _AppleMusicCard extends ConsumerWidget {
  const _AppleMusicCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appleMusicStatusProvider);
    if (!status.supported || status.ready) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (body, canConnect) = switch (status.access) {
      AppleMusicAccess.denied ||
      AppleMusicAccess.restricted => (l10n.musicAppleDenied, false),
      AppleMusicAccess.authorized => (
        status.canBecomeSubscriber
            ? l10n.musicAppleNeedsSubscription
            : l10n.musicAppleUnavailable,
        false,
      ),
      _ => (l10n.musicAppleConnectBody, true),
    };
    return Padding(
      key: const ValueKey('apple-music-card'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card.filled(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.musicAppleConnectTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodySmall),
              if (canConnect)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('apple-music-connect'),
                    onPressed: () =>
                        ref.read(appleMusicStatusProvider.notifier).connect(),
                    icon: const Icon(Icons.library_music_rounded),
                    label: Text(l10n.musicAppleConnect),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cadangan carian tab Lagu: genre/bahasa yang diminta pemandu Malaysia. Ia hanyalah pertanyaan
/// biasa ke katalog Audius.
const _songSuggestions = [
  'Malay',
  'Indonesia',
  'Japan',
  'K-pop',
  'J-pop',
  'City Pop',
  'Anime',
  'Dangdut',
  'Nasyid',
  'Lo-fi',
];

String _regionLabel(AppLocalizations l10n, RadioRegion r) => switch (r) {
  RadioRegion.favorites => l10n.musicRegionFavorites,
  RadioRegion.malaysia => l10n.musicRegionMalaysia,
  RadioRegion.indonesia => l10n.musicRegionIndonesia,
  RadioRegion.japan => l10n.musicRegionJapan,
  RadioRegion.jpop => l10n.musicRegionJpop,
  RadioRegion.korea => l10n.musicRegionKorea,
  RadioRegion.kpop => l10n.musicRegionKpop,
};

/// Baris cip yang boleh digulung mendatar.
class _ChipRow extends StatelessWidget {
  const _ChipRow({super.key, required this.children, this.wrap = false});

  final List<Widget> children;

  /// Semua cip kelihatan (dua baris di telefon sempit) dan bukannya digulung: Indonesia, Korea dan
  /// K-pop mesti ternampak tanpa pengguna perlu meneka ada lagi di sebelah kanan.
  final bool wrap;

  @override
  Widget build(BuildContext context) => wrap
      ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 8, runSpacing: 4, children: children),
          ),
        )
      : SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => children[i],
          ),
        );
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.state,
    required this.scroll,
    required this.easy,
  });

  final MusicSearchState state;
  final ScrollController scroll;
  final bool easy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final search = ref.read(musicSearchProvider.notifier);
    final player = ref.read(playerControllerProvider.notifier);
    final currentKey = ref.watch(
      playerControllerProvider.select((s) => s.current?.key),
    );
    final favorites = ref.watch(radioFavoritesProvider);
    final health = ref.watch(radioHealthProvider.notifier);
    ref.watch(
      radioHealthProvider,
    ); // bina semula apabila stesen ditanda gagal/pulih

    Widget message(IconData icon, String text, {Widget? action}) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      children: [
        Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          text,
          key: const ValueKey('music-message'),
          textAlign: TextAlign.center,
          style: easy
              ? theme.textTheme.titleMedium
              : theme.textTheme.bodyMedium,
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );

    final importButton = FilledButton.tonalIcon(
      key: const ValueKey('music-import'),
      onPressed: () async {
        final n = await search.importLocal();
        if (context.mounted && n > 0) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(l10n.musicImported(n))));
        }
      },
      icon: const Icon(Icons.library_add_rounded),
      label: Text(l10n.musicImport),
    );

    switch (state.status) {
      case MusicSearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case MusicSearchStatus.failed:
        return message(
          Icons.cloud_off_rounded,
          state.tab == MusicTab.local
              ? l10n.musicErrorSource(l10n.musicSourceLocal)
              : l10n.musicErrorSource(trackSourceName(l10n, state.tab.source)),
          action: TextButton(
            onPressed: search.refresh,
            child: Text(l10n.navContinue),
          ),
        );
      case MusicSearchStatus.idle:
      case MusicSearchStatus.empty:
        if (state.query.trim().isNotEmpty &&
            state.status == MusicSearchStatus.empty) {
          return message(
            Icons.search_off_rounded,
            state.tab == MusicTab.songs
                ? '${l10n.musicNoResults(state.query.trim())}\n\n${l10n.musicNoResultsSongsHint}'
                : l10n.musicNoResults(state.query.trim()),
            action: switch (state.tab) {
              MusicTab.local => importButton,
              MusicTab.songs => FilledButton.tonalIcon(
                key: const ValueKey('music-try-radio'),
                onPressed: () => search.setTab(MusicTab.radio),
                icon: const Icon(Icons.radio_rounded),
                label: Text(l10n.musicTryRadio),
              ),
              MusicTab.radio => null,
            },
          );
        }
        return switch (state.tab) {
          MusicTab.songs => message(
            Icons.music_note_rounded,
            l10n.musicEmptySongs,
          ),
          MusicTab.radio when state.region == RadioRegion.favorites => message(
            Icons.star_outline_rounded,
            l10n.musicEmptyFavorites,
          ),
          MusicTab.radio => message(Icons.radio_rounded, l10n.musicEmptyRadio),
          MusicTab.local => message(
            Icons.folder_open_rounded,
            l10n.musicEmptyLocal,
            action: importButton,
          ),
        };
      case MusicSearchStatus.ready:
        return ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          itemCount:
              state.results.length + (state.tab == MusicTab.local ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.results.length) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(child: importButton),
              );
            }
            final t = state.results[i];
            final selected = t.key == currentKey;
            final unreachable =
                state.tab == MusicTab.radio && health.isFailed(t);
            final playIcon = Icon(
              selected
                  ? Icons.graphic_eq_rounded
                  : Icons.play_circle_outline_rounded,
              color: theme.colorScheme.primary,
              size: easy ? 34 : 28,
            );
            return ListTile(
              key: ValueKey('music-result-${t.key}'),
              minTileHeight: easy ? 72 : 60,
              leading: TrackArt(track: t, size: easy ? 56 : 48),
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (easy
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleSmall)
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? theme.colorScheme.primary
                              : unreachable
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
              ),
              subtitle: Text(
                [
                  if (t.isLive) l10n.musicLive,
                  if (unreachable) l10n.musicRadioUnreachable,
                  if (t.artist != null) t.artist!,
                  if (t.source == TrackSource.audius) l10n.musicViaAudius,
                  if (t.source == TrackSource.appleMusic)
                    l10n.musicViaAppleMusic,
                  if (t.duration != null) formatTrackTime(t.duration!),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: switch (state.tab) {
                MusicTab.local => IconButton(
                  tooltip: l10n.musicRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => search.removeLocal(t),
                ),
                MusicTab.radio => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('music-fav-${t.key}'),
                      tooltip: favorites.contains(t)
                          ? l10n.musicFavoriteRemove
                          : l10n.musicFavoriteAdd,
                      iconSize: easy ? 32 : 26,
                      icon: Icon(
                        favorites.contains(t)
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: favorites.contains(t)
                            ? Colors.amber.shade700
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () =>
                          ref.read(radioFavoritesProvider.notifier).toggle(t),
                    ),
                    playIcon,
                  ],
                ),
                MusicTab.songs => playIcon,
              },
              onTap: () => player.playTrack(t, queue: state.results),
            );
          },
        );
    }
  }
}
