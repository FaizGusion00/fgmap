# ADR 0016: Paparan peta offline (PMTiles tempatan)

Status: diterima (2026-11-01); **jalur binaan belum dijalankan** (lihat "Belum disahkan"). Kod:
`features/map/domain/local_basemap_style.dart`, `features/map/data/map_style_loader.dart`,
`features/offline_maps/data/local_basemap.dart`, `offline_map_installer.dart`. Binaan: `tools/basemap/`,
`.github/workflows/tiles.yml`. Menyempurnakan "pelan sandaran" ADR 0001.

## Konteks

Pek offline (ADR 0014) hanya memuatkan data **laluan** dan **carian**. Latar peta (OpenFreeMap) masih
meminta tile, fon dan sprite daripada internet, jadi tanpa rangkaian peta kosong walaupun laluan dan
carian berfungsi. Pemilik meminta peta berfungsi sepenuhnya offline.

## Keputusan

1. **Tile dalam satu fail PMTiles, skema OpenMapTiles.**
   - Dijana oleh Planetiler daripada ekstrak Geofabrik yang sama dengan pek laluan dan indeks carian.
   - Skema OpenMapTiles dikekalkan, jadi gaya Liberty yang sama (cerah) dan `NightStyle` (malam)
     berfungsi tanpa penulisan semula.
   - Dimuat turun mentah (tile PMTiles sudah dimampatkan; gzip hanya menjimatkan beberapa peratus).
2. **MapLibre membaca fail terus; tiada pelayan setempat.**
   - Sumber gaya: `pmtiles://file:///.../basemap-<versi>.pmtiles`. `maplibre_gl` 0.27.1 membawa MapLibre
     Native Android 13.5.0 dan iOS 6.28.0, kedua-duanya dengan sokongan PMTiles.
   - Tiada soket `http://127.0.0.1` (tiada pengecualian cleartext dalam app).
   - Nama fail membawa versi supaya MapLibre tidak menggunakan direktori PMTiles yang disimpan untuk
     versi lama.
3. **Gaya, fon dan sprite dibundel dalam app (`assets/map/`, ~1 MB), bukan dimuat turun.**
   - `liberty.json` ialah gaya OpenFreeMap Liberty. `LocalBasemapStyle.build` mengganti sumber dengan fail
     PMTiles, membuang sumber raster Natural Earth jauh, dan menunjuk `glyphs` dan `sprite` ke fail.
   - Aset disalin ke `offline_maps/map_style/v1/` sekali (penanda `.ready` ditulis terakhir).
   - URL ialah `file://` penuh. Ruang dalam laluan (`Application Support` iOS) dikodkan `%20`, dan
     nama susun fon (`Noto Sans Regular`) ialah folder sebenar dengan ruang.
4. **Fon: hanya Latin dibundel; julat lain ialah fail glyph kosong yang sah.**
   - Setiap susun fon (Regular, Bold, Italic) membawa julat `0-255`, `256-511` dan `8192-8447`
     (~240 KB setiap susun).
   - 253 julat lain dijana sebagai PBF kosong (`emptyGlyphRange`). Tanpanya MapLibre menganggap julat yang
     tiada sebagai ralat dan memintanya semula pada setiap susun atur tile.
   - **Kesan:** nama dalam aksara Cina, Tamil dan Arab tidak dilukis, walaupun dalam talian, selagi
     paparan peta offline dipasang. Nama Latin (kebanyakan peta Malaysia) tidak terjejas.
5. **Satu muat turun, satu pilihan.**
   - Manifest membawa medan pilihan `basemap` {file, sizeBytes, sha256, maxZoom, schema}. Manifest lama
     dan entri rosak diabaikan (paparan peta kekal dalam talian).
   - Dipasang selepas pek laluan dan indeks carian. Kegagalannya **tidak** menggagalkan pek laluan;
     "Kemas kini" ditawarkan semula dan muat turun disambung (HTTP Range, `basemap.part`), disahkan dengan
     sha256, kemudian dipindahkan.
   - Jumlah muat turun yang dipaparkan dan amaran data mudah alih merangkumi paparan peta.
6. **Bila dipasang, gaya tempatan digunakan sentiasa (cerah dan malam), walaupun ada internet.**
   - Tidak bertukar gaya mengikut sambungan: tukar gaya di tengah navigasi mengelipkan peta dan membina
     semula semua lapisan.
   - `localBasemapProvider` dibatalkan bila pek dipasang atau dipadam, dan `mapStyleProvider` membina
     semula gaya. Jika gaya gagal dibina, jatuh ke gaya dalam talian.
7. **Binaan CI terasing.**
   - Langkah Planetiler dalam `tiles.yml` ialah `continue-on-error`. Jika ia gagal, pek laluan dan carian
     tetap diterbitkan tanpa `basemap`.
   - `tools/basemap/build.sh` menyemak sha256 jar Planetiler yang dipin (`VERSIONS`). `verify_pmtiles.py`
     menyemak PMTiles v3, jenis MVT, lapisan OpenMapTiles, liputan KL/JB/KK/Kuching dan saiz minimum
     sebelum manifest menyebutnya.

## Disahkan

- **Android (emulator arm64, MapLibre 13.5.0):** PMTiles dimuat daripada `pmtiles://file:///.../Application%20Support/...`;
  fon dan sprite dimuat daripada `file:///` dengan laluan berisi ruang; julat glyph kosong diterima tanpa
  ralat dan teks Latin dilukis. Diuji dengan sampel PMTiles skema Protomaps (satu-satunya yang boleh
  didapati tanpa menjalankan Planetiler) dan gaya ujian ringkas.
- Ujian unit: pembinaan gaya daripada Liberty sebenar (tiada URL rangkaian, ikon sprite wujud, setiap fon
  dalam gaya dibundel, malam boleh diwarnakan), penyalinan aset, pemasangan/sambung/rosak/batal/ganti versi.

## Belum disahkan

- **Planetiler belum dijalankan** (tidak dibenarkan menjalankan jar yang dimuat turun pada mesin pembangunan).
  Saiz fail sebenar, masa binaan dan bendera baris perintah belum diukur. Larian pertama `tiles.yml`
  (`workflow_dispatch`) mesti diperiksa log-nya.
- **iOS belum diuji** (tiada runtime simulator pada mesin pembangunan). Enjin teras MapLibre sama dengan
  Android; yang belum disahkan ialah pengekodan `%20` dan laluan `Application Support`.
- Gaya Liberty sebenar pada tile Planetiler Malaysia belum dilihat bersama; hanya mekanismenya yang disahkan.

## Akibat

- Muat turun pek bertambah sebanyak saiz PMTiles (belum diukur; `BASEMAP_MAXZOOM` dalam `tools/basemap/VERSIONS`
  mengawalnya, turunkan ke 13 jika terlalu besar). Had aset Release GitHub ialah 2 GiB; CI menolak ≥ 1.9 GiB.
- Di atas zum maksimum fail, MapLibre memperbesar tile (jalan kekal tajam, butiran tidak bertambah).
- Data paparan sama umur dengan pek (dibina setiap minggu) dan terhad kepada Malaysia, Singapura dan
  Brunei: di luar kawasan itu, peta kosong sehingga paparan peta offline dipadam.
- Gaya Liberty dibundel dalam app: perubahan gaya OpenFreeMap tidak sampai tanpa kemas kini app.
- Lesen gaya (BSD-3 + CC BY), fon (OFL) dan ikon (CC0) disertakan dalam halaman lesen
  (`assets/map/LICENSE-map.txt`). Atribusi "© OpenMapTiles" dipaparkan pada peta.
- Penambahbaikan kemudian: pek fon CJK/Tamil/Arab pilihan (julat dimuat turun bersama pek).
