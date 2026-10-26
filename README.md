# FGMap

Aplikasi navigasi komuniti untuk Malaysia. **Tanpa server sendiri**: Flutter (Android + iOS) · OpenStreetMap + MapLibre +
Valhalla. Semua logik dalam app; hanya fail setempat dan API awam percuma. Kos pelayan: RM0.

**Developed by Faiz Nasir · Owned by FG Universal Empire Company**
© 2026 FG Universal Empire Company. All rights reserved. Data peta © penyumbang OpenStreetMap.

Pelan projek penuh: [docs/PELAN.md](docs/PELAN.md). Seni bina tanpa server: [ADR 0004](docs/adr/0004-serverless.md).

## Susun atur

```
app/                  Flutter (feature-first)
packages/fgmap_valhalla/   Plugin: enjin laluan Valhalla dalam peranti (Android: Kotlin; iOS: Swift/SwiftPM)
tools/tiles/          Skrip membina pek peta offline (+ pelayan dev yang menyokong Range)
.github/workflows/    app.yml (ujian), tiles.yml (bina dan terbit pek peta secara berjadual)
docs/adr/             Rekod keputusan seni bina (0009: laluan/tol/kos, 0010: keselamatan/privasi/kestabilan)
docs/legal, docs/store  Dasar Privasi/Terma (draf, perlu semakan peguam) dan jawapan borang kedai
```

## Cara ia berfungsi

| Keperluan | Sumber | Kos |
|---|---|---|
| Paparan peta | OpenFreeMap (tile vektor awam, tanpa kunci) | RM0, tiada SLA |
| Laluan (online) | Server Valhalla awam FOSSGIS: data paling segar | RM0, penggunaan wajar, tiada SLA |
| Laluan (offline) | Valhalla dalam app + pek tile Malaysia (~254 MB) dimuat turun sekali | RM0 |
| Carian tempat | Photon awam (komoot), fallback Nominatim ([ADR 0007](docs/adr/0007-carian-pintar.md)) | RM0, penggunaan wajar |
| Cari berhampiran (minyak, makan, surau...) | Overpass API (data OSM), cache dalam peranti | RM0, penggunaan wajar |
| Pek peta offline | GitHub Release `tiles`, dikemas kini mingguan oleh `tiles.yml` | RM0 |
| Harga petrol/diesel (anggaran kos minyak) | data.gov.my (CC BY 4.0), cache 24 j | RM0 |
| Plaza tol | OSM melalui Overpass; harga hanya daripada dataset yang disahkan ([docs/tolls-data.md](docs/tolls-data.md)) | RM0 |

Mod **Auto** (lalai): online dahulu; jika gagal (tiada internet, masa tamat, 5xx, disekat) dan pek offline
dipasang, laluan dikira offline dan ditanda "Offline". Jawapan online "tiada laluan" ialah muktamad.
Pilihan **Online sahaja** / **Offline sahaja** ada pada lembaran Peta offline.

## Keperluan

Flutter 3.41.x, Android SDK (untuk Android), Docker (hanya untuk membina pek tile). iOS: lihat nota di bawah.

## Mula pantas

```sh
cd app && flutter pub get
make tiles          # sekali: bina pek tile offline (~10 min, Docker); atau tunggu workflow tiles menerbitkannya
make serve-tiles    # terminal lain: sajikan pek di :8099
make run-android    # emulator Android; app memuat turun pek daripada pelayan setempat
```

Tanpa `make tiles`, app tetap berfungsi dalam mod online; muat turun peta offline memerlukan pek diterbitkan.

Tekan lama pada peta, atau gunakan pil carian, untuk memilih destinasi (dan asal). Laluan dikira dari lokasi anda
(atau pusat peta jika lokasi tiada).

## Konfigurasi app (`--dart-define`)

| Nama | Lalai |
|---|---|
| `VALHALLA_URL` | `https://valhalla1.openstreetmap.de/route` |
| `PHOTON_URL` | `https://photon.komoot.io/api/` |
| `MAP_STYLE_LIGHT` | `https://tiles.openfreemap.org/styles/liberty` |
| `MAP_STYLE_DARK` | `https://tiles.openfreemap.org/styles/dark` |
| `OFFLINE_MANIFEST_URL` | `https://github.com/FaizGusion00/fgmap/releases/download/tiles/manifest.json` |
| `USER_AGENT` | `FGMap/0.1 (+https://github.com/fguniversalempire/fgmap)`: tukar kepada URL/e-mel sebenar |

Muat turun peta offline tersedia dalam binaan biasa selepas workflow `tiles` menerbitkan Release `tiles`
yang pertama. Workflow berjalan apabila konfigurasi tile berubah, setiap minggu, atau secara manual melalui
**Actions → tiles → Run workflow**. Repo mestilah awam supaya app boleh mengambil pek tanpa log masuk.
Untuk emulator Android setempat, `make run-android` menyajikan pek `tools/tiles/out` secara automatik;
jalankan `make tiles` dahulu jika pek belum dibina.

HTTP biasa dibenarkan hanya dalam build debug/profile Android (`src/debug` dan `src/profile`); release hanya HTTPS.

## Navigasi

Selepas laluan dikira, tekan **Mula** (GPS sebenar) atau **Simulasi** (memandu sepanjang laluan tanpa GPS; berguna
untuk menguji kamera, suara dan re-route). Semasa navigasi: kad manuver dengan "kemudian ...", ETA yang dilaraskan
mengikut kelajuan sebenar, kamera 3D/2D automatik, suara BM/English dengan bunyi amaran awal, re-route automatik
apabila tersasar, dan mod kamera/suara/bahasa suara pada butang sisi. Reka bentuk: [docs/adr/0003-navigation-engine.md](docs/adr/0003-navigation-engine.md).

Main semula jejak GPX (Bahagian 8.4): `ReplayLocationSource(gpxToFixes(parseGpx(xml)))` boleh diberi kepada
`NavigationController.start(source: ...)`.

## Ujian

```sh
make test                                              # ujian app (tanpa golden)
cd app && flutter test --tags golden                   # golden (dijana pada macOS)
cd app && flutter test --update-goldens --tags golden  # kemas kini golden selepas perubahan UI yang disengajakan
make analyze
```

Ujian muat turun peta offline berjalan terhadap pelayan HTTP setempat sebenar (sambung semula dengan Range,
checksum, pembatalan, sambungan terputus). Fixture Valhalla dan Photon ialah respons sebenar yang ditangkap.

## Nota penting

- **Versi Valhalla mesti sepadan.** `valhalla-mobile` 0.6.4 membenamkan Valhalla 3.9.1; pek tile dibina dengan
  3.9.1 ([tools/tiles/VERSIONS](tools/tiles/VERSIONS)). App menolak manifest untuk versi lain. Naikkan kedua-duanya bersama.
- **Geofabrik tiada ekstrak Malaysia sahaja.** Data ialah `malaysia-singapore-brunei`.
- **ETA online dan offline boleh berbeza.** Diukur untuk KLCC→KLIA: server awam 76 min, Valhalla tempatan
  (3.5.1, data Geofabrik yang sama) 58 min. Kerana itu laluan offline ditanda "Offline".
- **Server awam tiada SLA.** FOSSGIS dan Photon dasar penggunaan wajar; app menghantar `User-Agent` yang
  mengenal pasti dirinya, melakukan debounce carian, dan jatuh balik ke offline. Hos sendiri kemudian = tukar `VALHALLA_URL`.
- **Kemas kini app:** pek peta dikemas kini dalam app. Binari app sendiri dikemas kini melalui Play Store / App Store;
  kod Dart boleh dikemas kini tanpa store melalui code push (belum disediakan).
- **iOS (belum disahkan):** enjin offline iOS ialah `packages/fgmap_valhalla/ios/fgmap_valhalla` (SwiftPM, iOS 16.4+),
  ditulis tetapi **belum dibina atau diuji**. Ia memerlukan `flutter config --enable-swift-package-manager` dan
  `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` (hook `objective_c` gagal tanpanya).
  Tanpa SwiftPM, iOS menggunakan stub CocoaPods dan app berfungsi dalam mod online sahaja.
- Pakej peta: `maplibre_gl` ([ADR 0002](docs/adr/0002-flutter-map-package.md)). Hos tile peta:
  [ADR 0001](docs/adr/0001-tile-hosting.md).

## Belum ada

Akaun, laporan yang dikongsi antara pemandu (laporan kini tempatan sahaja; perlukan tempat simpan dikongsi,
ditangguh), trafik langsung, code push. Sudah ada sejak 0.4: peta gelap kontras tinggi, tema Auto-ikut-matahari,
Rumah/Kerja dan tempat disimpan, laporan tempatan dengan amaran suara, sambutan kali pertama, halaman Tetapan penuh
([ADR 0008](docs/adr/0008-fasa-ui-peta-gelap-tema-tempat-laporan.md)). Lihat Bahagian 18 pelan.
