import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../data/nearby_search.dart';
import '../data/photon_geocoder.dart';
import '../domain/nearby_category.dart';
import '../domain/place.dart';
import '../domain/place_ranker.dart';

enum SearchStatus { idle, loading, results, empty, failed }

@immutable
class PlaceSearchState {
  const PlaceSearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.failure,
    this.nearby,
    this.origin,
    this.cachedAt,
  });

  final SearchStatus status;

  /// Teks yang menghasilkan [results] (atau sedang dicari).
  final String query;
  final List<Place> results;
  final GeocodeFailureKind? failure;

  /// Kategori jika ini carian "berhampiran" (bukan teks), dan titik pusatnya.
  final NearbyCategory? nearby;
  final GeoPoint? origin;

  /// Bukan null apabila pelayan tidak dapat dicapai dan [results] ialah simpanan lama dalam peranti.
  final DateTime? cachedAt;
}

/// Jeda menaip sebelum carian dihantar. Photon awam ialah sumber kongsi; setiap ketukan kekunci
/// tidak boleh menjadi satu permintaan.
final searchDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 350),
);

final placeRankerProvider = Provider<PlaceRanker>((ref) => const PlaceRanker());

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

  /// Carian kategori berhampiran (stesen minyak, makan...). Tiada debounce: ia dicetus oleh ketukan,
  /// bukan menaip. Hasil tersusun dari yang paling dekat dengan [center].
  void searchNearby(
    NearbyCategory category, {
    required GeoPoint center,
    required String label,
    required String fallbackName,
  }) {
    _timer?.cancel();
    _cancel?.cancel();
    final seq = ++_seq;
    _lastNearby = (category, center, label, fallbackName);

    final key = 'nearby:${category.name}|${_roundKey(center)}';
    final cached = _cache[key];
    if (cached != null) {
      state = _ready(label, cached, nearby: category, origin: center);
      return;
    }
    state = PlaceSearchState(
      status: SearchStatus.loading,
      query: label,
      nearby: category,
      origin: center,
    );
    unawaited(_runNearby(category, center, label, fallbackName, key, seq));
  }

  Future<void> _runNearby(
    NearbyCategory category,
    GeoPoint center,
    String label,
    String fallbackName,
    String key,
    int seq,
  ) async {
    final cancel = CancelToken();
    _cancel = cancel;
    try {
      final result = await ref
          .read(nearbySearchProvider)
          .search(category, center, fallbackName: fallbackName, cancel: cancel);
      if (seq != _seq || !ref.mounted) return;
      // Simpanan lama tidak dicache dalam sesi supaya ketukan seterusnya mencuba pelayan semula.
      if (!result.fromCache) _cache[key] = result.places;
      state = _ready(
        label,
        result.places,
        nearby: category,
        origin: center,
        cachedAt: result.cachedAt,
      );
    } on GeocodeFailure catch (f) {
      if (seq != _seq || !ref.mounted) return;
      state = PlaceSearchState(
        status: SearchStatus.failed,
        query: label,
        failure: f.kind,
        nearby: category,
        origin: center,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || seq != _seq || !ref.mounted) {
        return;
      }
      state = PlaceSearchState(
        status: SearchStatus.failed,
        query: label,
        failure: GeocodeFailureKind.generic,
        nearby: category,
        origin: center,
      );
    }
  }

  (NearbyCategory, GeoPoint, String, String)? _lastNearby;

  /// Cuba lagi carian terakhir selepas kegagalan.
  void retry({GeoPoint? near}) {
    final last = _lastNearby;
    if (state.nearby != null && last != null) {
      searchNearby(
        last.$1,
        center: last.$2,
        label: last.$3,
        fallbackName: last.$4,
      );
      return;
    }
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
      final ranked = ref
          .read(placeRankerProvider)
          .rank(results, query, near: near);
      _cache[_key(query, near)] = ranked;
      state = _ready(query, ranked);
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

  PlaceSearchState _ready(
    String query,
    List<Place> results, {
    NearbyCategory? nearby,
    GeoPoint? origin,
    DateTime? cachedAt,
  }) => PlaceSearchState(
    status: results.isEmpty ? SearchStatus.empty : SearchStatus.results,
    query: query,
    results: results,
    nearby: nearby,
    origin: origin,
    cachedAt: cachedAt,
  );

  // Bundar ke ~1 km (2 perpuluhan ≈ 1.1 km) supaya pergerakan kecil tidak menggugurkan cache.
  static String _roundKey(GeoPoint p) =>
      '${p.lat.toStringAsFixed(2)},${p.lng.toStringAsFixed(2)}';

  static String _key(String query, GeoPoint? near) =>
      '${query.toLowerCase()}|${near == null ? '-' : _roundKey(near)}';
}

final placeSearchControllerProvider =
    NotifierProvider.autoDispose<PlaceSearchController, PlaceSearchState>(
      PlaceSearchController.new,
    );
