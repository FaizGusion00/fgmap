import 'package:fgmap/core/audio/audio_coordinator.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/music/data/apple_music_channel.dart';
import 'package:fgmap/features/music/data/audius_repository.dart';
import 'package:fgmap/features/music/data/radio_browser_repository.dart';
import 'package:fgmap/features/music/data/routing_music_engine.dart';
import 'package:fgmap/features/music/domain/apple_music.dart';
import 'package:fgmap/features/music/domain/player_state.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:fgmap/features/music/presentation/apple_music_controller.dart';
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

const _ready = AppleMusicStatus(
  access: AppleMusicAccess.authorized,
  canPlay: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('penghuraian jambatan natif', () {
    test('lagu: HTTPS sahaja untuk gambar, entri rosak dilangkau', () {
      final tracks = parseAppleSongs([
        {
          'id': '1',
          'title': ' Cindai ',
          'artist': 'Siti Nurhaliza',
          'artwork': 'https://is1.mzstatic.com/a.jpg',
          'durationMs': 235000,
        },
        {'id': '2', 'title': 'Tiada Seni', 'artwork': 'http://x.test/a.jpg'},
        {'id': '', 'title': 'Tiada id'},
        {'id': '3', 'title': '  '},
        'bukan peta',
      ]);
      expect(tracks.map((t) => t.id), ['1', '2']);
      final first = tracks.first;
      expect(first.source, TrackSource.appleMusic);
      expect(first.title, 'Cindai');
      expect(first.duration, const Duration(milliseconds: 235000));
      expect(first.artworkUri.toString(), 'https://is1.mzstatic.com/a.jpg');
      expect(first.streamUri.scheme, 'applemusic');
      expect(tracks.last.artworkUri, isNull, reason: 'http ditolak (ADR 0010)');
      expect(parseAppleSongs(null), isEmpty);
    });

    test('status: nilai tidak dikenali jatuh ke notDetermined', () {
      final s = parseAppleStatus({
        'authorization': 'authorized',
        'canPlay': true,
        'canBecomeSubscriber': false,
      });
      expect(s.ready, isTrue);
      expect(
        parseAppleStatus({'authorization': 'pelik'}).access,
        AppleMusicAccess.notDetermined,
      );
      expect(parseAppleStatus(null).ready, isFalse);
      expect(AppleMusicStatus.unsupported.supported, isFalse);
      expect(
        const AppleMusicStatus(access: AppleMusicAccess.authorized).ready,
        isFalse,
        reason: 'dibenarkan tetapi bukan pelanggan',
      );
    });

    test('gambar pemain: id dipetakan ke indeks baris gilir', () {
      final queue = [appleTrack('a'), appleTrack('b'), appleTrack('c')];
      final s = parseApplePlayer(
        {
          'status': 'playing',
          'positionMs': 1500,
          'id': 'c',
          'durationMs': 200000,
        },
        queue: queue,
        fallbackIndex: 0,
      )!;
      expect(s.status, PlayerStatus.playing);
      expect(s.index, 2);
      expect(s.position, const Duration(milliseconds: 1500));
      expect(s.duration, const Duration(milliseconds: 200000));

      final unknown = parseApplePlayer(
        {'status': 'loading', 'id': 'tiada'},
        queue: queue,
        fallbackIndex: 1,
      )!;
      expect(unknown.index, 1);
      expect(unknown.status, PlayerStatus.loading);
      expect(
        unknown.duration,
        queue[1].duration,
        reason: 'tempoh dari baris gilir',
      );
      expect(
        parseApplePlayer(
          {'status': 'idle'},
          queue: queue,
          fallbackIndex: 0,
        )!.status,
        PlayerStatus.idle,
      );
      expect(parseApplePlayer('x', queue: queue, fallbackIndex: 0), isNull);
    });
  });

  group('saluran natif (palsu)', () {
    late MethodChannel channel;
    late List<MethodCall> calls;
    Object? Function(MethodCall)? handler;

    setUp(() {
      channel = const MethodChannel('fgmaps/apple_music.test');
      calls = [];
      handler = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return handler?.call(call);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    });

    test('repositori: status, authorize dan search', () async {
      final repo = ChannelAppleMusicRepository(channel: channel);
      handler = (call) => switch (call.method) {
        'status' => {'authorization': 'authorized', 'canPlay': true},
        'authorize' => {'authorization': 'denied', 'canPlay': false},
        'search' => [
          {'id': '9', 'title': 'Lagu'},
        ],
        _ => null,
      };
      expect((await repo.status()).ready, isTrue);
      expect((await repo.authorize()).access, AppleMusicAccess.denied);
      expect((await repo.search('  siti  ')).single.id, '9');
      expect(calls.last.arguments, {'term': 'siti', 'limit': 25});
      calls.clear();
      expect(await repo.search('   '), isEmpty);
      expect(calls, isEmpty, reason: 'pertanyaan kosong tidak ke natif');
    });

    test('repositori: ralat natif pada status tidak melontar', () async {
      final repo = ChannelAppleMusicRepository(channel: channel);
      handler = (_) => throw PlatformException(code: 'x', message: 'gagal');
      expect((await repo.status()).ready, isFalse);
      expect((await repo.authorize()).ready, isFalse);
      await expectLater(repo.search('a'), throwsA(isA<PlatformException>()));
    });

    test('enjin: baris gilir, lompatan indeks dan seek', () async {
      final engine = AppleMusicEngine(
        channel: channel,
        events: const EventChannel('fgmaps/apple_music.test/events'),
      );
      addTearDown(engine.dispose);
      handler = (_) => null;
      final queue = [
        appleTrack('a'),
        appleTrack('b'),
        appleTrack('c'),
        appleTrack('d'),
      ];
      await engine.setQueue(queue, 1);
      expect(calls.last.method, 'setQueue');
      expect(calls.last.arguments, {
        'ids': ['a', 'b', 'c', 'd'],
        'startIndex': 1,
      });
      await engine.seekToIndex(2);
      expect(calls.last.method, 'next');
      await engine.seekToIndex(1);
      expect(calls.last.method, 'previous');
      await engine.seekToIndex(3);
      expect(
        calls.last.method,
        'setQueue',
        reason: 'lompatan jauh pasang baris gilir semula',
      );
      expect(calls.last.arguments, containsPair('startIndex', 3));
      await engine.seek(const Duration(seconds: 12));
      expect(calls.last.arguments, {'positionMs': 12000});
      await engine.setVolume(0.3);
      expect(engine.equalizerSupported, isFalse);
      await engine.stop();
      expect(calls.last.method, 'stop');
    });
  });

  group('RoutingMusicEngine', () {
    late FakeMusicEngine just;
    late FakeMusicEngine apple;
    late RoutingMusicEngine router;

    setUp(() {
      just = FakeMusicEngine();
      apple = FakeMusicEngine();
      router = RoutingMusicEngine(justAudio: just, apple: apple);
      addTearDown(router.dispose);
    });

    test(
      'memilih enjin ikut sumber dan menghentikan yang sebelumnya',
      () async {
        await router.setQueue([track('a')], 0);
        expect(just.calls, ['setQueue:1:0']);
        expect(apple.calls, isEmpty);

        await router.setQueue([appleTrack('x')], 0);
        expect(just.calls.last, 'stop');
        expect(apple.calls, ['setQueue:1:0']);

        await router.play();
        expect(apple.calls.last, 'play');
        expect(just.calls.last, 'stop', reason: 'just_audio tidak disentuh');

        await router.setQueue([track('b', source: TrackSource.radio)], 0);
        expect(apple.calls.last, 'stop');
        await router.pause();
        expect(just.calls.last, 'pause');
      },
    );

    test('gambar enjin yang tidak aktif dibuang', () async {
      final seen = <EngineSnapshot>[];
      final sub = router.snapshots.listen(seen.add);
      addTearDown(sub.cancel);
      await router.setQueue([appleTrack('x')], 0);
      just.emit(PlayerStatus.playing);
      apple.emit(PlayerStatus.paused);
      await Future<void>.delayed(Duration.zero);
      expect(seen.map((s) => s.status), [PlayerStatus.paused]);
    });

    test(
      'penyama kekal pada just_audio; tanpa MusicKit lagu Apple ditolak',
      () async {
        await router.setEqualizer(
          enabled: true,
          gainsDb: const [1, 2, 3, 4, 5],
        );
        expect(just.eqEnabled, isTrue);
        expect(apple.eqEnabled, isNull);

        final noApple = RoutingMusicEngine(justAudio: FakeMusicEngine());
        addTearDown(noApple.dispose);
        await expectLater(
          noApple.setQueue([appleTrack('x')], 0),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('PlayerController dengan Apple Music', () {
    late SharedPreferences prefs;
    late FakeMusicEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      engine = FakeMusicEngine();
    });

    ProviderContainer make() {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          musicEngineProvider.overrideWithValue(engine),
          radioRepositoryProvider.overrideWithValue(FakeRadioRepository()),
          audioCoordinatorProvider.overrideWithValue(AudioCoordinator()),
          audioServiceStarterProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('baris gilir bercampur: hanya lagu enjin yang sama kekal', () async {
      final c = make();
      final mixed = [
        appleTrack('a1'),
        track('au1'),
        appleTrack('a2'),
        track('au2'),
      ];
      await c
          .read(playerControllerProvider.notifier)
          .playTrack(mixed[2], queue: mixed);
      final s = c.read(playerControllerProvider);
      expect(s.queue.map((t) => t.id), ['a1', 'a2']);
      expect(s.current!.id, 'a2');
      expect(engine.calls, contains('setQueue:2:1'));

      await c
          .read(playerControllerProvider.notifier)
          .playTrack(mixed[1], queue: mixed);
      expect(c.read(playerControllerProvider).queue.map((t) => t.id), [
        'au1',
        'au2',
      ]);
    });

    test(
      'tiada kawalan kelantangan: suara navigasi menjeda, bukan memperlahankan',
      () async {
        final c = make();
        final ctrl = c.read(playerControllerProvider.notifier);
        await ctrl.playTrack(appleTrack('a'));
        engine.emit(PlayerStatus.playing);
        await Future<void>.delayed(Duration.zero);
        expect(engine.calls.where((e) => e.startsWith('volume')), isEmpty);

        await ctrl.onSpeechStart();
        expect(
          engine.calls.last,
          'pause',
          reason: 'mod duck lalai tetap menjeda',
        );
        expect(c.read(playerControllerProvider).ducked, isTrue);
        await ctrl.onSpeechEnd();
        expect(engine.calls.last, 'play');
        expect(engine.calls.where((e) => e.startsWith('volume')), isEmpty);

        await ctrl.setVolume(0.4);
        expect(engine.calls.where((e) => e.startsWith('volume')), isEmpty);
      },
    );

    test('lagu bukan Apple masih memperlahankan suara seperti biasa', () async {
      final c = make();
      final ctrl = c.read(playerControllerProvider.notifier);
      await ctrl.playTrack(track('a'));
      engine.emit(PlayerStatus.playing);
      await Future<void>.delayed(Duration.zero);
      await ctrl.onSpeechStart();
      expect(engine.calls.last, startsWith('volume:'));
    });
  });

  group('carian Lagu dengan Apple Music', () {
    late FakeAudiusRepository audius;
    late FakeAppleMusicRepository apple;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      audius = FakeAudiusRepository(results: [track('au1'), track('au2')]);
      apple = FakeAppleMusicRepository(
        current: _ready,
        results: [appleTrack('ap1'), appleTrack('ap2')],
      );
    });

    Future<ProviderContainer> make() async {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audiusRepositoryProvider.overrideWithValue(audius),
          appleMusicRepositoryProvider.overrideWithValue(apple),
          radioRepositoryProvider.overrideWithValue(FakeRadioRepository()),
        ],
      );
      addTearDown(c.dispose);
      c.read(appleMusicStatusProvider);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('Apple Music dahulu, kemudian Audius', () async {
      final c = await make();
      await c.read(musicSearchProvider.notifier).searchFor('siti');
      final s = c.read(musicSearchProvider);
      expect(s.status, MusicSearchStatus.ready);
      expect(s.results.map((t) => t.id), ['ap1', 'ap2', 'au1', 'au2']);
      expect(apple.queries, ['siti']);
    });

    test('Apple Music gagal: Audius tetap dipaparkan', () async {
      apple.error = StateError('MusicKit belum diaktifkan');
      final c = await make();
      await c.read(musicSearchProvider.notifier).searchFor('siti');
      final s = c.read(musicSearchProvider);
      expect(s.status, MusicSearchStatus.ready);
      expect(s.results.map((t) => t.id), ['au1', 'au2']);
    });

    test('kedua-duanya gagal: status gagal', () async {
      apple.error = StateError('a');
      audius.error = StateError('b');
      final c = await make();
      await c.read(musicSearchProvider.notifier).searchFor('siti');
      expect(c.read(musicSearchProvider).status, MusicSearchStatus.failed);
    });

    test(
      'belum disambung atau bukan pelanggan: Apple tidak dihubungi',
      () async {
        apple.current = const AppleMusicStatus(
          access: AppleMusicAccess.authorized,
        );
        final c = await make();
        await c.read(musicSearchProvider.notifier).searchFor('siti');
        expect(apple.queries, isEmpty);
        expect(c.read(musicSearchProvider).results.map((t) => t.id), [
          'au1',
          'au2',
        ]);
      },
    );

    test(
      'tidak disokong (Android): status unsupported, tiada sambungan',
      () async {
        apple.isSupported = false;
        final c = await make();
        expect(c.read(appleMusicStatusProvider), AppleMusicStatus.unsupported);
        await c.read(musicSearchProvider.notifier).searchFor('siti');
        expect(apple.queries, isEmpty);
      },
    );
  });

  group('kad Sambung Apple Music', () {
    late SharedPreferences prefs;
    late FakeAppleMusicRepository apple;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      apple = FakeAppleMusicRepository();
    });

    Future<void> pump(WidgetTester tester) async {
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
          appleMusicRepositoryProvider.overrideWithValue(apple),
          audioCoordinatorProvider.overrideWithValue(AudioCoordinator()),
          audioServiceStarterProvider.overrideWithValue(null),
        ],
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets('mengetik Sambung meminta kebenaran lalu menyembunyikan kad', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('apple-music-card')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('apple-music-connect')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(apple.authorizeCalls, 1);
      expect(find.byKey(const ValueKey('apple-music-card')), findsNothing);
    });

    testWidgets('ditolak: mesej tetapan tanpa butang Sambung', (tester) async {
      apple.current = const AppleMusicStatus(access: AppleMusicAccess.denied);
      await pump(tester);
      expect(find.byKey(const ValueKey('apple-music-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('apple-music-connect')), findsNothing);
      expect(
        apple.authorizeCalls,
        0,
        reason: 'tidak pernah meminta tanpa ketikan',
      );
    });

    testWidgets('bukan pelanggan: terangkan langganan, tiada butang', (
      tester,
    ) async {
      apple.current = const AppleMusicStatus(
        access: AppleMusicAccess.authorized,
        canBecomeSubscriber: true,
      );
      await pump(tester);
      expect(find.byKey(const ValueKey('apple-music-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('apple-music-connect')), findsNothing);
    });

    testWidgets('Android / ciri ditutup: kad tidak dipaparkan', (tester) async {
      apple.isSupported = false;
      await pump(tester);
      expect(find.byKey(const ValueKey('apple-music-card')), findsNothing);
    });

    testWidgets('sudah bersambung: kad tersembunyi', (tester) async {
      apple.current = _ready;
      await pump(tester);
      expect(find.byKey(const ValueKey('apple-music-card')), findsNothing);
    });
  });
}
