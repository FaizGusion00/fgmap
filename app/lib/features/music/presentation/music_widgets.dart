import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/track.dart';

/// Nama sumber untuk atribusi.
String trackSourceName(AppLocalizations l10n, TrackSource s) => switch (s) {
  TrackSource.audius => l10n.musicSourceAudius,
  TrackSource.radio => l10n.musicSourceRadio,
  TrackSource.local => l10n.musicSourceLocal,
  TrackSource.appleMusic => l10n.musicSourceAppleMusic,
};

IconData trackSourceIcon(TrackSource s) => switch (s) {
  TrackSource.audius => Icons.music_note_rounded,
  TrackSource.radio => Icons.radio_rounded,
  TrackSource.local => Icons.folder_rounded,
  TrackSource.appleMusic => Icons.library_music_rounded,
};

/// Karya seni lagu / favicon stesen dengan sandaran ikon sumber.
class TrackArt extends StatelessWidget {
  const TrackArt({super.key, required this.track, this.size = 56});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: size,
      height: size,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        trackSourceIcon(track.source),
        size: size * 0.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final uri = track.artworkUri;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: uri == null
          ? fallback
          : Image.network(
              uri.toString(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// "m:ss" / "h:mm:ss".
String formatTrackTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
