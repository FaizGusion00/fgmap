import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/music_settings.dart';
import '../domain/track.dart';
import 'mini_player.dart';
import 'music_search_controller.dart';
import 'music_widgets.dart';
import 'player_controller.dart';

Future<void> showMusicSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const MusicSheet(),
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
          const SizedBox(height: 4),
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
            l10n.musicNoResults(state.query.trim()),
            action: state.tab == MusicTab.local ? importButton : null,
          );
        }
        return switch (state.tab) {
          MusicTab.songs => message(
            Icons.music_note_rounded,
            l10n.musicEmptySongs,
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
                          color: selected ? theme.colorScheme.primary : null,
                        ),
              ),
              subtitle: Text(
                [
                  if (t.isLive) l10n.musicLive,
                  if (t.artist != null) t.artist!,
                  if (t.source == TrackSource.audius) l10n.musicViaAudius,
                  if (t.duration != null) formatTrackTime(t.duration!),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: state.tab == MusicTab.local
                  ? IconButton(
                      tooltip: l10n.musicRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => search.removeLocal(t),
                    )
                  : Icon(
                      selected
                          ? Icons.graphic_eq_rounded
                          : Icons.play_circle_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: easy ? 34 : 28,
                    ),
              onTap: () => player.playTrack(t, queue: state.results),
            );
          },
        );
    }
  }
}
