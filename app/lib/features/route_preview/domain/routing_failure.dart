/// Kategori kegagalan mengira laluan yang difahami UI. Teks mesra ditentukan oleh UI (l10n).
enum RoutingFailureKind {
  /// Tiada laluan boleh dikira untuk titik ini (laut, luar liputan, wilayah tidak bersambung, terlalu jauh).
  noRoute,

  /// Permintaan tidak sah (bug di pihak kita; bukan salah pengguna).
  invalidRequest,

  /// Sumber online menyekat kadar permintaan.
  rateLimited,

  /// Sumber online tidak tersedia (5xx).
  unavailable,
  timeout,

  /// Tiada sambungan rangkaian.
  network,

  /// Online gagal DAN pek peta offline tidak dipasang, jadi tiada jalan keluar.
  offlineRequired,

  /// Enjin offline gagal (fail tile rosak, dsb.).
  offlineEngine,
  generic,
}

class RoutingFailure implements Exception {
  const RoutingFailure(this.kind, [this.detail]);

  final RoutingFailureKind kind;

  /// Butiran teknikal untuk log; BUKAN untuk dipaparkan kepada pengguna.
  final String? detail;

  @override
  String toString() =>
      'RoutingFailure($kind${detail == null ? '' : ': $detail'})';
}
