import '../utils/geo.dart';

/// Konfigurasi masa binaan. Semua boleh ditimpa dengan `--dart-define=NAMA=nilai`.
///
/// URL gaya tile sengaja BUKAN hard-code di tempat lain: OpenFreeMap tiada SLA (Bahagian 19), jadi
/// beralih ke hos sendiri mesti hanya perubahan konfigurasi.
abstract final class AppConfig {
  /// Server Valhalla awam FOSSGIS untuk laluan online. Tiada SLA dan tertakluk kepada dasar penggunaan
  /// wajar; app jatuh balik ke enjin offline jika ia gagal. Boleh ditimpa (cth. hos sendiri kemudian).
  static const valhallaUrl = String.fromEnvironment(
    'VALHALLA_URL',
    defaultValue: 'https://valhalla1.openstreetmap.de/route',
  );

  /// Carian tempat (Photon). Pelayan awam komoot: percuma dan tanpa kunci, tetapi tertakluk kepada
  /// penggunaan wajar dan tiada SLA. Nominatim awam sengaja TIDAK digunakan: ia melarang autocomplete.
  static const photonUrl = String.fromEnvironment('PHOTON_URL', defaultValue: 'https://photon.komoot.io/api/');

  /// URL `manifest.json` pek peta offline (lihat tools/tiles). Sengaja TIADA lalai: manifest
  /// menentukan fail yang dipetakan oleh enjin natif, jadi hos mesti dipilih secara sedar (hos sendiri
  /// pada GitHub Releases atau Cloudflare R2). Kosong = ciri muat turun peta offline dimatikan.
  static const offlineManifestUrl = String.fromEnvironment(
    'OFFLINE_MANIFEST_URL',
  );

  /// Pengenalan app kepada server awam. Tukar `+contact` kepada URL/e-mel sebenar sebelum lancar.
  static const userAgent = String.fromEnvironment(
    'USER_AGENT',
    defaultValue: 'FGMap/0.1 (+https://github.com/fguniversalempire/fgmap)',
  );

  static const mapStyleLight = String.fromEnvironment(
    'MAP_STYLE_LIGHT',
    defaultValue: 'https://tiles.openfreemap.org/styles/positron',
  );

  static const mapStyleDark = String.fromEnvironment(
    'MAP_STYLE_DARK',
    defaultValue: 'https://tiles.openfreemap.org/styles/dark',
  );

  /// Pandangan awal: Kuala Lumpur.
  static const initialCenter = GeoPoint(3.139, 101.687);
  static const initialZoom = 11.0;
}
