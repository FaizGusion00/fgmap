import 'package:fgmap/core/audio/audio_coordinator.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/music/data/audius_repository.dart';
import 'package:fgmap/features/music/data/device_music_channel.dart';
import 'package:fgmap/features/music/data/external_music_launcher.dart';
import 'package:fgmap/features/music/data/local_library.dart';
import 'package:fgmap/features/music/data/radio_browser_repository.dart';
import 'package:fgmap/features/music/domain/device_music.dart';
import 'package:fgmap/features/music/domain/external_music.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:fgmap/features/music/presentation/device_music_controller.dart';
import 'package:fgmap/features/music/presentation/music_search_controller.dart';
import 'package:fgmap/features/music/presentation/music_sheet.dart';
import 'package:fgmap/features/music/presentation/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';
import 'music_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pautan carian ke app luar', () {
    test('Spotify: HTTPS, teks carian dikodkan dalam satu segmen', () {
      expect(
        spotifySearchUri('siti nurhaliza').toString(),
        'https://open.spotify.com/search/siti%20nurhaliza',
      );
      final slash = spotifySearchUri('AC/DC');
      expect(slash.pathSegments, ['search', 'AC/DC']);
      expect(slash.toString(), contains('AC%2FDC'));
      expect(
        spotifySearchUri('   ').toString(),
        'https://open.spotify.com/search',
      );
    });

    test('YouTube Music: pertanyaan dalam parameter q', () {
      final u = youtubeMusicSearchUri(' babymonster & friends ');
      expect(u.scheme, 'https');
      expect(u.host, 'music.youtube.com');
      expect(u.path, '/search');
      expect(u.queryParameters['q'], 'babymonster & friends');
      expect(
        youtubeMusicSearchUri('').toString(),
        'https://music.youtube.com/',
      );
    });
  });

  group('muzik pada telefon: penghuraian dan saluran', () {
    test('hanya skema boleh-main; entri rosak dilangkau', () {
      final tracks = parseDeviceSongs([
        {
          'id': '1',
          'title': ' Cindai ',
          'artist': 'Siti Nurhaliza',
          'durationMs': 235000,
          'uri': 'content://media/external/audio/media/1',
        },
        {'id': '2', 'title': 'iOS', 'uri': 'ipod-library://item/item.m4a?id=2'},
        {'id': '3', 'title': 'Fail', 'uri': 'file:///sdcard/Music/a.mp3'},
        {'id': '4', 'title': 'Rangkaian', 'uri': 'https://example.test/a.mp3'},
        {'id': '5', 'title': 'Tiada uri'},
        {'id': '', 'title': 'Tiada id', 'uri': 'content://x/1'},
        {'id': '6', 'title': '  ', 'uri': 'content://x/6'},
        'bukan peta',
      ]);
      expect(tracks.map((t) => t.id), ['1', '2', '3']);
      final first = tracks.first;
      expect(first.source, TrackSource.device);
      expect(first.title, 'Cindai');
      expect(first.artist, 'Siti Nurhaliza');
      expect(first.duration, const Duration(milliseconds: 235000));
      expect(first.streamUri.scheme, 'content');
      expect(tracks[1].artist, isNull);
      expect(parseDeviceSongs(null), isEmpty);
    });

    group('ChannelDeviceMusicRepository', () {
      late MethodChannel channel;
      late List<String> calls;
      late DateTime clock;
      Object? Function(MethodCall)? handler;

      setUp(() {
        channel = const MethodChannel('fgmaps/device_music.test');
        calls = [];
        clock = DateTime(2026, 10, 31, 12);
        handler = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call.method);
              return handler?.call(call);
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
      });

      ChannelDeviceMusicRepository repo() => ChannelDeviceMusicRepository(
        channel: channel,
        cacheFor: const Duration(seconds: 60),
        now: () => clock,
      );

      test('access dan request; ralat natif tidak melontar', () async {
        handler = (c) => c.method == 'access' ? 'denied' : 'authorized';
        final r = repo();
        expect(await r.access(), DeviceMusicAccess.denied);
        expect(await r.request(), DeviceMusicAccess.authorized);
        handler = (_) => throw PlatformException(code: 'x');
        expect(await r.access(), DeviceMusicAccess.notDetermined);
        expect(await r.request(), DeviceMusicAccess.notDetermined);
      });

      test(
        'senarai disimpan 60 saat; refresh dan request mengosongkannya',
        () async {
          handler = (_) => [
            {'id': '1', 'title': 'A', 'uri': 'content://m/1'},
          ];
          final r = repo();
          expect(await r.songs(), hasLength(1));
          expect(await r.songs(), hasLength(1));
          expect(
            calls.where((c) => c == 'list'),
            hasLength(1),
            reason: 'kali kedua dari ingatan',
          );

          clock = clock.add(const Duration(seconds: 61));
          await r.songs();
          expect(
            calls.where((c) => c == 'list'),
            hasLength(2),
            reason: 'cache tamat',
          );

          await r.songs(refresh: true);
          expect(calls.where((c) => c == 'list'), hasLength(3));

          handler = (c) => c.method == 'request'
              ? 'authorized'
              : [
                  {'id': '1', 'title': 'A', 'uri': 'content://m/1'},
                ];
          await r.request();
          await r.songs();
          expect(
            calls.where((c) => c == 'list'),
            hasLength(4),
            reason: 'kebenaran baharu = baca semula',
          );
        },
      );
    });
  });

  group('tab Fail saya dengan lagu telefon', () {
    late SharedPreferences prefs;
    late FakeLocalLibrary local;
    late FakeDeviceMusicRepository device;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      local = FakeLocalLibrary(
        tracks: [track('l1', source: TrackSource.local, title: 'Fail Import')],
      );
      device = FakeDeviceMusicRepository(
        current: DeviceMusicAccess.authorized,
        tracks: [
          deviceTrack('d1', title: 'Cindai'),
          deviceTrack('d2', title: 'Sejati'),
        ],
      );
    });

    Future<ProviderContainer> make() async {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localLibraryProvider.overrideWithValue(local),
          deviceMusicRepositoryProvider.overrideWithValue(device),
          audiusRepositoryProvider.overrideWithValue(FakeAudiusRepository()),
          radioRepositoryProvider.overrideWithValue(FakeRadioRepository()),
        ],
      );
      addTearDown(c.dispose);
      c.read(deviceMusicAccessProvider);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test(
      'dibenarkan: fail import dahulu, kemudian lagu telefon; boleh ditapis',
      () async {
        final c = await make();
        final ctrl = c.read(musicSearchProvider.notifier);
        await ctrl.setTab(MusicTab.local);
        expect(c.read(musicSearchProvider).results.map((t) => t.id), [
          'l1',
          'd1',
          'd2',
        ]);
        expect(
          device.refreshFlags.last,
          isTrue,
          reason: 'membuka tab membaca semula',
        );

        ctrl.setQuery('sejati');
        await Future<void>.delayed(Duration.zero);
        expect(c.read(musicSearchProvider).results.map((t) => t.id), ['d2']);
        expect(
          device.refreshFlags.last,
          isFalse,
          reason: 'menaip guna ingatan',
        );
      },
    );

    test('belum dibenarkan: lagu telefon tidak disentuh', () async {
      device.current = DeviceMusicAccess.notDetermined;
      final c = await make();
      await c.read(musicSearchProvider.notifier).setTab(MusicTab.local);
      expect(c.read(musicSearchProvider).results.map((t) => t.id), ['l1']);
      expect(device.refreshFlags, isEmpty);
    });

    test('kebenaran diberi semasa tab terbuka: senarai dimuat terus', () async {
      device.current = DeviceMusicAccess.notDetermined;
      final c = await make();
      await c.read(musicSearchProvider.notifier).setTab(MusicTab.local);
      expect(c.read(musicSearchProvider).results, hasLength(1));
      await c.read(deviceMusicAccessProvider.notifier).connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(device.requestCalls, 1);
      expect(c.read(musicSearchProvider).results.map((t) => t.id), [
        'l1',
        'd1',
        'd2',
      ]);
    });

    test('bacaan telefon gagal: fail import tetap dipaparkan', () async {
      device.error = StateError('MediaStore rosak');
      final c = await make();
      await c.read(musicSearchProvider.notifier).setTab(MusicTab.local);
      final s = c.read(musicSearchProvider);
      expect(s.status, MusicSearchStatus.ready);
      expect(s.results.map((t) => t.id), ['l1']);
    });

    test('platform tanpa jambatan: status unsupported', () async {
      device.isSupported = false;
      final c = await make();
      expect(c.read(deviceMusicAccessProvider), DeviceMusicAccess.unsupported);
    });
  });

  group('baris gilir bertetingkap', () {
    late FakeMusicEngine engine;
    late ProviderContainer c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      engine = FakeMusicEngine();
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          musicEngineProvider.overrideWithValue(engine),
          radioRepositoryProvider.overrideWithValue(FakeRadioRepository()),
          audioCoordinatorProvider.overrideWithValue(AudioCoordinator()),
          audioServiceStarterProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
    });

    final big = [for (var i = 0; i < 1000; i++) deviceTrack('d$i')];

    test(
      'pustaka besar: sehingga 300 lagu, lagu diketik kekal sebagai semasa',
      () async {
        final ctrl = c.read(playerControllerProvider.notifier);
        await ctrl.playTrack(big[500], queue: big);
        final s = c.read(playerControllerProvider);
        expect(s.queue, hasLength(PlayerController.maxQueue));
        expect(s.current, big[500]);
        expect(s.queue.first, big[480], reason: '20 lagu sebelum yang diketik');
        expect(engine.calls, contains('setQueue:300:20'));
      },
    );

    test('di hujung senarai tetingkap tidak melampaui sempadan', () async {
      final ctrl = c.read(playerControllerProvider.notifier);
      await ctrl.playTrack(big[999], queue: big);
      var s = c.read(playerControllerProvider);
      expect(s.queue, hasLength(300));
      expect(s.queue.last, big[999]);
      expect(s.current, big[999]);

      await ctrl.playTrack(big[0], queue: big);
      s = c.read(playerControllerProvider);
      expect(s.queue.first, big[0]);
      expect(s.index, 0);
    });

    test('baris gilir kecil tidak diubah', () async {
      final q = [for (var i = 0; i < 5; i++) deviceTrack('s$i')];
      await c.read(playerControllerProvider.notifier).playTrack(q[3], queue: q);
      expect(c.read(playerControllerProvider).queue, q);
      expect(c.read(playerControllerProvider).index, 3);
    });
  });

  group('widget', () {
    late SharedPreferences prefs;
    late FakeDeviceMusicRepository device;
    late List<Uri> opened;
    var launchOk = true;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      device = FakeDeviceMusicRepository(
        tracks: [deviceTrack('d1', title: 'Cindai')],
      );
      opened = [];
      launchOk = true;
    });

    Future<ProviderContainer> pump(WidgetTester tester) async {
      usePhoneSurface(tester);
      reduceMotion(tester);
      await pumpApp(
        tester,
        const Scaffold(body: MusicSheet()),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          musicEngineProvider.overrideWithValue(FakeMusicEngine()),
          audiusRepositoryProvider.overrideWithValue(
            FakeAudiusRepository(trendingResults: [track('t1')]),
          ),
          radioRepositoryProvider.overrideWithValue(FakeRadioRepository()),
          localLibraryProvider.overrideWithValue(
            FakeLocalLibrary(
              tracks: [
                track('l1', source: TrackSource.local, title: 'Fail Import'),
              ],
            ),
          ),
          deviceMusicRepositoryProvider.overrideWithValue(device),
          externalMusicLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return launchOk;
          }),
          audioCoordinatorProvider.overrideWithValue(AudioCoordinator()),
          audioServiceStarterProvider.overrideWithValue(null),
        ],
      );
      await settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    }

    testWidgets('Spotify dan YouTube Music membuka carian yang ditaip', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(const ValueKey('music-search')),
        'babymonster',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('music-open-spotify')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('music-open-ytmusic')));
      await tester.pump();
      expect(opened.map((u) => u.toString()), [
        'https://open.spotify.com/search/babymonster',
        'https://music.youtube.com/search?q=babymonster',
      ]);
    });

    testWidgets('tanpa carian: membuka laman utama app', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('music-open-spotify')));
      await tester.pump();
      expect(opened.single.toString(), 'https://open.spotify.com/search');
    });

    testWidgets('gagal dibuka: mesej, bukan senyap', (tester) async {
      launchOk = false;
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('music-open-ytmusic')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'tab Fail saya: kad kebenaran, kemudian lagu telefon tanpa butang padam',
      (tester) async {
        final container = await pump(tester);
        await container
            .read(musicSearchProvider.notifier)
            .setTab(MusicTab.local);
        await settle(tester);
        expect(find.byKey(const ValueKey('device-music-card')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('music-external')),
          findsNothing,
          reason: 'hanya di tab Lagu',
        );

        await tester.tap(find.byKey(const ValueKey('device-music-allow')));
        await settle(tester);
        expect(device.requestCalls, 1);
        expect(find.byKey(const ValueKey('device-music-card')), findsNothing);
        expect(find.text('Cindai'), findsOneWidget);
        expect(find.text('Fail Import'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('music-result-device:d1')),
            matching: find.byIcon(Icons.delete_outline_rounded),
          ),
          findsNothing,
          reason: 'lagu telefon tidak boleh dipadam oleh app',
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('music-result-local:l1')),
            matching: find.byIcon(Icons.delete_outline_rounded),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('ditolak: mesej Tetapan tanpa butang; unsupported: tiada kad', (
      tester,
    ) async {
      device.current = DeviceMusicAccess.denied;
      final container = await pump(tester);
      await container.read(musicSearchProvider.notifier).setTab(MusicTab.local);
      await settle(tester);
      expect(find.byKey(const ValueKey('device-music-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('device-music-allow')), findsNothing);
      expect(
        device.requestCalls,
        0,
        reason: 'tidak pernah meminta tanpa ketikan',
      );
    });

    testWidgets('platform tanpa jambatan: kad tidak dipaparkan', (
      tester,
    ) async {
      device.isSupported = false;
      final container = await pump(tester);
      await container.read(musicSearchProvider.notifier).setTab(MusicTab.local);
      await settle(tester);
      expect(find.byKey(const ValueKey('device-music-card')), findsNothing);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
