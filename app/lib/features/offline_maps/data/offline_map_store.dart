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
///     basemap-<versi>.pmtiles  tile paparan peta offline + basemap.json (versi, saiz); nama fail
///                              membawa versi supaya MapLibre tidak menggunakan direktori cache lama
///     basemap.part + basemap.part.json  muat turun separa (boleh disambung)
///     map_style/             aset gaya peta yang disalin keluar daripada app (lihat LocalBasemap)
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
  File get basemapPart => File(p.join(dir.path, 'basemap.part'));
  File get _basemapPartMeta => File(p.join(dir.path, 'basemap.part.json'));
  File get _basemapMeta => File(p.join(dir.path, 'basemap.json'));

  /// Folder aset gaya peta tempatan (fon, sprite). Boleh dijana semula daripada app.
  Directory get styleAssetsDir => Directory(p.join(dir.path, 'map_style'));

  File _basemapFile(String version) =>
      File(p.join(dir.path, 'basemap-$version.pmtiles'));

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
      final basemap = await _readBasemap();
      var full = map;
      if (places != null) {
        full = full.withPlaces(places.$1, _places.path, places.$2);
      }
      if (basemap != null) {
        full = full.withBasemap(basemap.$1, basemap.$3, basemap.$2);
      }
      return full;
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

  /// (versi, saiz, laluan) tile paparan peta yang dipasang, atau null jika tiada/rosak.
  Future<(String, int, String)?> _readBasemap() async {
    try {
      if (!await _basemapMeta.exists()) return null;
      final meta = jsonDecode(await _basemapMeta.readAsString());
      if (meta is! Map<String, dynamic>) return null;
      final version = meta['version'];
      final size = meta['sizeBytes'];
      if (version is! String || size is! int) return null;
      final file = _basemapFile(version);
      if (!await file.exists() || await file.length() != size) return null;
      return (version, size, file.path);
    } on Object {
      return null;
    }
  }

  /// Pasang tile paparan peta yang sudah disahkan ([verifiedPart] dipindahkan menjadi
  /// `basemap-<versi>.pmtiles`) dan buang versi lama.
  Future<void> installBasemap(
    File verifiedPart, {
    required String version,
    required int sizeBytes,
  }) async {
    if (await _basemapMeta.exists()) await _basemapMeta.delete();
    await _deleteBasemapFiles();
    await verifiedPart.rename(_basemapFile(version).path);
    await _basemapMeta.writeAsString(
      jsonEncode({'version': version, 'sizeBytes': sizeBytes}),
      flush: true,
    );
  }

  Future<void> _deleteBasemapFiles() async {
    if (!await dir.exists()) return;
    await for (final e in dir.list()) {
      if (e is File && RegExp(r'basemap-.*\.pmtiles$').hasMatch(e.path)) {
        await e.delete();
      }
    }
  }

  /// Bait muat turun separa tile paparan peta yang sah untuk [version]/[sha256], atau 0 (dan fail
  /// separa dibuang jika milik versi lain).
  Future<int> basemapPartialBytesFor(String version, String sha256) async {
    try {
      if (await basemapPart.exists() && await _basemapPartMeta.exists()) {
        final meta = jsonDecode(await _basemapPartMeta.readAsString());
        if (meta is Map<String, dynamic> &&
            meta['version'] == version &&
            meta['sha256'] == sha256) {
          return await basemapPart.length();
        }
      }
    } on Object {
      // jatuh ke pembuangan di bawah
    }
    await discardBasemapPartial();
    return 0;
  }

  Future<void> markBasemapPartial(String version, String sha256) =>
      _basemapPartMeta.writeAsString(
        jsonEncode({'version': version, 'sha256': sha256}),
        flush: true,
      );

  Future<void> discardBasemapPartial() async {
    for (final f in [basemapPart, _basemapPartMeta]) {
      if (await f.exists()) await f.delete();
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
    for (final f in [
      _installedMeta,
      _tar,
      _placesMeta,
      _places,
      _basemapMeta,
    ]) {
      if (await f.exists()) await f.delete();
    }
    await _deleteBasemapFiles();
    if (await styleAssetsDir.exists()) {
      await styleAssetsDir.delete(recursive: true);
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
