import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../data/photon_geocoder.dart';
import '../domain/place.dart';

enum SearchStatus { idle, loading, results, empty, failed }

@immutable
class PlaceSearchState {
  const PlaceSearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.failure,
  });

  final SearchStatus status;

  /// Teks yang menghasilkan [results] (atau sedang dicari).
  final String query;
  final List<Place> results;
  final GeocodeFailureKind? failure;
}

/// Jeda menaip sebelum carian dihantar. Photon awam ialah sumber kongsi; setiap ketukan kekunci
/// tidak boleh menjadi satu permintaan.
final searchDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 350),
);

/// Carian tempat dengan debounce, pembatalan permintaan lapuk, dan cache hasil dalam sesi.
class PlaceSearchController extends Notifier<PlaceSearchState> {
  Timer? _timer;
  CancelToken? _cancel;
  int _seq = 0;

  /// Cache hasil mengikut (teks, kawasan hampir dibundar) supaya menaip semula atau memadam satu aksara
  /// tidak mengulang permintaan.
  final Map<String, List<Place>> _cache = {};

  @override
  PlaceSearchState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _cancel?.cancel();
    });
    return const PlaceSearchState();
  }

  static const _minChars = 2;

  /// Dipanggil setiap kali teks berubah.
  void onQueryChanged(String text, {GeoPoint? near}) {
    final query = text.trim();
    _timer?.cancel();
    _cancel?.cancel();
    final seq = ++_seq;

    if (query.length < _minChars) {
      state = const PlaceSearchState();
      return;
    }

    final cached = _cache[_key(query, near)];
    if (cached != null) {
      state = _ready(query, cached);
      return;
    }

    state = PlaceSearchState(status: SearchStatus.loading, query: query);
    _timer = Timer(
      ref.read(searchDebounceProvider),
      () => _run(query, near, seq),
    );
  }

  /// Cuba lagi carian terakhir selepas kegagalan.
  void retry({GeoPoint? near}) {
    final q = state.query;
    if (q.length < _minChars) return;
    onQueryChanged(q, near: near);
  }

  void clear() {
    _timer?.cancel();
    _cancel?.cancel();
    _seq++;
    state = const PlaceSearchState();
  }

  Future<void> _run(String query, GeoPoint? near, int seq) async {
    final cancel = CancelToken();
    _cancel = cancel;
    try {
      final results = await ref
          .read(geocoderProvider)
          .search(query, near: near, cancel: cancel);
      if (seq != _seq || !ref.mounted) return;
      _cache[_key(query, near)] = results;
      state = _ready(query, results);
    } on GeocodeFailure catch (f) {
      if (seq != _seq || !ref.mounted) return;
      state = PlaceSearchState(
        status: SearchStatus.failed,
        query: query,
        failure: f.kind,
      );
    } on DioException catch (e) {
      // Pembatalan oleh permintaan yang lebih baharu: bukan kegagalan.
      if (e.type == DioExceptionType.cancel || seq != _seq || !ref.mounted) {
        return;
      }
      state = PlaceSearchState(
        status: SearchStatus.failed,
        query: query,
        failure: GeocodeFailureKind.generic,
      );
    }
  }

  PlaceSearchState _ready(String query, List<Place> results) =>
      PlaceSearchState(
        status: results.isEmpty ? SearchStatus.empty : SearchStatus.results,
        query: query,
        results: results,
      );

  // Bundar ke ~1 km (2 perpuluhan ≈ 1.1 km) supaya pergerakan kecil tidak menggugurkan cache.
  static String _key(String query, GeoPoint? near) =>
      '${query.toLowerCase()}|${near == null ? '-' : '${near.lat.toStringAsFixed(2)},${near.lng.toStringAsFixed(2)}'}';
}

final placeSearchControllerProvider =
    NotifierProvider.autoDispose<PlaceSearchController, PlaceSearchState>(
      PlaceSearchController.new,
    );
