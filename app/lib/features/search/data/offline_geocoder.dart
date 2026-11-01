import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/utils/geo.dart';
import '../domain/nearby_category.dart';
import '../domain/offline_place.dart';
import '../domain/place.dart';
import 'nearby_search.dart';
import 'offline_places_db.dart';
import 'photon_geocoder.dart';

/// Carian dalam talian (Photon/Nominatim) dengan indeks offline sebagai sandaran: tanpa internet,
/// atau bila pelayan gagal/lambat, hasil datang daripada pek peta yang dimuat turun. Bila dalam
/// talian memulangkan sedikit hasil, padanan offline yang tiada dalam senarai ditambah di hujung.
class OfflineAwareGeocoder implements Geocoder {
  OfflineAwareGeocoder(
    this._online,
    this._offline, {
    this.onlineTimeout = const Duration(seconds: 6),
    this.enrichBelow = minOnlineBeforeFill,
  });

  final Geocoder _online;
  final OfflinePlacesDb _offline;
  final Duration onlineTimeout;

  /// Jika dalam talian memberi kurang daripada ini, tambah padanan offline tanpa pendua.
  final int enrichBelow;

  /// Ambang lalai: hasil dalam talian jarang (Photon sparse di MY) digabung dengan indeks pek.
  /// Typeahead memaparkan senarai berguna (~24); isi offline sehingga gabungan cukup padat.
  static const minOnlineBeforeFill = 20;

  /// Had gabungan dalam talian + offline sebelum ranker UI memotong.
  static const maxMergedResults = 40;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    // Offline bermula serentak (milisaat); tidak menunggu rangkaian.
    final offlineFuture = _offline
        .search(query, near: near)
        .then((rows) => [for (final r in rows) r.toPlace()])
        .catchError((Object _) => const <Place>[]);
    List<Place> online;
    try {
      online = await _online
          .search(query, near: near, cancel: cancel)
          .timeout(onlineTimeout);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      final offline = await offlineFuture;
      if (offline.isNotEmpty) return offline;
      rethrow;
    } on Object {
      final offline = await offlineFuture;
      if (offline.isNotEmpty) return offline;
      rethrow;
    }
    final offline = await offlineFuture;
    if (online.isEmpty) return offline;
    if (online.length >= enrichBelow || offline.isEmpty) return online;
    final extra = [
      for (final p in offline)
        if (!online.any(
          (o) =>
              distanceMeters(o.point, p.point) < 250 ||
              (o.name.toLowerCase() == p.name.toLowerCase() &&
                  distanceMeters(o.point, p.point) < 2000),
        ))
          p,
    ];
    final room = math.max(0, maxMergedResults - online.length);
    return [...online, ...extra.take(room)];
  }
}

/// Carian kategori berdekatan daripada indeks offline. Melempar [GeocodeFailure] jika tiada indeks
/// supaya rantai sandaran beralih ke sumber seterusnya.
class OfflineNearbySearch implements NearbySearch {
  OfflineNearbySearch(this._db);

  final OfflinePlacesDb _db;

  static List<int> catsFor(NearbyCategory c) => switch (c) {
    NearbyCategory.fuel => const [OfflinePlaceCat.fuel],
    NearbyCategory.food => const [OfflinePlaceCat.food],
    NearbyCategory.mosque => const [OfflinePlaceCat.mosque],
    NearbyCategory.toilets => const [
      OfflinePlaceCat.toilets,
      OfflinePlaceCat.restArea,
    ],
    NearbyCategory.parking => const [OfflinePlaceCat.parking],
    NearbyCategory.hospital => const [OfflinePlaceCat.hospital],
  };

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    if (!await _db.available) {
      throw const GeocodeFailure(
        GeocodeFailureKind.unavailable,
        'tiada indeks',
      );
    }
    for (final radiusKm in const [3.0, 10.0, 25.0]) {
      final dLat = radiusKm / 111.32;
      final dLng = radiusKm / (111.32 * math.cos(center.lat * math.pi / 180));
      final rows = await _db.inBox(catsFor(category), (
        center.lat - dLat,
        center.lng - dLng,
        center.lat + dLat,
        center.lng + dLng,
      ));
      if (rows.length >= 5 || radiusKm == 25.0) {
        final places = [
          for (final r in rows)
            r.name.isEmpty
                ? OfflinePlaceRow(
                    name: fallbackName,
                    kind: r.kind,
                    cat: r.cat,
                    point: r.point,
                    rank: r.rank,
                    area: r.area,
                  ).toPlace()
                : r.toPlace(),
        ];
        return NearbyResult(sortNearby(places, center));
      }
    }
    return const NearbyResult([]);
  }
}
