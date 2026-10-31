import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/log.dart';
import '../data/audius_repository.dart';
import '../data/local_library.dart';
import '../data/radio_browser_repository.dart';
import '../data/radio_favorites.dart';
import '../data/radio_health.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';

enum MusicTab {
  songs,
  radio,
  local;

  TrackSource get source => switch (this) {
    MusicTab.songs => TrackSource.audius,
    MusicTab.radio => TrackSource.radio,
    MusicTab.local => TrackSource.local,
  };
}

enum MusicSearchStatus { idle, loading, ready, empty, failed }

@immutable
class MusicSearchState {
  const MusicSearchState({
    this.tab = MusicTab.songs,
    this.query = '',
    this.status = MusicSearchStatus.idle,
    this.results = const [],
    this.region = RadioRegion.malaysia,
  });

  final MusicTab tab;
  final String query;
  final MusicSearchStatus status;
  final List<Track> results;
  final RadioRegion region;

  MusicSearchState copyWith({
    MusicTab? tab,
    String? query,
    MusicSearchStatus? status,
    List<Track>? results,
    RadioRegion? region,
  }) => MusicSearchState(
    tab: tab ?? this.tab,
    query: query ?? this.query,
    status: status ?? this.status,
    results: results ?? this.results,
    region: region ?? this.region,
  );
}

/// Satu carian untuk tiga sumber: Lagu (Audius) mencari pada pelayan selepas nyahlantun; Radio dan
/// Fail saya menapis senarai tempatan serta-merta. Radio juga dinyahlantun (carian nama sedunia).
/// Setiap sumber gagal secara berasingan.
class MusicSearchController extends Notifier<MusicSearchState> {
  Timer? _debounce;
  int _generation = 0;
  static const debounce = Duration(milliseconds: 400);

  @override
  MusicSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    // Senarai Kegemaran dibaca terus dari peranti: segarkan serta-merta (tanpa pemuat) bila bintang
    // diketik semasa melihatnya.
    ref.listen(radioFavoritesProvider, (_, favorites) {
      if (state.tab != MusicTab.radio ||
          state.region != RadioRegion.favorites) {
        return;
      }
      final results = _filter(favorites, state.query.trim());
      state = state.copyWith(
        status: results.isEmpty
            ? MusicSearchStatus.empty
            : MusicSearchStatus.ready,
        results: results,
      );
    });
    return const MusicSearchState();
  }

  Future<void> setTab(MusicTab tab) async {
    _debounce?.cancel();
    state = state.copyWith(tab: tab);
    await _run(immediate: true);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    if (state.tab != MusicTab.local) {
      // Lagu dan Radio mencari di pelayan: nyahlantun supaya tidak satu permintaan setiap huruf.
      _debounce = Timer(debounce, () => unawaited(_run()));
    } else {
      unawaited(_run(immediate: true));
    }
  }

  Future<void> setRegion(RadioRegion region) async {
    _debounce?.cancel();
    state = state.copyWith(region: region);
    await _run(immediate: true);
  }

  /// Cadangan carian (cth. "K-pop") pada tab Lagu: isi pertanyaan dan cari serta-merta.
  Future<void> searchFor(String query) async {
    _debounce?.cancel();
    state = state.copyWith(query: query);
    await _run(immediate: true);
  }

  Future<void> refresh() => _run(immediate: true);

  Future<void> _run({bool immediate = false}) async {
    final generation = ++_generation;
    final tab = state.tab;
    final query = state.query.trim();
    if (tab == MusicTab.songs && query.isEmpty) {
      // Tanpa pertanyaan: trending sebagai cadangan (bukan skrin kosong).
      state = state.copyWith(
        status: MusicSearchStatus.loading,
        results: const [],
      );
    } else {
      state = state.copyWith(status: MusicSearchStatus.loading);
    }
    try {
      final results = switch (tab) {
        MusicTab.songs =>
          query.isEmpty
              ? await ref.read(audiusRepositoryProvider).trending()
              : await ref.read(audiusRepositoryProvider).search(query),
        MusicTab.radio when state.region == RadioRegion.favorites => _filter(
          ref.read(radioFavoritesProvider),
          query,
        ),
        MusicTab.radio => _sinkFailed(
          await ref
              .read(radioRepositoryProvider)
              .stations(query: query, region: state.region),
        ),
        MusicTab.local => _filter(
          await ref.read(localLibraryProvider).list(),
          query,
        ),
      };
      if (generation != _generation) return;
      state = state.copyWith(
        status: results.isEmpty
            ? MusicSearchStatus.empty
            : MusicSearchStatus.ready,
        results: results,
      );
    } on Object catch (e) {
      if (generation != _generation) return;
      logDiag('Carian muzik (${tab.name}) gagal: $e');
      state = state.copyWith(
        status: MusicSearchStatus.failed,
        results: const [],
      );
    }
  }

  /// Stesen yang gagal disambung pada peranti ini dalam 24 jam lalu dibenam ke bawah (susunan lain
  /// kekal): mengikut ukuran, separuh senarai Korea tidak boleh disambung dari luar Korea.
  List<Track> _sinkFailed(List<Track> stations) {
    final health = ref.read(radioHealthProvider.notifier);
    final ok = <Track>[];
    final failed = <Track>[];
    for (final t in stations) {
      (health.isFailed(t) ? failed : ok).add(t);
    }
    return failed.isEmpty ? stations : [...ok, ...failed];
  }

  static List<Track> _filter(List<Track> tracks, String query) {
    final q = query.toLowerCase();
    if (q.isEmpty) return tracks;
    return [
      for (final t in tracks)
        if (t.title.toLowerCase().contains(q) ||
            (t.artist?.toLowerCase().contains(q) ?? false))
          t,
    ];
  }

  /// Import fail dan segarkan tab Fail saya.
  Future<int> importLocal() async {
    final added = await ref.read(localLibraryProvider).import();
    if (state.tab == MusicTab.local) await _run(immediate: true);
    return added.length;
  }

  Future<void> removeLocal(Track t) async {
    await ref.read(localLibraryProvider).remove(t);
    if (state.tab == MusicTab.local) await _run(immediate: true);
  }
}

final musicSearchProvider =
    NotifierProvider<MusicSearchController, MusicSearchState>(
      MusicSearchController.new,
    );
