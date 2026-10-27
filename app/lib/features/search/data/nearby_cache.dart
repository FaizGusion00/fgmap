import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/geo.dart';
import '../domain/nearby_category.dart';
import '../domain/place.dart';
import 'nearby_search.dart';

/// Cache berterusan hasil "berhampiran" dalam peranti.
///
/// - Segar (< [freshFor]): dipulangkan terus tanpa rangkaian (menjimatkan kuota pelayan awam).
/// - Pelayan gagal semua: hasil lama (sehingga [maxStale]) dipulangkan DITANDAI sebagai simpanan, supaya
///   pemandu masih mempunyai senarai tempat sekitar walaupun tiada liputan, dan UI memberitahu masanya.
class CachedNearbySearch implements ProgressiveNearbySearch {
  CachedNearbySearch(
    this.inner,
    this._prefs, {
    this.freshFor = const Duration(minutes: 30),
    this.maxStale = const Duration(days: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final NearbySearch inner;
  final SharedPreferences _prefs;
  final Duration freshFor;
  final Duration maxStale;
  final DateTime Function() _clock;

  static const _indexKey = 'nearby.v1.index';
  static const _maxEntries = 40;

  /// Sel ~1.1 km (0.01 darjah): hasil yang disimpan hanya digunakan semula untuk lokasi yang sangat hampir.
  static String _key(NearbyCategory category, GeoPoint c) =>
      'nearby.v1.${category.name}.${(c.lat * 100).round()}.${(c.lng * 100).round()}';

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) =>
      watch(category, center, fallbackName: fallbackName, cancel: cancel).last;

  /// Segar (< [freshFor]): satu hasil tanpa rangkaian. Lama tetapi ada: simpanan dipaparkan SERTA-MERTA
  /// (`refreshing`), kemudian digantikan oleh hasil segar apabila siap; jika pelayan gagal, simpanan
  /// ditandai sebagai simpanan lama. Tiada simpanan: hasil berperingkat daripada pelayan.
  @override
  Stream<NearbyResult> watch(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async* {
    final key = _key(category, center);
    final entry = _read(key);
    final now = _clock();

    if (entry != null && now.difference(entry.at) < freshFor) {
      yield NearbyResult(sortNearby(entry.places, center));
      return;
    }
    final stale = entry != null && now.difference(entry.at) < maxStale;
    final shown = stale ? sortNearby(entry.places, center) : const <Place>[];
    if (stale) yield NearbyResult(shown, refreshing: true);

    var gotAny = false;
    try {
      await for (final r in watchNearby(
        inner,
        category,
        center,
        fallbackName: fallbackName,
        cancel: cancel,
      )) {
        gotAny = true;
        if (!r.refreshing && r.places.isNotEmpty) {
          await _write(key, now, r.places);
        }
        // Simpanan lama sudah di skrin: jangan gantikan dengan hasil sementara yang lebih kecil.
        if (stale && r.refreshing) continue;
        yield r;
      }
    } on GeocodeFailure {
      if (stale) {
        yield NearbyResult(shown, cachedAt: entry.at);
        return;
      }
      if (gotAny) return;
      rethrow;
    }
  }

  ({DateTime at, List<Place> places})? _read(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(json['t'] as int);
      final list = json['p'];
      if (list is! List) return null;
      final places = [for (final p in list) ?_decode(p)];
      return places.isEmpty ? null : (at: at, places: places);
    } on Object {
      return null;
    }
  }

  Future<void> _write(String key, DateTime at, List<Place> places) async {
    try {
      await _prefs.setString(
        key,
        jsonEncode({
          't': at.millisecondsSinceEpoch,
          'p': [for (final p in places) _encode(p)],
        }),
      );
      final index = [
        key,
        ...(_prefs.getStringList(_indexKey) ?? const <String>[]).where(
          (k) => k != key,
        ),
      ];
      for (final old in index.skip(_maxEntries)) {
        await _prefs.remove(old);
      }
      await _prefs.setStringList(_indexKey, index.take(_maxEntries).toList());
    } on Object {
      // Cache ialah pengoptimuman; kegagalan menulis tidak boleh menggagalkan carian.
    }
  }

  static Map<String, Object?> _encode(Place p) => {
    'n': p.name,
    's': p.subtitle,
    'la': p.point.lat,
    'ln': p.point.lng,
    'c': p.category,
    'k': p.osmKey,
    't': p.osmType,
    'i': p.osmId,
  };

  static Place? _decode(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    final name = v['n'];
    final lat = v['la'];
    final lng = v['ln'];
    if (name is! String || lat is! num || lng is! num) return null;
    return Place(
      name: name,
      subtitle: v['s'] is String ? v['s'] as String : '',
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
      category: v['c'] as String?,
      osmKey: v['k'] as String?,
      osmType: v['t'] as String?,
      osmId: v['i'] is int ? v['i'] as int : null,
    );
  }
}
