import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
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

/// Awalan kunci simpanan cakera hasil sepanjang laluan (dipadam oleh "padam data").
const alongRouteCachePrefix = 'along.v1.';

class AlongRouteController extends Notifier<AlongRouteState> {
  /// Hasil carian kekal sah selama ini untuk laluan yang sama (dalam memori). Data OSM jarang berubah
  /// dan carian itu mahal (pelayan awam percuma); menukar kategori dan kembali menjadi serta-merta.
  static const cacheTtl = Duration(minutes: 20);

  /// Simpanan cakera: laluan yang sama dibuka semula (cth. perjalanan pulang esok) tanpa rangkaian.
  static const diskTtl = Duration(hours: 24);
  static const _diskMax = 6;
  static const _cacheMax = 24;

  CancelToken? _cancel;
  List<GeoPoint>? _points;
  String? _routeKey;
  int _seq = 0;

  /// Kunci laluan -> kategori -> hasil; susunan sisipan = LRU.
  final _cache = <String, _CacheEntry>{};

  /// Carian gabungan (semua kategori) yang sedang berjalan untuk laluan semasa.
  Future<bool>? _allInFlight;
  String? _allKey;

  @override
  AlongRouteState build() {
    ref.onDispose(() {
      _cancel?.cancel();
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

  void _store(AlongRouteCategory c, List<AlongRoutePoi> pois, {DateTime? at}) {
    _cache.remove(_cacheKey(c));
    _cache[_cacheKey(c)] = _CacheEntry(pois, at ?? DateTime.now());
    while (_cache.length > _cacheMax) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<void> loadForRoute(
    RouteOption route, {
    AlongRouteCategory? category,
  }) async {
    final key = routeKeyOf(route.points);
    if (_routeKey != key) {
      _allInFlight = null;
      _allKey = null;
    }
    _points = route.points;
    _routeKey = key;
    _restoreFromDisk(key);
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
    final cached = _cached(cat);
    if (cached != null) {
      state = state.copyWith(
        category: cat,
        pois: cached,
        loading: false,
        clearError: true,
      );
      return;
    }
    // Senarai kategori lama dikosongkan: jangan tunjuk "R&R" di bawah cip "Minyak" yang sedang dimuat.
    state = state.copyWith(
      category: cat,
      pois: const [],
      loading: true,
      clearError: true,
    );
    final ok = await _loadAll(points);
    if (seq != _seq) return;
    final pois = _cached(cat);
    if (ok && pois != null) {
      state = state.copyWith(pois: pois, loading: false, clearError: true);
    } else {
      state = state.copyWith(
        loading: false,
        error: 'unavailable',
        pois: const [],
      );
    }
  }

  /// Satu permintaan untuk semua kategori laluan ini; dikongsi oleh semua cip yang diketuk semasa ia
  /// berjalan. Benar jika berjaya.
  Future<bool> _loadAll(List<GeoPoint> points) {
    final key = _routeKey;
    final running = _allInFlight;
    if (running != null && _allKey == key) return running;
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    _allKey = key;
    final future = () async {
      try {
        final all = await ref
            .read(alongRouteSearchProvider)
            .searchAll(
              routePoints: points,
              fallbackName: _fallback,
              cancel: token,
            );
        if (key != _routeKey || token.isCancelled) return false;
        all.forEach(_store);
        _saveToDisk(key!, all);
        return true;
      } on Object {
        return false;
      } finally {
        if (_allKey == key) _allInFlight = null;
      }
    }();
    _allInFlight = future;
    return future;
  }

  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      return null; // ujian tanpa storan
    }
  }

  void _restoreFromDisk(String key) {
    if (AlongRouteCategory.values.every((c) => _cached(c) != null)) return;
    final raw = _prefs?.getString('$alongRouteCachePrefix$key');
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(json['at']?.toString() ?? '');
      if (at == null || DateTime.now().difference(at) > diskTtl) return;
      final cats = json['cats'] as Map<String, dynamic>;
      for (final c in AlongRouteCategory.values) {
        final list = cats[c.name];
        if (list is! List) continue;
        // Cache memori bermula semula supaya TTL 20 minit tidak membuang hasil cakera yang masih sah.
        _store(c, [for (final e in list) ?AlongRoutePoi.fromJson(e)]);
      }
    } on Object {
      // rosak: abaikan
    }
  }

  void _saveToDisk(
    String key,
    Map<AlongRouteCategory, List<AlongRoutePoi>> all,
  ) {
    final prefs = _prefs;
    if (prefs == null) return;
    final value = jsonEncode({
      'at': DateTime.now().toIso8601String(),
      'cats': {
        for (final e in all.entries)
          e.key.name: [for (final p in e.value.take(80)) p.toJson()],
      },
    });
    unawaited(prefs.setString('$alongRouteCachePrefix$key', value));
    final keys =
        prefs
            .getKeys()
            .where((k) => k.startsWith(alongRouteCachePrefix))
            .toList()
          ..remove('$alongRouteCachePrefix$key');
    // Buang yang paling lama jika melebihi had (urutan kunci tidak terjamin: semak cap masa).
    if (keys.length >= _diskMax) {
      keys.sort((a, b) => _savedAt(prefs, a).compareTo(_savedAt(prefs, b)));
      for (final k in keys.take(keys.length - _diskMax + 1)) {
        unawaited(prefs.remove(k));
      }
    }
  }

  static DateTime _savedAt(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key) ?? '';
    final m = RegExp(r'"at":"([^"]+)"').firstMatch(raw);
    return DateTime.tryParse(m?.group(1) ?? '') ?? DateTime(2000);
  }

  void clear() {
    _cancel?.cancel();
    _seq++;
    _points = null;
    _routeKey = null;
    _allInFlight = null;
    _allKey = null;
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
