import 'package:fgmap/core/audio/audio_coordinator.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/music/data/audius_repository.dart';
import 'package:fgmap/features/music/data/local_library.dart';
import 'package:fgmap/features/music/data/music_settings.dart';
import 'package:fgmap/features/music/data/radio_browser_repository.dart';
import 'package:fgmap/features/music/data/radio_favorites.dart';
import 'package:fgmap/features/music/domain/eq.dart';
import 'package:fgmap/features/music/domain/music_repository.dart';
import 'package:fgmap/features/music/domain/player_state.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:fgmap/features/music/presentation/equalizer_sheet.dart';
import 'package:fgmap/features/music/presentation/mini_player.dart';
import 'package:fgmap/features/music/presentation/music_settings_section.dart';
import 'package:fgmap/features/music/presentation/music_sheet.dart';
import 'package:fgmap/features/music/presentation/now_playing_page.dart';
import 'package:fgmap/features/music/presentation/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';
import 'music_test_support.dart';

void main() {
  late SharedPreferences prefs;
  late FakeMusicEngine engine;
  late FakeAudiusRepository audius;
  late FakeRadioRepository radio;
  late FakeLocalLibrary local;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    engine = FakeMusicEngine();
    audius = FakeAudiusRepository(
      results: [
        track('a1', title: 'Lagu Raya Aidilfitri'),
        track('a2', title: 'Sejahtera'),
      ],
      trendingResults: [track('t1', title: 'Trending Satu')],
    );
    radio = FakeRadioRepository(
      results: [track('r1', source: TrackSource.radio, title: 'Sinar FM')],
    );
    local = FakeLocalLibrary(
      toImport: [track('l1', source: TrackSource.local, title: 'Fail Saya')],
    );
  });

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      Scaffold(body: child),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        musicEngineProvider.overrideWithValue(engine),
        audiusRepositoryProvider.overrideWithValue(audius),
        radioRepositoryProvider.overrideWithValue(radio),
        localLibraryProvider.overrideWithValue(local),
        audioCoordinatorProvider.overrideWithValue(AudioCoordinator()),
        audioServiceStarterProvider.overrideWithValue(null),
      ],
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  // Medan carian berfokus mengelip kursor: pumpAndSettle tidak akan selesai, jadi pam terhad.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  group('MusicSheet', () {
    testWidgets('tab Lagu: cadangan carian mengisi medan dan mencari', (
      tester,
    ) async {
      await pump(tester, const MusicSheet());
      expect(find.byKey(const ValueKey('music-suggestions')), findsOneWidget);
      // Baris cadangan boleh digulung: cip di luar skrin belum dibina.
      final chip = find.byKey(const ValueKey('music-suggest-K-pop'));
      await tester.scrollUntilVisible(
        chip,
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('music-suggestions')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(chip);
      await settle(tester);
      expect(audius.queries, contains('K-pop'));
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('music-search')),
      );
      expect(field.controller!.text, 'K-pop');
    });

    testWidgets(
      'tab Radio: bintang menyimpan stesen; cip Kegemaran memaparkannya',
      (tester) async {
        await pump(tester, const MusicSheet());
        await tester.tap(find.text('Radio'));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('music-region-favorites')));
        await settle(tester);
        expect(find.byKey(const ValueKey('music-message')), findsOneWidget);
        expect(
          find.textContaining('Belum ada stesen kegemaran'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('music-region-malaysia')));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('music-fav-radio:r1')));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('music-region-favorites')));
        await settle(tester);
        expect(
          find.byKey(const ValueKey('music-result-radio:r1')),
          findsOneWidget,
        );
        expect(find.text('Sinar FM'), findsOneWidget);

        // Ketik bintang lagi di dalam Kegemaran membuangnya serta-merta.
        await tester.tap(find.byKey(const ValueKey('music-fav-radio:r1')));
        await settle(tester);
        expect(
          find.byKey(const ValueKey('music-result-radio:r1')),
          findsNothing,
        );
      },
    );

    testWidgets('tab Radio: cip kawasan; ketik Korea memuat stesen Korea', (
      tester,
    ) async {
      await pump(tester, const MusicSheet());
      await tester.tap(find.text('Radio'));
      await settle(tester);
      expect(find.byKey(const ValueKey('music-regions')), findsOneWidget);
      expect(find.byKey(const ValueKey('music-suggestions')), findsNothing);
      for (final name in [
        'favorites',
        'malaysia',
        'indonesia',
        'japan',
        'jpop',
        'korea',
        'kpop',
      ]) {
        expect(find.byKey(ValueKey('music-region-$name')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('music-region-japan')));
      await settle(tester);
      expect(radio.regions.last, RadioRegion.japan);
      await tester.tap(find.byKey(const ValueKey('music-region-korea')));
      await settle(tester);
      expect(radio.regions.last, RadioRegion.korea);
      await tester.tap(find.byKey(const ValueKey('music-region-kpop')));
      await settle(tester);
      expect(radio.regions.last, RadioRegion.kpop);
    });

    testWidgets(
      'tiada hasil lagu: mesej jujur + butang Cari dalam Radio memindahkan pertanyaan',
      (tester) async {
        audius.results = [];
        await pump(tester, const MusicSheet());
        await tester.enterText(
          find.byKey(const ValueKey('music-search')),
          'Sinar',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
        expect(find.textContaining('label besar'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('music-try-radio')));
        await settle(tester);
        expect(find.text('Sinar FM'), findsOneWidget);
      },
    );

    testWidgets(
      'trending dahulu; taip -> hasil -> ketik -> main; atribusi dipaparkan',
      (tester) async {
        final c = await pump(tester, const MusicSheet());
        expect(find.text('Trending Satu'), findsOneWidget);
        expect(find.byKey(const ValueKey('music-attribution')), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('music-search')),
          'raya',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
        expect(find.text('Lagu Raya Aidilfitri'), findsOneWidget);
        expect(find.textContaining('via Audius'), findsWidgets);
        await tester.tap(find.text('Lagu Raya Aidilfitri'));
        await settle(tester);
        expect(engine.calls, contains('setQueue:2:0'));
        expect(engine.calls, contains('play'));
        expect(c.read(playerControllerProvider).current?.id, 'a1');
        // Pemain kecil muncul di bawah lembaran.
        expect(find.byKey(const ValueKey('mini-player')), findsOneWidget);
      },
    );

    testWidgets('tab Radio: LANGSUNG; tab Fail saya: import', (tester) async {
      final c = await pump(tester, const MusicSheet());
      await tester.tap(find.text('Radio'));
      await settle(tester);
      expect(find.text('Sinar FM'), findsOneWidget);
      expect(find.textContaining('LANGSUNG'), findsOneWidget);
      expect(c.read(musicSettingsProvider).lastTab, 1);

      await tester.tap(find.text('Fail saya'));
      await settle(tester);
      expect(find.byKey(const ValueKey('music-message')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('music-import')));
      await settle(tester);
      expect(find.text('Fail Saya'), findsOneWidget);
    });

    testWidgets('sumber gagal: mesej jujur bagi sumber itu sahaja', (
      tester,
    ) async {
      audius.error = StateError('offline');
      await pump(tester, const MusicSheet());
      expect(
        find.textContaining('Audius tidak dapat dihubungi'),
        findsOneWidget,
      );
      await tester.tap(find.text('Radio'));
      await settle(tester);
      expect(find.text('Sinar FM'), findsOneWidget);
    });
  });

  group('MiniPlayer dan NowPlaying', () {
    testWidgets('tersembunyi tanpa lagu; main/jeda, seterusnya, tutup', (
      tester,
    ) async {
      final c = await pump(tester, const MiniPlayer());
      expect(find.byKey(const ValueKey('mini-player')), findsNothing);
      final q = [track('a', title: 'Satu'), track('b', title: 'Dua')];
      await c.read(playerControllerProvider.notifier).playTrack(q[0], queue: q);
      engine.emit(PlayerStatus.playing);
      await tester.pumpAndSettle();
      expect(find.text('Satu'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mini-toggle')));
      expect(engine.calls.last, 'pause');
      await tester.tap(find.byKey(const ValueKey('mini-next')));
      await tester.pumpAndSettle();
      expect(engine.calls, contains('index:1'));
      await tester.tap(find.byKey(const ValueKey('mini-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mini-player')), findsNothing);
    });

    testWidgets(
      'pemain penuh: peluncur untuk lagu, tiada untuk radio; EQ dibuka',
      (tester) async {
        final c = await pump(
          tester,
          const SizedBox(height: 800, child: NowPlayingSheet()),
        );
        await c
            .read(playerControllerProvider.notifier)
            .playTrack(track('a', title: 'Satu'));
        engine.emit(PlayerStatus.playing, duration: const Duration(minutes: 3));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('now-title')), findsOneWidget);
        expect(find.byKey(const ValueKey('now-seek')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('now-eq')));
        await tester.pumpAndSettle();
        expect(find.byType(EqualizerPanel), findsOneWidget);
      },
    );

    testWidgets(
      'radio: lagu yang sedang bersiaran dipaparkan; bintang menyimpan',
      (tester) async {
        final c = await pump(
          tester,
          const Column(
            children: [
              MiniPlayer(),
              SizedBox(height: 700, child: NowPlayingSheet()),
            ],
          ),
        );
        final station = track(
          'r',
          source: TrackSource.radio,
          title: 'Sinar FM',
        );
        await c.read(playerControllerProvider.notifier).playTrack(station);
        engine.emit(
          PlayerStatus.playing,
          nowPlaying: 'Siti Nurhaliza - Cindai',
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('mini-subtitle'))).data,
          'Siti Nurhaliza - Cindai',
        );
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('now-subtitle'))).data,
          'Siti Nurhaliza - Cindai',
        );
        expect(find.byTooltip('Tambah ke kegemaran'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('now-fav')));
        await tester.pumpAndSettle();
        expect(c.read(radioFavoritesProvider), [station]);
        expect(find.byTooltip('Buang daripada kegemaran'), findsOneWidget);
      },
    );

    testWidgets('radio: tiada peluncur, lencana LANGSUNG', (tester) async {
      final c = await pump(
        tester,
        const SizedBox(height: 800, child: NowPlayingSheet()),
      );
      await c
          .read(playerControllerProvider.notifier)
          .playTrack(track('r', source: TrackSource.radio, title: 'Sinar FM'));
      engine.emit(PlayerStatus.playing);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('now-seek')), findsNothing);
      expect(find.text('LANGSUNG'), findsOneWidget);
    });
  });

  group('EqualizerPanel dan tetapan', () {
    testWidgets('pratetap Bes memakai gandaan; peluncur hanya dalam Tersuai', (
      tester,
    ) async {
      final c = await pump(
        tester,
        const SingleChildScrollView(child: EqualizerPanel()),
      );
      await tester.tap(find.text('Bes'));
      await tester.pumpAndSettle();
      expect(c.read(musicSettingsProvider).eq.preset, EqPreset.bass);
      expect(engine.eqGains, eqPresetGainsDb[EqPreset.bass]);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('eq-band-0')),
      );
      expect(slider.onChanged, isNull);
      await tester.tap(find.text('Tersuai'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('eq-band-0')))
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('iOS/tidak disokong: nota dan kawalan dilumpuhkan', (
      tester,
    ) async {
      engine.supportsEq = false;
      await pump(tester, const SingleChildScrollView(child: EqualizerPanel()));
      expect(find.byKey(const ValueKey('eq-unsupported')), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('eq-enable')))
            .onChanged,
        isNull,
      );
    });

    testWidgets('tetapan: lalai perlahankan; pilih jeda disimpan', (
      tester,
    ) async {
      final c = await pump(
        tester,
        const SingleChildScrollView(child: MusicSettingsSection()),
      );
      expect(c.read(musicSettingsProvider).duckMode, DuckMode.duck);
      await tester.tap(find.byKey(const ValueKey('music-duck-pause')));
      await tester.pumpAndSettle();
      expect(c.read(musicSettingsProvider).duckMode, DuckMode.pause);
      expect(prefs.getString('music.duckMode'), 'pause');
      await tester.tap(find.byKey(const ValueKey('music-open')));
      await tester.pumpAndSettle();
      expect(find.byType(MusicSheet), findsOneWidget);
    });
  });
}
