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

  /// Fallback carian (Nominatim awam). Hanya apabila Photon gagal atau tiada hasil: dasar Nominatim
  /// melarang autocomplete dan mengehadkan 1 permintaan sesaat. Boleh ditimpa dengan hos sendiri.
  static const nominatimUrl = String.fromEnvironment(
    'NOMINATIM_URL',
    defaultValue: 'https://nominatim.openstreetmap.org/search',
  );

  /// Cermin Overpass (dipisahkan koma) untuk carian kategori berdekatan. Percuma tanpa kunci; dasar
  /// penggunaan: kurang 10,000 pertanyaan sehari, UA berpengenalan, tiada permintaan selari. Dicuba
  /// mengikut tertib; cermin seterusnya hanya apabila yang sebelumnya gagal.
  static const _overpassRaw = String.fromEnvironment(
    'OVERPASS_URLS',
    defaultValue:
        'https://overpass-api.de/api/interpreter,'
        'https://overpass.private.coffee/api/interpreter,'
        'https://overpass.openstreetmap.fr/api/interpreter',
  );
  static List<String> get overpassUrls => _overpassRaw
      .split(',')
      .map((u) => u.trim())
      .where((u) => u.isNotEmpty)
      .toList();

  /// Audius: API awam tanpa kunci untuk cari dan strim muzik (lesen Audius Open Music License
  /// membenarkan "Music Players" pihak ketiga menstrim). Hos kandungan (`creatornode`) ialah
  /// lencongan 302 daripada `/stream`. Hanya `app_name` diperlukan.
  static const audiusUrl = String.fromEnvironment(
    'AUDIUS_URL',
    defaultValue: 'https://api.audius.co',
  );

  /// Waktu solat rasmi JAKIM (e-Solat) melalui API komuniti WaktuSolat (percuma, tanpa kunci). Ia
  /// menukar koordinat kepada zon JAKIM dan memulangkan jadual bulanan rasmi. Hanya koordinat
  /// dibundarkan ~1 km, tahun dan bulan dihantar. Jika gagal, waktu dikira pada telefon.
  static const waktuSolatUrl = String.fromEnvironment(
    'WAKTU_SOLAT_URL',
    defaultValue: 'https://api.waktusolat.app',
  );

  /// Nama app yang dihantar kepada Audius (dasar: setiap app pengeluaran menghantar nama unik).
  static const audiusAppName = 'FGMaps';

  /// Apple Music (iOS, MusicKit): lagu penuh untuk pelanggan. MATI secara lalai di semua build: ia
  /// memerlukan keahlian berbayar Apple Developer Program (untuk mengaktifkan perkhidmatan MusicKit
  /// pada App ID) dan telefon dengan langganan Apple Music. Hidupkan dengan `--dart-define=APPLE_MUSIC=true`
  /// hanya selepas itu ada; jika tidak, kad "Sambung Apple Music" menjadi jalan buntu. Tiada kesan di
  /// Android.
  static const appleMusicEnabled = bool.fromEnvironment('APPLE_MUSIC');

  /// Cermin Radio Browser (pangkalan data stesen radio komuniti, percuma tanpa kunci). Dasar: UA
  /// berpengenalan, jangan guna satu pelayan sahaja. Dicuba mengikut tertib seperti Overpass.
  static const _radioBrowserRaw = String.fromEnvironment(
    'RADIO_BROWSER_URLS',
    defaultValue:
        'https://de1.api.radio-browser.info,'
        'https://fi1.api.radio-browser.info,'
        'https://at1.api.radio-browser.info',
  );
  static List<String> get radioBrowserUrls => _radioBrowserRaw
      .split(',')
      .map((u) => u.trim())
      .where((u) => u.isNotEmpty)
      .toList();

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
    defaultValue: 'FGMap/0.5 (+https://github.com/FaizGusion00/fgmap)',
  );

  /// Carian fatwa percuma deen.ai (FGMuslim AI — sandaran). Tiada kunci.
  static const deenApiUrl = String.fromEnvironment(
    'DEEN_API_URL',
    defaultValue: 'https://api.deen.ai',
  );

  /// Jawapan RAG berpetikan islamic.app (FGMuslim AI — utama). Tiada kunci; had rate.
  static const islamicAppApiUrl = String.fromEnvironment(
    'ISLAMIC_APP_API_URL',
    defaultValue: 'https://api.islamic.app',
  );

  static const mapStyleLight = String.fromEnvironment(
    'MAP_STYLE_LIGHT',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  static const mapStyleDark = String.fromEnvironment(
    'MAP_STYLE_DARK',
    defaultValue: 'https://tiles.openfreemap.org/styles/dark',
  );

  /// Gaya asas untuk gaya malam. Diwarnakan semula dalam app (NightStyle), jadi mestilah gaya vektor
  /// skema OpenMapTiles. Liberty ialah gaya rasmi OpenFreeMap yang pasti wujud; gaya `dark` hanya
  /// sandaran apabila pengambilan atau penghuraian gagal.
  static const mapStyleNightBase = String.fromEnvironment(
    'MAP_STYLE_NIGHT_BASE',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  /// Titik akhir yang bukan HTTPS. Dalam build release semuanya mesti HTTPS (data lokasi dan pertanyaan
  /// tidak boleh dihantar tanpa penyulitan); `--dart-define` dengan `http://` hanya untuk pembangunan
  /// (cth. pelayan pek tile setempat). Pemanggil melempar ralat dalam release jika senarai ini tidak kosong.
  static List<String> insecureEndpoints() => insecureOf({
    'VALHALLA_URL': valhallaUrl,
    'PHOTON_URL': photonUrl,
    'NOMINATIM_URL': nominatimUrl,
    'OVERPASS_URLS': overpassUrls.join(','),
    'AUDIUS_URL': audiusUrl,
    'WAKTU_SOLAT_URL': waktuSolatUrl,
    'RADIO_BROWSER_URLS': radioBrowserUrls.join(','),
    'OFFLINE_MANIFEST_URL': offlineManifestUrl,
    'MAP_STYLE_LIGHT': mapStyleLight,
    'MAP_STYLE_DARK': mapStyleDark,
    'MAP_STYLE_NIGHT_BASE': mapStyleNightBase,
  });

  /// Nama konfigurasi dalam [endpoints] yang mengandungi URL bukan-HTTPS (nilai boleh berbilang URL
  /// dipisahkan koma). Dipisahkan daripada [insecureEndpoints] supaya boleh diuji.
  static List<String> insecureOf(Map<String, String> endpoints) => [
    for (final entry in endpoints.entries)
      if (entry.value
          .split(',')
          .any((u) => u.trim().isNotEmpty && !u.trim().startsWith('https://')))
        entry.key,
  ];

  /// Pandangan awal: Kuala Lumpur.
  static const initialCenter = GeoPoint(3.139, 101.687);
  static const initialZoom = 11.0;
}
