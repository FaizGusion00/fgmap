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

## Tambahan: "Cari berhampiran" yang sebenar (versi 0.3.3, diperkukuh 0.3.4)

Chip Fuel/Food/Mosque/Toilets/Parking/Hospital sebelum ini hanya mengisi medan dengan perkataan dan menjalankan
carian NAMA ("Fuel" tidak menjumpai "Petronas"). Kini setiap chip ialah carian kategori mengikut tag OSM
di sekitar lokasi pengguna. Lapisan kebolehpercayaan (dari atas):

1. **Cache segar (30 min, dalam peranti):** hasil yang baru diperoleh untuk sel ~1 km dipulangkan terus; menjimatkan
   kuota pelayan awam.
2. **Overpass (utama):** `out tags center`, cermin berturutan (`overpass-api.de`, `overpass.private.coffee`,
   `overpass.openstreetmap.fr`; boleh ditukar melalui `OVERPASS_URLS`), satu permintaan pada satu masa, cermin yang
   terakhir berjaya dicuba dahulu, had masa keseluruhan 20 s. `remark: runtime error` dan HTML dianggap kegagalan.
3. **Nominatim (fallback):** frasa khas + `bounded=1` jika semua cermin Overpass gagal. Overpass yang berjaya tetapi
   kosong ialah jawapan sah ("tiada ... dalam OSM berdekatan"), bukan sebab untuk fallback.
4. **Simpanan lama (sehingga 30 hari):** jika semua pelayan gagal, senarai terakhir yang baik untuk kategori dan
   kawasan itu dipaparkan dengan sepanduk "Pelayan tidak dapat dicapai, hasil tersimpan dari ...", disusun semula
   mengikut jarak dari lokasi semasa. Hasil kosong tidak menimpa simpanan yang baik. Maksimum 40 entri.

Kelengkapan:
- Tag diperluas: makan (restaurant, fast_food, cafe, food_court, canteen, ice_cream); masjid/surau (place_of_worship
  muslim, building=mosque, prayer_room, dan place_of_worship bernama surau/masjid/musolla tanpa tag agama); hospital
  (`amenity` dan `healthcare`); parkir tidak persendirian/pelanggan/permit.
- Radius berperingkat (kecil dahulu, diperluas hanya jika hasil < ambang kategori, maks 30 km untuk hospital) supaya
  kawasan padat tidak terpotong oleh had 1000 elemen; hasil dari peringkat luas yang gagal tidak membuang hasil
  peringkat awal.
- Tempat tanpa nama dalam OSM (lazim bagi tandas/parkir) dilabel dengan nama kategori dan diturunkan 600 m setara;
  entri bernama sama dalam 60 m digabung. Setiap baris menunjukkan jenis, jarak, jenama/alamat jika ada.
- Tidak dipanggil semasa menaip dan tiada autocomplete. Satu ketukan = 1 hingga 3 pertanyaan.
- Had: kelengkapan akhirnya bergantung data OSM (alamat sering kosong, jam buka tiada; klinik tidak dimasukkan
  dalam "Hospital"). Ujian guna badan Overpass sintetik; pengesahan sebenar di peranti.

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
