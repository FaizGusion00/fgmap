import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/player_state.dart';
import 'music_widgets.dart';
import 'now_playing_page.dart';
import 'player_controller.dart';

/// Bar pemain kecil di atas kawalan bawah skrin utama: karya seni, tajuk, main/jeda, seterusnya,
/// tutup. Ketik membuka pemain penuh. Dalam Mod mudah lebih tinggi dan butang lebih besar.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final current = ref.watch(
      playerControllerProvider.select((s) => s.current),
    );
    final status = ref.watch(playerControllerProvider.select((s) => s.status));
    final ducked = ref.watch(playerControllerProvider.select((s) => s.ducked));
    final hasNext = ref.watch(
      playerControllerProvider.select((s) => s.hasNext),
    );
    if (current == null) return const SizedBox.shrink();
    final controller = ref.read(playerControllerProvider.notifier);
    final playing = status == PlayerStatus.playing;
    final busy =
        status == PlayerStatus.loading || status == PlayerStatus.buffering;
    final iconSize = easy ? 34.0 : 28.0;

    return Material(
      key: const ValueKey('mini-player'),
      color: theme.colorScheme.surface,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showNowPlaying(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: [
              TrackArt(track: current, size: easy ? 56 : 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (easy
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.titleSmall)
                              ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      status == PlayerStatus.error
                          ? l10n.musicError
                          : ducked
                          ? l10n.musicDucked
                          : (current.artist ??
                                trackSourceName(l10n, current.source)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status == PlayerStatus.error
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  key: const ValueKey('mini-toggle'),
                  tooltip: playing ? l10n.musicPause : l10n.musicPlay,
                  iconSize: iconSize,
                  onPressed: controller.toggle,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              if (hasNext)
                IconButton(
                  key: const ValueKey('mini-next'),
                  tooltip: l10n.musicNext,
                  iconSize: iconSize,
                  onPressed: controller.next,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              IconButton(
                key: const ValueKey('mini-close'),
                tooltip: l10n.musicStop,
                iconSize: easy ? 26 : 22,
                onPressed: controller.stop,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
