import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/offline_models.dart';

/// Fail pek peta offline pada cakera. Satu direktori:
///
///     valhalla_tiles.tar     pek aktif (dimmap oleh enjin natif)
///     installed.json         metadata pek aktif (versi, saiz)
///     download.part          muat turun separa (boleh disambung)
///     download.json          metadata muat turun separa
///     valhalla_tiles.tar.tmp hasil ekstrak sementara sebelum dipasang
///     places.sqlite          indeks carian offline (FTS4) + places.json (versi, saiz)
///     places.part / .tmp     muat turun dan ekstrak sementara indeks
class OfflineMapStore {
  OfflineMapStore(this.dir);

  final Directory dir;

  File get _tar => File(p.join(dir.path, 'valhalla_tiles.tar'));
  File get _installedMeta => File(p.join(dir.path, 'installed.json'));
  File get partFile => File(p.join(dir.path, 'download.part'));
  File get _partMeta => File(p.join(dir.path, 'download.json'));
  File get tmpTar => File(p.join(dir.path, 'valhalla_tiles.tar.tmp'));
  File get _places => File(p.join(dir.path, 'places.sqlite'));
  File get _placesMeta => File(p.join(dir.path, 'places.json'));
  File get placesPart => File(p.join(dir.path, 'places.part'));
  File get placesTmp => File(p.join(dir.path, 'places.sqlite.tmp'));

  Future<void> ensureDir() async {
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  /// Pek yang dipasang, atau null jika tiada ATAU rosak (fail hilang/saiz tidak sepadan dengan
  /// metadata, cth. pemasangan terganggu). Pek rosak tidak dilaporkan sebagai ada supaya enjin
  /// tidak membuka tile yang terpotong.
  Future<InstalledMap?> readInstalled() async {
    try {
      if (!await _tar.exists() || !await _installedMeta.exists()) return null;
      final meta = jsonDecode(await _installedMeta.readAsString());
      if (meta is! Map<String, dynamic>) return null;
      final version = meta['version'];
      final size = meta['sizeBytes'];
      if (version is! String || size is! int) return null;
      if (await _tar.length() != size) return null;
      final map = InstalledMap(
        version: version,
        sizeBytes: size,
        tarPath: _tar.path,
      );
      final places = await _readPlaces();
      return places == null
          ? map
          : map.withPlaces(places.$1, _places.path, places.$2);
    } on Object {
      return null;
    }
  }

  /// (versi, saiz) indeks carian yang dipasang, atau null jika tiada/rosak.
  Future<(String, int)?> _readPlaces() async {
    try {
      if (!await _places.exists() || !await _placesMeta.exists()) return null;
      final meta = jsonDecode(await _placesMeta.readAsString());
      if (meta is! Map<String, dynamic>) return null;
      final version = meta['version'];
      final size = meta['sizeBytes'];
      if (version is! String || size is! int) return null;
      if (await _places.length() != size) return null;
      return (version, size);
    } on Object {
      return null;
    }
  }

  /// Pasang indeks carian yang sudah disahkan. Pemanggil MESTI menutup pangkalan data dahulu.
  Future<void> installPlaces(
    File verifiedTmp, {
    required String version,
    required int sizeBytes,
  }) async {
    if (await _placesMeta.exists()) await _placesMeta.delete();
    if (await _places.exists()) await _places.delete();
    await verifiedTmp.rename(_places.path);
    await _placesMeta.writeAsString(
      jsonEncode({'version': version, 'sizeBytes': sizeBytes}),
      flush: true,
    );
  }

  Future<void> discardPlacesPartial() async {
    for (final f in [placesPart, placesTmp]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Menukar pek aktif secara atomik: [verifiedTmp] (sudah disahkan) menjadi pek aktif. Pemanggil
  /// MESTI menutup enjin natif dahulu supaya fail lama tidak lagi dimmap.
  Future<InstalledMap> install(
    File verifiedTmp, {
    required String version,
    required int sizeBytes,
  }) async {
    // Metadata lama dibuang dahulu: jika proses terhenti di tengah, readInstalled() melaporkan
    // "tiada" (selamat), bukan metadata lama dengan fail baharu.
    if (await _installedMeta.exists()) await _installedMeta.delete();
    if (await _tar.exists()) await _tar.delete();
    await verifiedTmp.rename(_tar.path);
    await _installedMeta.writeAsString(
      jsonEncode({'version': version, 'sizeBytes': sizeBytes}),
      flush: true,
    );
    return InstalledMap(
      version: version,
      sizeBytes: sizeBytes,
      tarPath: _tar.path,
    );
  }

  Future<void> deleteInstalled() async {
    for (final f in [_installedMeta, _tar, _placesMeta, _places]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Bait muat turun separa yang sah untuk [version]/[sha256], atau 0 (dan fail separa dibuang jika
  /// ia milik pek lain).
  Future<int> partialBytesFor(String version, String sha256) async {
    try {
      if (!await partFile.exists() || !await _partMeta.exists()) {
        await discardPartial();
        return 0;
      }
      final meta = jsonDecode(await _partMeta.readAsString());
      if (meta is Map<String, dynamic> &&
          meta['version'] == version &&
          meta['sha256'] == sha256) {
        return partFile.length();
      }
    } on Object {
      // jatuh ke pembuangan di bawah
    }
    await discardPartial();
    return 0;
  }

  Future<void> markPartial(String version, String sha256) =>
      _partMeta.writeAsString(
        jsonEncode({'version': version, 'sha256': sha256}),
        flush: true,
      );

  Future<void> discardPartial() async {
    for (final f in [partFile, _partMeta, tmpTar, placesPart, placesTmp]) {
      if (await f.exists()) await f.delete();
    }
  }
}
