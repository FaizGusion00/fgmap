import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../route_preview/domain/route_option.dart';
import '../data/along_route_search.dart';
import '../domain/along_route_category.dart';
import '../domain/along_route_poi.dart';

class AlongRouteState {
  const AlongRouteState({
    this.category = AlongRouteCategory.restArea,
    this.pois = const [],
    this.loading = false,
    this.error,
  });

  final AlongRouteCategory category;
  final List<AlongRoutePoi> pois;
  final bool loading;
  final String? error;

  AlongRouteState copyWith({
    AlongRouteCategory? category,
    List<AlongRoutePoi>? pois,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => AlongRouteState(
    category: category ?? this.category,
    pois: pois ?? this.pois,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class _CacheEntry {
  _CacheEntry(this.pois, this.at);

  final List<AlongRoutePoi> pois;
  final DateTime at;
}

class AlongRouteController extends Notifier<AlongRouteState> {
  /// Hasil carian kekal sah selama ini untuk laluan dan kategori yang sama. Data OSM jarang berubah
  /// dan carian itu mahal (pelayan awam percuma); menukar kategori dan kembali menjadi serta-merta.
  static const cacheTtl = Duration(minutes: 20);
  static const _cacheMax = 24;

  CancelToken? _cancel;
  CancelToken? _prefetchCancel;
  List<GeoPoint>? _points;
  String? _routeKey;
  int _seq = 0;

  /// Kunci laluan -> kategori -> hasil; susunan sisipan = LRU.
  final _cache = <String, _CacheEntry>{};

  /// Kategori yang sudah dicuba pra-muat untuk laluan semasa (sekali sahaja setiap laluan).
  final _prefetched = <String>{};

  @override
  AlongRouteState build() {
    ref.onDispose(() {
      _cancel?.cancel();
      _prefetchCancel?.cancel();
      _seq++;
    });
    return const AlongRouteState();
  }

  /// Cap jari laluan: bilangan titik, hujung dan titik tengah. Cukup membezakan laluan alternatif
  /// bagi asal-destinasi yang sama tanpa mencincang ribuan titik.
  static String routeKeyOf(List<GeoPoint> pts) {
    String f(GeoPoint p) =>
        '${p.lat.toStringAsFixed(4)},${p.lng.toStringAsFixed(4)}';
    return '${pts.length}|${f(pts.first)}|${f(pts[pts.length ~/ 2])}|${f(pts.last)}';
  }

  String _cacheKey(AlongRouteCategory c) => '$_routeKey#${c.name}';

  List<AlongRoutePoi>? _cached(AlongRouteCategory c) {
    final key = _cacheKey(c);
    final hit = _cache.remove(key);
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > cacheTtl) return null;
    _cache[key] = hit; // segarkan kedudukan LRU
    return hit.pois;
  }

  void _store(AlongRouteCategory c, List<AlongRoutePoi> pois) {
    _cache.remove(_cacheKey(c));
    _cache[_cacheKey(c)] = _CacheEntry(pois, DateTime.now());
    while (_cache.length > _cacheMax) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<void> loadForRoute(
    RouteOption route, {
    AlongRouteCategory? category,
  }) async {
    final changed = _routeKey != routeKeyOf(route.points);
    _points = route.points;
    _routeKey = routeKeyOf(route.points);
    if (changed) {
      _prefetchCancel?.cancel();
      _prefetched.clear();
    }
    await _search(route.points, category ?? state.category);
  }

  Future<void> selectCategory(AlongRouteCategory cat) async {
    final points = _points;
    if (points == null || points.length < 2) {
      state = state.copyWith(category: cat, pois: const []);
      return;
    }
    await _search(points, cat);
  }

  Future<void> _search(List<GeoPoint> points, AlongRouteCategory cat) async {
    final seq = ++_seq;
    _cancel?.cancel();

    final cached = _cached(cat);
    if (cached != null) {
      state = state.copyWith(
        category: cat,
        pois: cached,
        loading: false,
        clearError: true,
      );
      unawaited(_prefetchNext(points, cat));
      return;
    }

    _cancel = CancelToken();
    // Senarai kategori lama dikosongkan: jangan tunjuk "R&R" di bawah cip "Minyak" yang sedang dimuat.
    state = state.copyWith(
      category: cat,
      pois: const [],
      loading: true,
      clearError: true,
    );
    try {
      final pois = await ref
          .read(alongRouteSearchProvider)
          .search(
            routePoints: points,
            category: cat,
            fallbackName: _fallback(cat),
            cancel: _cancel,
          );
      if (seq != _seq) return;
      _store(cat, pois);
      state = state.copyWith(pois: pois, loading: false, clearError: true);
      unawaited(_prefetchNext(points, cat));
    } on DioException catch (e) {
      if (seq != _seq) return;
      if (e.type == DioExceptionType.cancel) return;
      state = state.copyWith(
        loading: false,
        error: 'unavailable',
        pois: const [],
      );
    } catch (_) {
      if (seq != _seq) return;
      state = state.copyWith(
        loading: false,
        error: 'unavailable',
        pois: const [],
      );
    }
  }

  /// Selepas satu kategori berjaya, muat senyap-senyap pasangannya yang paling lazim (R&R <-> minyak)
  /// supaya ketukan seterusnya serta-merta. Sekali setiap laluan; ralat diabaikan; dibatalkan apabila
  /// laluan bertukar. Hanya satu permintaan tambahan, jauh di bawah had penggunaan Overpass.
  Future<void> _prefetchNext(
    List<GeoPoint> points,
    AlongRouteCategory done,
  ) async {
    final next = switch (done) {
      AlongRouteCategory.restArea => AlongRouteCategory.fuel,
      AlongRouteCategory.fuel => AlongRouteCategory.restArea,
      _ => null,
    };
    if (next == null || _cached(next) != null) return;
    if (!_prefetched.add('$_routeKey#${next.name}')) return;
    final key = _routeKey;
    _prefetchCancel?.cancel();
    final token = _prefetchCancel = CancelToken();
    try {
      final pois = await ref
          .read(alongRouteSearchProvider)
          .search(
            routePoints: points,
            category: next,
            fallbackName: _fallback(next),
            cancel: token,
          );
      if (key == _routeKey && !token.isCancelled) _store(next, pois);
    } catch (_) {
      // pra-muat gagal: kategori dimuat apabila diketuk.
    }
  }

  void clear() {
    _cancel?.cancel();
    _prefetchCancel?.cancel();
    _seq++;
    _points = null;
    _routeKey = null;
    _prefetched.clear();
    state = const AlongRouteState();
  }

  String _fallback(AlongRouteCategory c) => switch (c) {
    AlongRouteCategory.restArea => 'R&R',
    AlongRouteCategory.fuel => 'Stesen minyak',
    AlongRouteCategory.evCharging => 'Pengecas EV',
    AlongRouteCategory.mosque => 'Surau',
    AlongRouteCategory.toilets => 'Tandas',
  };
}

final alongRouteControllerProvider =
    NotifierProvider<AlongRouteController, AlongRouteState>(
      AlongRouteController.new,
    );
