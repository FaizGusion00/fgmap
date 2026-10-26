import 'package:flutter/foundation.dart';

/// Versi Valhalla yang tertanam dalam valhalla-mobile yang digunakan app (tools/tiles/VERSIONS).
/// Pek tile yang dibina dengan versi lain DITOLAK: enjin natif boleh gagal atau memberi laluan salah.
const expectedValhallaVersion = '3.9.1';

class ManifestException implements Exception {
  const ManifestException(this.message, {this.incompatible = false});

  final String message;

  /// Benar jika manifest sah tetapi untuk versi enjin yang tidak serasi.
  final bool incompatible;

  @override
  String toString() => 'ManifestException: $message';
}

/// Penerangan pek peta offline yang diterbitkan oleh tools/tiles/build.sh.
@immutable
class OfflineManifest {
  const OfflineManifest({
    required this.region,
    required this.version,
    required this.valhalla,
    required this.file,
    required this.sizeBytes,
    required this.sha256,
    required this.extractedSizeBytes,
    required this.extractedSha256,
  });

  final String region;

  /// Versi pek (tarikh UTC YYYYMMDD). Lebih besar = lebih baharu.
  final String version;
  final String valhalla;

  /// Nama fail pek termampat, relatif kepada URL manifest.
  final String file;
  final int sizeBytes;
  final String sha256;
  final int extractedSizeBytes;
  final String extractedSha256;

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');
  static final _version = RegExp(r'^\d{8}$');
  static final _safeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  /// Mengesahkan dan menghurai manifest. Melempar [ManifestException] untuk apa-apa yang meragukan.
  factory OfflineManifest.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ManifestException('manifest bukan objek JSON');
    }

    T field<T>(String key) {
      final v = json[key];
      if (v is! T) {
        throw ManifestException('medan "$key" hilang atau jenis salah');
      }
      return v;
    }

    if (field<int>('schema') != 1) {
      throw const ManifestException('skema manifest tidak disokong');
    }

    final file = field<String>('file');
    // Nama fail sahaja: URL pek ialah sebelah manifest. Menolak laluan, "..", skema dan hos lain.
    if (!_safeName.hasMatch(file) || file.contains('..')) {
      throw ManifestException('nama fail tidak selamat: $file');
    }
    final version = field<String>('version');
    if (!_version.hasMatch(version)) {
      throw ManifestException('versi tidak sah: $version');
    }

    final sha = field<String>('sha256');
    final rawSha = field<String>('extractedSha256');
    if (!_hex64.hasMatch(sha) || !_hex64.hasMatch(rawSha)) {
      throw const ManifestException('sha256 tidak sah');
    }
    final size = field<int>('sizeBytes');
    final rawSize = field<int>('extractedSizeBytes');
    if (size <= 0 || rawSize <= 0) {
      throw const ManifestException('saiz tidak sah');
    }

    final valhalla = field<String>('valhalla');
    if (valhalla != expectedValhallaVersion) {
      throw ManifestException(
        'pek dibina untuk Valhalla $valhalla, app memerlukan $expectedValhallaVersion',
        incompatible: true,
      );
    }

    return OfflineManifest(
      region: field<String>('region'),
      version: version,
      valhalla: valhalla,
      file: file,
      sizeBytes: size,
      sha256: sha,
      extractedSizeBytes: rawSize,
      extractedSha256: rawSha,
    );
  }
}

/// Pek yang sedang dipasang pada peranti.
@immutable
class InstalledMap {
  const InstalledMap({
    required this.version,
    required this.sizeBytes,
    required this.tarPath,
  });

  final String version;
  final int sizeBytes;
  final String tarPath;
}

enum OfflineMapFailure {
  /// OFFLINE_MANIFEST_URL tidak ditetapkan.
  notConfigured,
  network,
  manifestInvalid,
  incompatible,
  checksum,
  storage,
  cancelled,
  generic,
}

class OfflineMapException implements Exception {
  const OfflineMapException(this.kind, [this.detail]);

  final OfflineMapFailure kind;
  final String? detail;

  @override
  String toString() =>
      'OfflineMapException($kind${detail == null ? '' : ': $detail'})';
}
