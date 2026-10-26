# ADR 0001: Hos tile peta

- Status: diterima (Fasa 0)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 4.3, 4.4, 8.5-E, 19

## Konteks

App memaparkan peta vektor melalui MapLibre. Tile vektor OSM boleh datang daripada (a) perkhidmatan awam
percuma, atau (b) hos sendiri. Server tile awam OSM tidak boleh digunakan untuk produksi.

## Keputusan

Fasa 0 hingga beta menggunakan **OpenFreeMap** (percuma, tanpa API key, tiada had paparan):

| Tema | Gaya | URL (lalai, boleh ditimpa) |
|---|---|---|
| Cerah | liberty | `https://tiles.openfreemap.org/styles/liberty` |
| Gelap | fiord | `https://tiles.openfreemap.org/styles/fiord` |

Kedua-dua URL datang daripada `AppConfig` (`--dart-define=MAP_STYLE_LIGHT=...`, `MAP_STYLE_DARK=...`).
**Tiada URL tile di-hard-code di tempat lain.** Beralih hos mesti hanya perubahan konfigurasi.

Gaya sebenar disahkan wujud dan sah, dengan sumber `openmaptiles` dan `glyphs`, bukan hanya dijangka
daripada kod status HTTP.

Gaya tersuai FGMap (cerah, gelap, "navigasi malam", Bahagian 8.1 dan 14.6) ditangguh ke Fasa 3.

## Risiko yang diketahui

1. **Tiada SLA.** OpenFreeMap dibiayai derma dan boleh berhenti atau mengehadkan penggunaan.
2. **Kemas kini mingguan.** Jalan baharu muncul pada paparan lebih lewat berbanding Valhalla yang dibina
   daripada ekstrak Geofabrik harian. Paparan dan routing boleh berbeza seketika.
3. **Gaya, fon dan sprite turut bergantung pada hos yang sama**, bukan tile sahaja.

## Syarat beralih ke hos sendiri

Mana-mana satu: gangguan OpenFreeMap yang menjejas beta; permintaan pengguna melepasi penggunaan wajar
(hubungi pengendali mereka sebelum itu berlaku); ketidakpadanan paparan/routing mengganggu pengguna.

## Pelan sandaran (BELUM disahkan; spike Fasa 0 tidak dilakukan)

Spike PMTiles dalam pelan Fasa 0 ialah item stretch dan **tidak dibuat**. Skopnya lebih besar daripada tile sahaja:

1. Jana tile OpenMapTiles untuk `malaysia-singapore-brunei` dengan Planetiler (ekstrak yang sama dengan Valhalla).
2. Hos fail `.pmtiles` di belakang CDN dengan sokongan HTTP range.
3. Hos **gaya JSON, glyph (fon) dan sprite** sendiri; gaya OpenFreeMap merujuk aset pada hos mereka.
4. Sahkan `maplibre_gl` 0.27.1 memuatkan sumber `pmtiles://` pada Android dan iOS (README pakej menyatakan
   sokongan; belum diuji di sini).

Anggaran kerja belum diukur.

## Akibat

- Fasa 0 mempunyai satu kebergantungan luar yang tidak dikawal untuk paparan peta (bukan untuk routing).
- Ujian app tidak menyentuh rangkaian tile; ia menggunakan peta palsu di belakang antara muka `MapViewConfig`.
