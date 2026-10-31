import 'package:fgmap/features/music/data/audius_repository.dart';
import 'package:fgmap/features/music/data/local_library.dart';
import 'package:fgmap/features/music/data/radio_browser_repository.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:fgmap/features/music/presentation/music_search_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'music_test_support.dart';

void main() {
  late FakeAudiusRepository audius;
  late FakeRadioRepository radio;
  late FakeLocalLibrary local;

  setUp(() {
    audius = FakeAudiusRepository(
      results: [track('a1'), track('a2')],
      trendingResults: [track('t1')],
    );
    radio = FakeRadioRepository(
      results: [
        track('r1', source: TrackSource.radio, title: 'Sinar FM'),
        track('r2', source: TrackSource.radio, title: 'Hot FM'),
      ],
    );
    local = FakeLocalLibrary(
      tracks: [track('l1', source: TrackSource.local, title: 'Lagu Raya')],
      toImport: [track('l2', source: TrackSource.local, title: 'Baru')],
    );
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        audiusRepositoryProvider.overrideWithValue(audius),
        radioRepositoryProvider.overrideWithValue(radio),
        localLibraryProvider.overrideWithValue(local),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('tab Lagu tanpa pertanyaan: trending; carian dinyahlantun 400 ms', () async {
    final c = make();
    final ctrl = c.read(musicSearchProvider.notifier);
    await ctrl.setTab(MusicTab.songs);
    expect(c.read(musicSearchProvider).status, MusicSearchStatus.ready);
    expect(c.read(musicSearchProvider).results.map((t) => t.id), ['t1']);

    ctrl.setQuery('la');
    ctrl.setQuery('lagu');
    await settle();
    expect(audius.queries, isEmpty, reason: 'belum tamat nyahlantun');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(audius.queries, ['lagu']);
    expect(c.read(musicSearchProvider).results.map((t) => t.id), ['a1', 'a2']);
  });

  test('tab Radio dan Fail saya menapis serta-merta; kosong -> empty', () async {
    final c = make();
    final ctrl = c.read(musicSearchProvider.notifier);
    await ctrl.setTab(MusicTab.radio);
    expect(c.read(musicSearchProvider).results, hasLength(2));
    ctrl.setQuery('sinar');
    await settle();
    expect(c.read(musicSearchProvider).results.map((t) => t.title), ['Sinar FM']);
    ctrl.setQuery('zzz');
    await settle();
    expect(c.read(musicSearchProvider).status, MusicSearchStatus.empty);

    ctrl.setQuery('');
    await ctrl.setTab(MusicTab.local);
    expect(c.read(musicSearchProvider).results.map((t) => t.title), ['Lagu Raya']);
    ctrl.setQuery('raya');
    await settle();
    expect(c.read(musicSearchProvider).results, hasLength(1));
  });

  test('sumber gagal secara berasingan: Audius gagal tidak menjejaskan Radio', () async {
    audius.error = StateError('offline');
    final c = make();
    final ctrl = c.read(musicSearchProvider.notifier);
    await ctrl.setTab(MusicTab.songs);
    expect(c.read(musicSearchProvider).status, MusicSearchStatus.failed);
    await ctrl.setTab(MusicTab.radio);
    expect(c.read(musicSearchProvider).status, MusicSearchStatus.ready);
  });

  test('import menambah fail dan menyegarkan tab Fail saya; buang', () async {
    final c = make();
    final ctrl = c.read(musicSearchProvider.notifier);
    await ctrl.setTab(MusicTab.local);
    expect(await ctrl.importLocal(), 1);
    expect(c.read(musicSearchProvider).results, hasLength(2));
    await ctrl.removeLocal(c.read(musicSearchProvider).results.first);
    expect(c.read(musicSearchProvider).results, hasLength(1));
  });
}
