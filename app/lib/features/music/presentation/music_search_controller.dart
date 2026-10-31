import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/log.dart';
import '../data/audius_repository.dart';
import '../data/local_library.dart';
import '../data/radio_browser_repository.dart';
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
  });

  final MusicTab tab;
  final String query;
  final MusicSearchStatus status;
  final List<Track> results;

  MusicSearchState copyWith({
    MusicTab? tab,
    String? query,
    MusicSearchStatus? status,
    List<Track>? results,
  }) => MusicSearchState(
    tab: tab ?? this.tab,
    query: query ?? this.query,
    status: status ?? this.status,
    results: results ?? this.results,
  );
}

/// Satu carian untuk tiga sumber: Lagu (Audius) mencari pada pelayan selepas nyahlantun; Radio dan
/// Fail saya menapis senarai tempatan serta-merta. Setiap sumber gagal secara berasingan.
class MusicSearchController extends Notifier<MusicSearchState> {
  Timer? _debounce;
  int _generation = 0;
  static const debounce = Duration(milliseconds: 400);

  @override
  MusicSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
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
    if (state.tab == MusicTab.songs) {
      _debounce = Timer(debounce, () => unawaited(_run()));
    } else {
      unawaited(_run(immediate: true));
    }
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
        MusicTab.radio =>
          await ref.read(radioRepositoryProvider).stations(query: query),
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
