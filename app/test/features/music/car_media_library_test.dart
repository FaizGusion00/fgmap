import 'package:audio_service/audio_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/music/data/car_media_library.dart';
import 'package:fgmap/features/music/data/local_library.dart';
import 'package:fgmap/features/music/data/radio_favorites.dart';
import 'package:fgmap/features/music/domain/device_music.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:fgmap/features/music/presentation/device_music_controller.dart';
import 'package:fgmap/features/music/presentation/player_controller.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_test_support.dart';

/// Bahagian media Android Auto: folder dan lagu yang sudah ada dalam app, main melalui pemain app.
void main() {
  late FakeMusicEngine engine;
  late FakeDeviceMusicRepository device;
  late ProviderContainer container;

  Future<CarMediaLibrary> setUp0({
    DeviceMusicAccess access = DeviceMusicAccess.authorized,
    List<Track> imported = const [],
  }) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = const Locale('ms');
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    engine = FakeMusicEngine();
    device = FakeDeviceMusicRepository(
      current: access,
      tracks: [deviceTrack('1'), deviceTrack('2'), deviceTrack('3')],
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        musicEngineProvider.overrideWithValue(engine),
        audioServiceStarterProvider.overrideWithValue(null),
        deviceMusicRepositoryProvider.overrideWithValue(device),
        localLibraryProvider.overrideWithValue(
          FakeLocalLibrary(tracks: imported),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(
      Provider(
        (ref) =>
            CarMediaLibrary(ref, ref.read(playerControllerProvider.notifier)),
      ),
    );
  }

  test(
    'folder akar: radio Malaysia dan lagu telefon (bila dibenarkan)',
    () async {
      final library = await setUp0();
      final root = await library.children(AudioService.browsableRootId);
      expect(root.map((m) => m.id), ['stations', 'device']);
      expect(root.first.title, 'Radio Malaysia');
      expect(root.every((m) => m.playable == false), isTrue);
    },
  );

  test('tanpa kebenaran muzik telefon: folder itu tidak dipaparkan', () async {
    final library = await setUp0(access: DeviceMusicAccess.denied);
    final root = await library.children(AudioService.browsableRootId);
    expect(root.map((m) => m.id), isNot(contains('device')));
  });

  test('kegemaran radio dan lagu diimport muncul sebagai folder', () async {
    final library = await setUp0(imported: [track('a')]);
    await container
        .read(radioFavoritesProvider.notifier)
        .toggle(track('r1', source: TrackSource.radio));
    final root = await library.children(AudioService.browsableRootId);
    expect(root.map((m) => m.id), [
      'favorites',
      'stations',
      'device',
      'imported',
    ]);
  });

  test('stesen Malaysia boleh dimain dan merupakan siaran langsung', () async {
    final library = await setUp0();
    final stations = await library.children('stations');
    expect(stations, isNotEmpty);
    expect(stations.every((m) => m.playable == true), isTrue);
    expect(stations.first.isLive, isTrue);
  });

  test(
    'memilih lagu telefon memainkan folder itu sebagai baris gilir',
    () async {
      final library = await setUp0();
      final songs = await library.children('device');
      expect(songs, hasLength(3));
      await library.playFromMediaId(songs[1].id);
      expect(engine.calls, contains('setQueue:3:1'));
      final state = container.read(playerControllerProvider);
      expect(state.current?.id, '2');
    },
  );

  test('id tidak dikenali: tiada apa dimain, tidak ranap', () async {
    final library = await setUp0();
    await library.playFromMediaId('bukan/apa-apa');
    await library.playFromMediaId('tiada-garis');
    expect(engine.calls.where((c) => c.startsWith('setQueue')), isEmpty);
    expect(await library.children('bukan-folder'), isEmpty);
  });
}
