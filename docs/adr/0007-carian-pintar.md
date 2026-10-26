# ADR 0007: Carian destinasi pintar (ranking, Nominatim fallback, radius jalan)

- Status: diterima (disahkan dengan ujian unit/widget dan data sintetik; belum diuji dengan Photon/Nominatim sebenar kerana persekitaran pembangunan tidak boleh mencapainya)
- Tarikh: 2026-10-26
- Menambah ADR 0004 (carian = Photon awam)

## Konteks

Laporan ujian: mencari "Lotus Puncak Alam" meletakkan pin pada perhentian bas **"Lotus Puncak Alam (Opp)"**
(seberang jalan, atas jalan raya) dan bukan kedai sebenar. Punca dalam kod:

1. Hasil Photon dipaparkan mengikut susunan Photon (padanan teks sahaja); `Place` tidak membawa `osm_key`,
   `osm_type` atau saiz bangunan, jadi perhentian bas dan kedai bernama sama tidak boleh dibezakan.
2. Titik Photon dihantar mentah sebagai destinasi Valhalla tanpa `radius`; untuk bangunan besar titik tengah
   boleh paling dekat dengan jalan yang salah.
3. Hanya satu provider; jika Photon gagal atau kosong tiada jalan lain.
4. Pengguna tidak nampak jenis (pasar raya / perhentian bas) atau jarak, jadi tidak dapat menilai hasil.

Google Places ditolak: bukan "percuma selamanya" (had percuma bulanan ikut SKU sejak Mac 2025, perlu akaun
billing) dan kunci dalam APK boleh disalahgunakan tanpa proksi. LocationIQ/Geoapify memerlukan kunci dan
akaun; dikekalkan sebagai pilihan kemudian melalui antara muka `Geocoder`.

## Keputusan

1. **`Place` membawa metadata OSM** (`osmKey`, `osmType`, `osmId`, `extentDiagonalM`, `countryCode`). Sejarah
   carian kekal 5 medan, jadi data lama masih sah (tanpa metadata = tanpa radius dan jenis umum).
2. **`PlaceRanker`** (domain tulen, menentukan): skor = prior susunan Photon + padanan teks (tepat > awalan >
   semua token) + berat jenis (kedai/POI tinggi, perhentian bas -10) + bonus saiz bangunan + susut jarak
   logaritma dari `near`. Penalti 18 untuk nama `(Opp)/opposite/seberang/arah`, dan 12 lagi untuk perhentian
   yang namanya seakan POI sebenar dalam 400 m ("bayang"). Semuanya dimatikan apabila pertanyaan menyebut
   `bus/lrt/mrt/ktm/stesen/hentian/terminal/stop`. Hasil sama nama dan sejenis dalam 150 m digabung.
3. **Photon**: `limit` 20 (ranker memilih 10), `zoom=14`, `location_bias_scale=0.35`; `near` kini lokasi GPS
   pengguna jika sah (bukan sekadar pusat kamera).
4. **`FallbackGeocoder`**: Photon dahulu; jika gagal atau kosong (pertanyaan ≥3 aksara), Nominatim. Dasar
   Nominatim awam (1 req/s, tiada autocomplete, UA berpengenalan) dipatuhi dengan menunggu pengguna berhenti
   menaip (700 ms), menjarakkan permintaan ≥1.1 s dan membatalkan jika usang. Photon berjaya tetapi kosong dan
   Nominatim gagal = kosong (jujur); kedua-dua gagal = kegagalan Photon dilaporkan.
5. **Radius destinasi**: `RouteQuery.destinationRadiusM` = separuh pepenjuru bangunan/kawasan (`W/R`), dihadkan
   15-60 m, dihantar sebagai `radius` pada lokasi terakhir Valhalla (online dan offline). Titik `N` tiada radius.
6. **UI hasil**: baris kedua "Jenis · jarak" dan alamat; perhentian seberang jalan dilabel.

## Tambahan: "Cari berhampiran" yang sebenar (versi 0.3.3)

Chip Fuel/Food/Mosque/Toilets/Parking/Hospital sebelum ini hanya mengisi medan dengan perkataan dan menjalankan
carian NAMA ("Fuel" tidak menjumpai "Petronas"). Kini setiap chip ialah carian kategori mengikut tag OSM
di sekitar lokasi pengguna:

- `NearbyCategory` memetakan chip kepada tag (`amenity=fuel`; makan = restaurant/fast_food/cafe/food_court;
  masjid/surau = `place_of_worship`+`religion=muslim` atau `building=mosque`; tandas; parkir bukan persendirian;
  hospital) dan radius awal (parkir 1 km, makan 1.5 km, minyak/surau/tandas 3 km, hospital 8 km). Jika kurang 3
  hasil, radius diperluas 3x (maks 15 km).
- `OverpassNearbySearch`: Overpass API (data OSM, percuma tanpa kunci), `out tags center`, satu permintaan pada satu
  masa, cermin dicuba berturutan (`overpass-api.de`, `overpass.private.coffee`; boleh ditukar melalui
  `OVERPASS_URLS`). Dasar awam: kurang 10,000 pertanyaan sehari dan UA berpengenalan; satu ketukan = 1-2
  pertanyaan. `remark: runtime error` dan HTML dianggap kegagalan (cermin seterusnya).
- Fallback: Nominatim frasa khas + `bounded=1` jika semua cermin Overpass gagal; Overpass yang berjaya tetapi
  kosong ialah jawapan sah ("tiada ... dalam OSM berdekatan").
- Susunan: paling dekat dahulu; tempat tanpa nama dalam OSM (lazim bagi tandas/parkir) diberi penalti 600 m setara
  dan dilabel dengan nama kategori; entri bernama sama dalam 60 m digabung.
- Tidak dipanggil semasa menaip dan tiada autocomplete; hasil dicache dalam sesi (sel ~1 km).
- Had: kelengkapan bergantung data OSM (alamat sering kosong, jam buka tiada). Ujian guna badan Overpass sintetik;
  pengesahan sebenar di peranti.

## Tidak dibuat dan sebabnya

- **Mengesahkan titik teratas melalui Nominatim /lookup pada setiap pilihan:** menambah kebergantungan dan
  kependaman tanpa bukti ia lebih tepat; Photon dan Nominatim berkongsi data OSM yang sama.
- **Pintu masuk bangunan:** OSM jarang menandakan `entrance`; `radius` hanya memperbaiki pilihan jalan.
- **Pratonton peta sebelum mula:** tidak dipilih pengguna (ranking + label dahulu).
- **Penapis `osm_tag=!highway:bus_stop` pada Photon:** sokongan pada pelayan awam tidak pasti; ranker
  menurunkan, bukan membuang, supaya pengguna yang memang mahu perhentian masih menjumpainya.

## Akibat

- Ujian guna data sintetik (ditanda) untuk kes Lotus; susunan sebenar bergantung data OSM semasa. Jika
  Lotus tidak bernama sebagai POI dalam OSM, tiada ranker boleh mencipta hasil itu.
- Golden `trip_planner_golden_test` perlu dijana semula di macOS kerana baris hasil kini ada label jenis.
- Pelan jangka panjang: Photon/Nominatim hos sendiri melalui `PHOTON_URL`/`NOMINATIM_URL` (tiada perubahan kod).
