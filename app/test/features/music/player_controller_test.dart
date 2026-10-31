import 'package:fgmap/core/audio/audio_coordinator.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/music/data/music_settings.dart';
import 'package:fgmap/features/music/data/radio_browser_repository.dart';
import 'package:fgmap/features/music/data/radio_health.dart';
import 'package:fgmap/features/music/domain/eq.dart';
import 'package:fgmap/features/music/domain/player_state.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:fgmap/features/music/presentation/player_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_test_support.dart';

void main() {
  late SharedPreferences prefs;
  late FakeMusicEngine engine;
  late FakeRadioRepository radio;
  late AudioCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    engine = FakeMusicEngine();
    radio = FakeRadioRepository();
    coordinator = AudioCoordinator();
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        musicEngineProvider.overrideWithValue(engine),
        radioRepositoryProvider.overrideWithValue(radio),
        audioCoordinatorProvider.overrideWithValue(coordinator),
        audioServiceStarterProvider.overrideWithValue(null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('idle -> loading -> playing -> paused -> idle', () async {
    final c = make();
    final ctrl = c.read(playerControllerProvider.notifier);
    expect(c.read(playerControllerProvider).status, PlayerStatus.idle);
    final q = [track('a'), track('b'), track('c')];
    await ctrl.playTrack(q[1], queue: q);
    expect(engine.calls, containsAllInOrder(['setQueue:3:1', 'play']));
    expect(c.read(playerControllerProvider).current, q[1]);
    expect(c.read(playerControllerProvider).status, PlayerStatus.loading);

    engine.emit(PlayerStatus.playing, duration: const Duration(minutes: 3));
    await tick();
    expect(c.read(playerControllerProvider).isPlaying, isTrue);
    expect(
      c.read(playerControllerProvider).duration,
      const Duration(minutes: 3),
    );

    await ctrl.toggle();
    expect(engine.calls.last, 'pause');
    engine.emit(PlayerStatus.paused);
    await tick();
    expect(c.read(playerControllerProvider).status, PlayerStatus.paused);
    await ctrl.toggle();
    expect(engine.calls.last, 'play');

    await ctrl.stop();
    expect(c.read(playerControllerProvider), const PlayerState());
  });

  test(
    'seterusnya/sebelumnya mengikut sempadan; sebelumnya > 3 s = ulang',
    () async {
      final c = make();
      final ctrl = c.read(playerControllerProvider.notifier);
      final q = [track('a'), track('b')];
      await ctrl.playTrack(q[0], queue: q);
      engine.calls.clear();
      await ctrl.previous(); // di awal, tiada sebelumnya -> seek 0
      expect(engine.calls, ['seek:0']);
      engine.calls.clear();
      await ctrl.next();
      expect(engine.calls, ['index:1', 'play']);
      engine.emit(
        PlayerStatus.playing,
        index: 1,
        position: const Duration(seconds: 10),
      );
      await tick();
      expect(c.read(playerControllerProvider).current, q[1]);
      expect(c.read(playerControllerProvider).hasNext, isFalse);
      engine.calls.clear();
      await ctrl.next(); // tiada
      expect(engine.calls, isEmpty);
      await ctrl.previous(); // 10 s masuk -> ulang
      expect(engine.calls, ['seek:0']);
      engine.emit(
        PlayerStatus.playing,
        index: 1,
        position: const Duration(seconds: 1),
      );
      await tick();
      engine.calls.clear();
      await ctrl.previous();
      expect(engine.calls, ['index:0', 'play']);
    },
  );

  test(
    'siaran langsung: seek diabaikan; klik radio dikira sekali setiap main',
    () async {
      final c = make();
      final ctrl = c.read(playerControllerProvider.notifier);
      final live = track('r1', source: TrackSource.radio);
      await ctrl.playTrack(live);
      expect(radio.clicks, ['uuid-r1']);
      engine.calls.clear();
      await ctrl.seek(const Duration(seconds: 30));
      expect(engine.calls, isEmpty);
      // Lagu biasa boleh seek.
      await ctrl.playTrack(track('a'));
      await ctrl.seek(const Duration(seconds: 30));
      expect(engine.calls.last, 'seek:30');
    },
  );

  test(
    'ralat enjin -> status error dengan mesej; ralat semasa setQueue juga',
    () async {
      final c = make();
      final ctrl = c.read(playerControllerProvider.notifier);
      await ctrl.playTrack(track('a'));
      engine.emit(PlayerStatus.error, error: 'HTTP 403');
      await tick();
      expect(c.read(playerControllerProvider).status, PlayerStatus.error);
      expect(c.read(playerControllerProvider).error, 'HTTP 403');

      engine.failOnSetQueue = StateError('rosak');
      await ctrl.playTrack(track('b'));
      expect(c.read(playerControllerProvider).status, PlayerStatus.error);
    },
  );

  test('suara navigasi: perlahankan (lalai) kepada 20% dan pulihkan', () async {
    final c = make();
    final ctrl = c.read(playerControllerProvider.notifier);
    await ctrl.playTrack(track('a'));
    engine.emit(PlayerStatus.playing);
    await tick();
    await ctrl.setVolume(0.8);
    expect(engine.volume, 0.8);

    await coordinator.beginSpeech();
    expect(c.read(playerControllerProvider).ducked, isTrue);
    expect(engine.volume, closeTo(0.16, 0.001)); // 20% daripada 0.8
    // Kelantangan ditukar semasa perlahan: hanya disimpan, dipakai selepas.
    await ctrl.setVolume(1.0);
    expect(engine.volume, closeTo(0.16, 0.001));
    // Dua ayat bertindih: pulih hanya selepas kedua-dua tamat.
    await coordinator.beginSpeech();
    await coordinator.endSpeech();
    expect(c.read(playerControllerProvider).ducked, isTrue);
    await coordinator.endSpeech();
    expect(c.read(playerControllerProvider).ducked, isFalse);
    expect(engine.volume, 1.0);
    expect(engine.calls, isNot(contains('pause')));
  });

  test(
    'suara navigasi: mod jeda -> jeda dan sambung semula; tidak sambung jika pengguna jeda',
    () async {
      await prefs.setString('music.duckMode', 'pause');
      final c = make();
      final ctrl = c.read(playerControllerProvider.notifier);
      await ctrl.playTrack(track('a'));
      engine.emit(PlayerStatus.playing);
      await tick();
      engine.calls.clear();
      await coordinator.beginSpeech();
      expect(engine.calls, ['pause']);
      engine.emit(PlayerStatus.paused);
      await tick();
      await coordinator.endSpeech();
      expect(engine.calls.last, 'play');

      // Pengguna sendiri jeda sebelum suara: jangan sambung.
      engine.emit(PlayerStatus.playing);
      await tick();
      await ctrl.toggle();
      engine.emit(PlayerStatus.paused);
      await tick();
      engine.calls.clear();
      await coordinator.beginSpeech();
      await coordinator.endSpeech();
      expect(engine.calls, isNot(contains('play')));
    },
  );

  test('tiada lagu: suara navigasi tidak mengubah apa-apa', () async {
    make().read(playerControllerProvider);
    await coordinator.beginSpeech();
    await coordinator.endSpeech();
    expect(engine.calls, isEmpty);
  });

  test(
    'penyama mengikut tetapan: pratetap bes dipakai; tersuai diklip',
    () async {
      final c = make();
      c.read(playerControllerProvider);
      await tick();
      expect(engine.eqEnabled, isFalse);
      await c.read(musicSettingsProvider.notifier).setEqPreset(EqPreset.bass);
      await tick();
      expect(engine.eqEnabled, isTrue);
      expect(engine.eqGains, eqPresetGainsDb[EqPreset.bass]);
      await c.read(musicSettingsProvider.notifier).setCustomGain(0, 40);
      await tick();
      expect(c.read(musicSettingsProvider).eq.preset, EqPreset.custom);
      expect(engine.eqGains!.first, eqMaxDb);
      expect(prefs.getStringList('music.eq.gains')!.first, eqMaxDb.toString());
    },
  );

  test(
    'tetapan muzik: lalai perlahankan, disimpan dan dibaca semula',
    () async {
      final c = make();
      expect(c.read(musicSettingsProvider).duckMode, DuckMode.duck);
      await c.read(musicSettingsProvider.notifier).setDuckMode(DuckMode.pause);
      await c.read(musicSettingsProvider.notifier).setLastTab(2);
      expect(prefs.getString('music.duckMode'), 'pause');
      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(musicSettingsProvider).duckMode, DuckMode.pause);
      expect(again.read(musicSettingsProvider).lastTab, 2);
    },
  );

  group('Radio langsung', () {
    test(
      'lagu yang sedang bersiaran dibersihkan; nama stesen sahaja dibuang',
      () async {
        final c = make();
        final ctrl = c.read(playerControllerProvider.notifier);
        await ctrl.playTrack(
          track('r', source: TrackSource.radio, title: 'Sinar FM'),
        );
        engine.emit(
          PlayerStatus.playing,
          nowPlaying: ' Spring - Kugapai Cinta ',
        );
        await tick();
        expect(
          c.read(playerControllerProvider).nowPlaying,
          'Spring - Kugapai Cinta',
        );
        engine.emit(PlayerStatus.playing, nowPlaying: 'SINAR FM');
        await tick();
        expect(c.read(playerControllerProvider).nowPlaying, isNull);
        engine.emit(PlayerStatus.playing, nowPlaying: 'Awie - Sejati');
        await tick();
        engine.emit(
          PlayerStatus.playing,
        ); // enjin menghantar kosong (tukar stesen)
        await tick();
        expect(c.read(playerControllerProvider).nowPlaying, isNull);
      },
    );

    test(
      'lagu bukan siaran langsung tidak pernah memaparkan tajuk ICY',
      () async {
        final c = make();
        await c
            .read(playerControllerProvider.notifier)
            .playTrack(track('a', title: 'Satu'));
        engine.emit(PlayerStatus.playing, nowPlaying: 'Sesuatu - Lain');
        await tick();
        expect(c.read(playerControllerProvider).nowPlaying, isNull);
      },
    );

    test(
      'ralat strim ditanda gagal; main semula berjaya melupakannya',
      () async {
        final c = make();
        final ctrl = c.read(playerControllerProvider.notifier);
        final station = track(
          'r',
          source: TrackSource.radio,
          title: 'KBS Cool FM',
        );
        await ctrl.playTrack(station);
        engine.emit(PlayerStatus.error, error: '403');
        await tick();
        final health = c.read(radioHealthProvider.notifier);
        expect(health.isFailed(station), isTrue);
        engine.emit(PlayerStatus.playing);
        await tick();
        expect(health.isFailed(station), isFalse);
      },
    );

    test('setQueue gagal pada stesen radio juga ditanda gagal', () async {
      final c = make();
      final station = track('r', source: TrackSource.radio);
      engine.failOnSetQueue = StateError('tiada sambungan');
      await c.read(playerControllerProvider.notifier).playTrack(station);
      expect(c.read(playerControllerProvider).status, PlayerStatus.error);
      expect(c.read(radioHealthProvider.notifier).isFailed(station), isTrue);
    });

    test('lagu Audius yang ralat tidak masuk ingatan stesen gagal', () async {
      final c = make();
      await c
          .read(playerControllerProvider.notifier)
          .playTrack(track('a', title: 'Satu'));
      engine.emit(PlayerStatus.error, error: 'x');
      await tick();
      expect(c.read(radioHealthProvider), isEmpty);
    });
  });
}
