import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/device_music.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';
import '../presentation/device_music_controller.dart';
import '../presentation/player_controller.dart';
import 'curated_stations.dart';
import 'local_library.dart';
import 'music_audio_handler.dart';
import 'radio_favorites.dart';

/// Senarai muzik FGMaps dalam bahagian media Android Auto: radio kegemaran, stesen Malaysia, lagu dalam
/// telefon (jika kebenaran sudah diberi di app) dan lagu yang diimport. Hanya kandungan yang sudah ada
/// dalam app; tiada carian dalam talian dari kereta.
///
/// Id media: `folder` untuk folder, `folder/kunciLagu` untuk lagu. Memilih lagu memainkannya bersama
/// lagu lain dalam folder yang sama sebagai baris gilir, melalui [PlayerController] (mini pemain di
/// telefon kekal sama).
class CarMediaLibrary implements MediaBrowseSource {
  CarMediaLibrary(this._ref, this._player);

  final Ref _ref;
  final PlayerController _player;

  static const favorites = 'favorites';
  static const stations = 'stations';
  static const device = 'device';
  static const imported = 'imported';

  /// Had lagu setiap folder: hos kereta sendiri hanya memaparkan sebahagian ketika memandu.
  static const maxItems = 200;

  AppLocalizations get _l10n => lookupAppLocalizations(
    Locale(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ms'
          ? 'ms'
          : 'en',
    ),
  );

  @override
  Future<List<MediaItem>> children(String parentMediaId) async {
    if (parentMediaId == AudioService.browsableRootId) return _folders();
    if (parentMediaId == AudioService.recentRootId) {
      // "Sambung semula" Android: stesen/lagu terakhir di baris gilir pemain.
      final current = _ref.read(playerControllerProvider).current;
      return current == null ? const [] : [_item('recent', current)];
    }
    final tracks = await _tracks(parentMediaId);
    return [for (final t in tracks.take(maxItems)) _item(parentMediaId, t)];
  }

  Future<List<MediaItem>> _folders() async {
    final en = _l10n.localeName != 'ms';
    final folders = <MediaItem>[];
    void add(String id, String title) =>
        folders.add(MediaItem(id: id, title: title, playable: false));
    if (_ref.read(radioFavoritesProvider).isNotEmpty) {
      add(favorites, en ? 'Favourite radio' : 'Radio kegemaran');
    }
    add(stations, en ? 'Malaysian radio' : 'Radio Malaysia');
    if (await _deviceAllowed()) {
      add(device, en ? 'Phone music' : 'Lagu telefon');
    }
    final importedSongs = await _safe(
      () => _ref.read(localLibraryProvider).list(),
    );
    if (importedSongs.isNotEmpty) {
      add(imported, en ? 'Imported songs' : 'Lagu diimport');
    }
    return folders;
  }

  Future<bool> _deviceAllowed() async {
    try {
      return await _ref.read(deviceMusicRepositoryProvider).access() ==
          DeviceMusicAccess.authorized;
    } on Object {
      return false;
    }
  }

  Future<List<Track>> _tracks(String folder) async => switch (folder) {
    favorites => _ref.read(radioFavoritesProvider),
    stations => [
      for (final s in curatedStations)
        if (s.region == RadioRegion.malaysia) s.toTrack(),
    ],
    device =>
      await _deviceAllowed()
          ? await _safe(() => _ref.read(deviceMusicRepositoryProvider).songs())
          : const <Track>[],
    imported => await _safe(() => _ref.read(localLibraryProvider).list()),
    'recent' => [?_ref.read(playerControllerProvider).current],
    _ => const <Track>[],
  };

  static Future<List<Track>> _safe(Future<List<Track>> Function() load) async {
    try {
      return await load();
    } on Object {
      return const [];
    }
  }

  MediaItem _item(String folder, Track t) => MediaItem(
    id: '$folder/${t.key}',
    title: t.title,
    artist: t.artist,
    artUri: t.artworkUri,
    duration: t.duration,
    isLive: t.isLive,
    playable: true,
  );

  @override
  Future<void> playFromMediaId(String mediaId) async {
    final slash = mediaId.indexOf('/');
    if (slash <= 0) return;
    final folder = mediaId.substring(0, slash);
    final key = mediaId.substring(slash + 1);
    final tracks = await _tracks(folder);
    final track = tracks.where((t) => t.key == key).firstOrNull;
    if (track == null) return;
    await _player.playTrack(track, queue: tracks);
  }
}
