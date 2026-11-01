import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../../offline_maps/data/offline_engine_host.dart';
import '../../offline_maps/data/offline_map_store.dart';
import '../domain/offline_place.dart';

/// Indeks carian offline (SQLite FTS4) yang dimuat turun bersama pek peta. Dibuka baca-sahaja secara
/// malas pada carian pertama; [close] dipanggil sebelum pek baharu menggantikan fail.
class OfflinePlacesDb {
  OfflinePlacesDb(this._path);

  /// Laluan fail yang dipasang, atau null jika tiada.
  final Future<String?> Function() _path;

  Database? _db;
  String? _openPath;
  Future<Database?>? _opening;

  /// Ada indeks yang boleh dicari pada peranti ini?
  Future<bool> get available async => (await _database()) != null;

  Future<Database?> _database() {
    final db = _db;
    if (db != null && db.isOpen) return Future.value(db);
    return _opening ??= () async {
      try {
        final path = await _path();
        if (path == null) return null;
        final opened = await openReadOnlyDatabase(path);
        _db = opened;
        _openPath = path;
        return opened;
      } on Object catch (e) {
        logDiag('Indeks carian offline tidak dapat dibuka: $e');
        return null;
      } finally {
        _opening = null;
      }
    }();
  }

  /// Carian teks (nama, nama lain, kawasan). Kosong jika tiada indeks atau tiada padanan.
  Future<List<OfflinePlaceRow>> search(
    String text, {
    GeoPoint? near,
    int limit = 20,
  }) async {
    final match = ftsMatchQuery(text);
    if (match == null) return const [];
    final db = await _database();
    if (db == null) return const [];
    try {
      final rows = await db.rawQuery(
        'SELECT p.name, p.alt, p.kind, p.cat, p.lat, p.lng, p.area, p.rank '
        'FROM place_fts JOIN place p ON p.id = place_fts.docid '
        'WHERE place_fts MATCH ? LIMIT 400',
        [match],
      );
      return rankOfflinePlaces(
        [for (final r in rows) ?OfflinePlaceRow.fromRow(r)],
        text,
        near: near,
        limit: limit,
      );
    } on Object catch (e) {
      logDiag('Carian offline gagal: $e');
      return const [];
    }
  }

  /// Tempat kategori [cats] dalam kotak (selatan, barat, utara, timur).
  Future<List<OfflinePlaceRow>> inBox(
    List<int> cats,
    (double s, double w, double n, double e) box, {
    int limit = 500,
  }) async {
    final db = await _database();
    if (db == null || cats.isEmpty) return const [];
    final (s, w, n, e) = box;
    final rows = await db.rawQuery(
      'SELECT name, alt, kind, cat, lat, lng, area, rank FROM place '
      'WHERE cat IN (${List.filled(cats.length, '?').join(',')}) '
      'AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ? LIMIT ?',
      [...cats, s, n, w, e, limit],
    );
    return [for (final r in rows) ?OfflinePlaceRow.fromRow(r)];
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _openPath = null;
    if (db != null && db.isOpen) await db.close();
  }

  /// Fail berubah (pek baharu dipasang/dipadam): buka semula pada carian seterusnya.
  Future<void> reloadIfChanged() async {
    final path = await _path();
    if (path != _openPath) await close();
  }
}

final offlinePlacesDbProvider = Provider<OfflinePlacesDb>((ref) {
  OfflineMapStore? store;
  try {
    store = ref.watch(offlineMapStoreProvider);
  } on Object {
    // Ujian/persekitaran tanpa storan peta: tiada indeks offline.
  }
  final db = OfflinePlacesDb(
    () async => (await store?.readInstalled())?.placesPath,
  );
  ref.onDispose(() => unawaited(db.close()));
  return db;
});
