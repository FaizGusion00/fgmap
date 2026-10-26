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

  /// Atribut jalan (had laju) pada server yang sama dengan [valhallaUrl]: `.../route` -> `.../trace_attributes`.
  static String get traceAttributesUrl => valhallaUrl.endsWith('/route')
      ? '${valhallaUrl.substring(0, valhallaUrl.length - '/route'.length)}/trace_attributes'
      : '$valhallaUrl/trace_attributes';

  /// Carian tempat (Photon). Pelayan awam komoot: percuma dan tanpa kunci, tetapi tertakluk kepada
  /// penggunaan wajar dan tiada SLA. Nominatim awam sengaja TIDAK digunakan: ia melarang autocomplete.
  static const photonUrl = String.fromEnvironment(
    'PHOTON_URL',
    defaultValue: 'https://photon.komoot.io/api/',
  );

  /// URL manifest peta offline yang diterbitkan oleh workflow tiles. Boleh ditukar untuk pelayan
  /// pembangunan setempat atau hos sendiri dengan `--dart-define=OFFLINE_MANIFEST_URL=...`.
  static const offlineManifestUrl = String.fromEnvironment(
    'OFFLINE_MANIFEST_URL',
    defaultValue:
        'https://github.com/FaizGusion00/fgmap/releases/download/tiles/manifest.json',
  );

  /// Pengenalan app kepada server awam. Tukar `+contact` kepada URL/e-mel sebenar sebelum lancar.
  static const userAgent = String.fromEnvironment(
    'USER_AGENT',
    defaultValue: 'FGMap/0.1 (+https://github.com/fguniversalempire/fgmap)',
  );

  static const mapStyleLight = String.fromEnvironment(
    'MAP_STYLE_LIGHT',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  static const mapStyleDark = String.fromEnvironment(
    'MAP_STYLE_DARK',
    defaultValue: 'https://tiles.openfreemap.org/styles/dark',
  );

  /// Pandangan awal: Kuala Lumpur.
  static const initialCenter = GeoPoint(3.139, 101.687);
  static const initialZoom = 11.0;
}
