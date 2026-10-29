import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/retry_interceptor.dart';
import '../../../core/utils/geo.dart';
import '../data/nearby_search.dart';
import '../data/photon_geocoder.dart';
import '../domain/direct_destination.dart';
import '../domain/location_link.dart';
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
    this.refreshing = false,
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

  /// Benar apabila [results] sementara dan hasil lebih lengkap masih dicari.
  final bool refreshing;
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

    if (query.length < _minChars && !looksLikeDirectDestination(query)) {
      state = const PlaceSearchState();
      return;
    }

    // Koordinat / pautan dengan lat/lng: terus tanpa debounce geocoder.
    final direct = placeFromDirectQuery(query);
    if (direct != null) {
      state = _ready(query, [direct]);
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
      await for (final result in watchNearby(
        ref.read(nearbySearchProvider),
        category,
        center,
        fallbackName: fallbackName,
        cancel: cancel,
      )) {
        if (seq != _seq || !ref.mounted) return;
        // Simpanan lama tidak dicache dalam sesi supaya ketukan seterusnya mencuba pelayan semula;
        // hasil sementara juga tidak.
        if (!result.fromCache && !result.refreshing) {
          _cache[key] = result.places;
        }
        // Hasil sementara yang kosong: kekal "memuatkan" (bukan "tiada hasil") sehingga peringkat akhir.
        if (result.refreshing && result.places.isEmpty) continue;
        state = _ready(
          label,
          result.places,
          nearby: category,
          origin: center,
          cachedAt: result.cachedAt,
          refreshing: result.refreshing,
        );
      }
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
      // Pautan pendek Google: resolve redirect → lat/lng (cara "percuma" dapat koordinat Google).
      final fromLink = await _placeFromShortMapLink(query, cancel);
      if (seq != _seq || !ref.mounted) return;
      if (fromLink != null) {
        _cache[_key(query, near)] = [fromLink];
        state = _ready(query, [fromLink]);
        return;
      }

      final searchQuery = searchLabelFromMapLink(query) ?? query;
      final results = await ref
          .read(geocoderProvider)
          .search(searchQuery, near: near, cancel: cancel);
      if (seq != _seq || !ref.mounted) return;
      final ranked = ref
          .read(placeRankerProvider)
          .rank(results, searchQuery, near: near);
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

  Future<Place?> _placeFromShortMapLink(String query, CancelToken cancel) async {
    final uri = Uri.tryParse(query.trim());
    if (uri == null || !isShortMapLink(uri)) {
      // Allow bare host/path without scheme.
      final withScheme = Uri.tryParse(
        query.trim().startsWith('http') ? query.trim() : 'https://${query.trim()}',
      );
      if (withScheme == null || !isShortMapLink(withScheme)) return null;
      return _resolveShortLink(withScheme, cancel);
    }
    return _resolveShortLink(uri, cancel);
  }

  Future<Place?> _resolveShortLink(Uri uri, CancelToken cancel) async {
    try {
      final response = await ref
          .read(dioProvider)
          .headUri<Object?>(
            uri,
            cancelToken: cancel,
            options: RetryInterceptor.options(
              Options(followRedirects: true, maxRedirects: 5),
            ),
          );
      final resolved = response.realUri;
      final shared = sharedLocationFromUri(resolved);
      final point = shared?.point;
      if (point == null) {
        // Redirect kadang hanya buka nama — biar _run cari OSM dengan label.
        return null;
      }
      final label = shared?.label?.trim();
      return Place(
        name: (label != null && label.isNotEmpty)
            ? label
            : '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
        subtitle:
            '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
        point: point,
        category: 'coordinates',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return null;
    }
  }

  PlaceSearchState _ready(
    String query,
    List<Place> results, {
    NearbyCategory? nearby,
    GeoPoint? origin,
    DateTime? cachedAt,
    bool refreshing = false,
  }) => PlaceSearchState(
    status: results.isEmpty ? SearchStatus.empty : SearchStatus.results,
    query: query,
    results: results,
    nearby: nearby,
    origin: origin,
    cachedAt: cachedAt,
    refreshing: refreshing,
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
