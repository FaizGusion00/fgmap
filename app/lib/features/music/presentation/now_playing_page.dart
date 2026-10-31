import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../core/settings/easy_mode_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/radio_favorites.dart';
import '../domain/player_state.dart';
import '../domain/track.dart';
import 'equalizer_sheet.dart';
import 'music_widgets.dart';
import 'player_controller.dart';

Future<void> showNowPlaying(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const SheetBottomInset(child: NowPlayingSheet()),
);

/// Pemain penuh: karya seni besar, tajuk, sumber, peluncur (bukan untuk siaran langsung), kawalan
/// besar (>= 64 dp), kelantangan, penyama dan baris gilir.
class NowPlayingSheet extends ConsumerWidget {
  const NowPlayingSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final current = state.current;
    if (current == null) {
      return SizedBox(
        height: 200,
        child: Center(child: Text(l10n.musicNowPlaying)),
      );
    }
    final playing = state.isPlaying;
    final duration = state.duration;
    final big = easy ? 84.0 : 72.0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Center(child: TrackArt(track: current, size: 220)),
          const SizedBox(height: 20),
          Text(
            current.title,
            key: const ValueKey('now-title'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.nowPlaying ??
                current.artist ??
                trackSourceName(l10n, current.source),
            key: const ValueKey('now-subtitle'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (current.isLive)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(l10n.musicLive),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (current.isLive)
                Consumer(
                  builder: (context, ref, _) {
                    final fav = ref.watch(
                      radioFavoritesProvider.select((l) => l.contains(current)),
                    );
                    return IconButton(
                      key: const ValueKey('now-fav'),
                      tooltip: fav
                          ? l10n.musicFavoriteRemove
                          : l10n.musicFavoriteAdd,
                      icon: Icon(
                        fav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: fav ? Colors.amber.shade700 : null,
                      ),
                      onPressed: () => ref
                          .read(radioFavoritesProvider.notifier)
                          .toggle(current),
                    );
                  },
                ),
              if (current.permalink != null)
                TextButton.icon(
                  onPressed: () => launchUrl(
                    current.permalink!,
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    current.source == TrackSource.audius
                        ? l10n.musicViaAudius
                        : trackSourceName(l10n, current.source),
                  ),
                ),
            ],
          ),
          if (state.status == PlayerStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.musicError,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!current.isLive) ...[
            Slider(
              key: const ValueKey('now-seek'),
              value: duration == null || duration == Duration.zero
                  ? 0
                  : (state.position.inMilliseconds / duration.inMilliseconds)
                        .clamp(0.0, 1.0),
              onChanged: duration == null
                  ? null
                  : (v) => controller.seek(duration * v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatTrackTime(state.position),
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  duration == null ? '--:--' : formatTrackTime(duration),
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('now-previous'),
                tooltip: l10n.musicPrevious,
                iconSize: 40,
                constraints: BoxConstraints(
                  minWidth: big * 0.8,
                  minHeight: big * 0.8,
                ),
                onPressed: controller.previous,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                key: const ValueKey('now-toggle'),
                tooltip: playing ? l10n.musicPause : l10n.musicPlay,
                iconSize: 44,
                constraints: BoxConstraints(minWidth: big, minHeight: big),
                onPressed: controller.toggle,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                key: const ValueKey('now-next'),
                tooltip: l10n.musicNext,
                iconSize: 40,
                constraints: BoxConstraints(
                  minWidth: big * 0.8,
                  minHeight: big * 0.8,
                ),
                onPressed: state.hasNext ? controller.next : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.volume_down_rounded),
              Expanded(
                child: Slider(
                  key: const ValueKey('now-volume'),
                  value: state.volume,
                  onChanged: controller.setVolume,
                  label: l10n.musicVolume,
                ),
              ),
              const Icon(Icons.volume_up_rounded),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              TextButton.icon(
                key: const ValueKey('now-eq'),
                onPressed: () => showEqualizerSheet(context),
                icon: const Icon(Icons.equalizer_rounded),
                label: Text(l10n.musicEqualizer),
              ),
              TextButton.icon(
                key: const ValueKey('now-stop'),
                onPressed: () {
                  controller.stop();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded),
                label: Text(l10n.musicStop),
              ),
            ],
          ),
          if (state.queue.length > 1) ...[
            const Divider(height: 24),
            Text(l10n.musicQueue, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (var i = 0; i < state.queue.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: TrackArt(track: state.queue[i], size: 40),
                title: Text(
                  state.queue[i].title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: i == state.index
                      ? TextStyle(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                onTap: () =>
                    controller.playTrack(state.queue[i], queue: state.queue),
              ),
          ],
        ],
      ),
    );
  }
}
