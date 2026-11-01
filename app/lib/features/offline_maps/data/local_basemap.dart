import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../map/domain/local_basemap_style.dart';
import '../../../core/utils/log.dart';
import 'offline_engine_host.dart';
import 'offline_map_store.dart';

/// Paparan peta offline yang sedia digunakan: fail tile + aset gaya pada cakera.
class LocalBasemap {
  const LocalBasemap({
    required this.version,
    required this.pmtilesPath,
    required this.assetsDir,
    required this.styleTemplate,
  });

  final String version;
  final String pmtilesPath;

  /// Folder fon dan sprite yang telah disalin keluar daripada app.
  final String assetsDir;

  /// Gaya Liberty mentah (dibundel); diubah oleh [LocalBasemapStyle.build].
  final String styleTemplate;
}

/// Menyalin aset gaya (fon, sprite) daripada bundle app ke cakera: MapLibre membacanya melalui
/// `file://`, bukan melalui pemuat aset Flutter.
class LocalBasemapAssets {
  LocalBasemapAssets(this._bundle);

  final AssetBundle _bundle;

  /// Naikkan bila fon/sprite dalam `assets/map/` berubah, supaya salinan lama dijana semula.
  static const version = 1;

  static const _root = 'assets/map';
  static const _marker = '.ready';

  Future<String>? _pending;

  /// Memastikan aset ada dalam [dir]; mengembalikan laluan folder. Sekali sahaja setiap [version]
  /// (penanda ditulis terakhir, jadi salinan separa dijana semula). Panggilan serentak berkongsi satu
  /// kerja: dua penyalin pada folder yang sama akan merosakkan satu sama lain.
  Future<String> ensure(Directory dir) {
    final running = _pending;
    if (running != null) return running;
    final job = _ensure(dir);
    _pending = job;
    return job.whenComplete(() => _pending = null);
  }

  Future<String> _ensure(Directory dir) async {
    final target = Directory(p.join(dir.path, 'v$version'));
    final marker = File(p.join(target.path, _marker));
    if (await marker.exists()) return target.path;

    if (await dir.exists()) await dir.delete(recursive: true);
    await target.create(recursive: true);

    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    for (final asset in manifest.listAssets()) {
      if (!asset.startsWith('$_root/') || asset == '$_root/liberty.json') {
        continue;
      }
      final rel = asset.substring(_root.length + 1);
      if (rel.endsWith('.txt')) continue;
      // Folder fon dalam aset memakai `_` (tanpa ruang); MapLibre meminta nama susun fon sebenar.
      final parts = rel.split('/');
      if (parts.first == 'fonts' && parts.length > 2) {
        parts[1] = parts[1].replaceAll('_', ' ');
      }
      final file = File(p.joinAll([target.path, ...parts]));
      await file.parent.create(recursive: true);
      final data = await _bundle.load(asset);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }

    // Julat glyph yang tidak dibundel: fail kosong yang sah (lihat LocalBasemapStyle.emptyGlyphRange).
    for (final stack in LocalBasemapStyle.fontStacks) {
      final fontDir = Directory(p.join(target.path, 'fonts', stack));
      await fontDir.create(recursive: true);
      for (final range in LocalBasemapStyle.allGlyphRanges) {
        final f = File(p.join(fontDir.path, '$range.pbf'));
        if (await f.exists()) continue;
        await f.writeAsBytes(LocalBasemapStyle.emptyGlyphRange(stack, range));
      }
    }
    await marker.writeAsString('ok', flush: true);
    return target.path;
  }

  Future<String> template() => _bundle.loadString('$_root/liberty.json');
}

final localBasemapAssetsProvider = Provider<LocalBasemapAssets>(
  (ref) => LocalBasemapAssets(rootBundle),
);

/// Paparan peta offline jika dipasang; null = guna gaya dalam talian. Tidak melempar: persekitaran
/// tanpa storan peta (ujian) atau aset yang gagal disalin jatuh ke gaya dalam talian.
final localBasemapProvider = FutureProvider<LocalBasemap?>((ref) async {
  final OfflineMapStore store;
  try {
    store = ref.watch(offlineMapStoreProvider);
  } on Object {
    return null;
  }
  try {
    final installed = await store.readInstalled();
    final path = installed?.basemapPath;
    if (installed == null || path == null) return null;
    final assets = ref.read(localBasemapAssetsProvider);
    final assetsDir = await assets.ensure(store.styleAssetsDir);
    return LocalBasemap(
      version: installed.basemapVersion!,
      pmtilesPath: path,
      assetsDir: assetsDir,
      styleTemplate: await assets.template(),
    );
  } on Object catch (e) {
    logDiag('Paparan peta offline tidak dapat disediakan: $e');
    return null;
  }
});
