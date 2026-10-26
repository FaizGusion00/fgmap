# FGMap

Aplikasi navigasi komuniti untuk Malaysia. Flutter (iOS + Android) · Go · PostgreSQL/PostGIS · OpenStreetMap +
MapLibre + Valhalla.

**Developed by Faiz Nasir · Owned by FG Universal Empire Company**
© 2026 FG Universal Empire Company. All rights reserved. Data peta © penyumbang OpenStreetMap.

Pelan projek penuh: [docs/PELAN.md](docs/PELAN.md). Dokumen ini meliputi **Fasa 0** (peta + satu laluan A→B,
hujung ke hujung).

## Susun atur

```
app/            Flutter (feature-first)
server/         Go API (chi, pgx, goose, oapi-codegen)
infra/          compose.yaml (PostGIS + Valhalla), valhalla/smoke.sh
api/openapi.yaml   Kontrak API: sumber kebenaran. Kod Go dan Dart dijana daripadanya.
docs/adr/       Rekod keputusan seni bina
```

## Keperluan

Flutter 3.41.x, Go (toolchain 1.26.10 dimuat turun automatik), Docker (≥ 8 GB untuk Valhalla), Xcode dan/atau
Android SDK. Tiada alat global lain: `oapi-codegen`, `goose` dan `govulncheck` dijalankan melalui `go tool` / `go run`.

## Mula pantas

```sh
make up        # PostGIS + Valhalla. Kali pertama: muat turun ekstrak (~240 MB) dan bina graf, ~7 minit
make migrate   # kenakan migrasi DB
make api       # Go API di :8080
make smoke     # 5 laluan rujukan Malaysia + kes negatif terhadap Valhalla

cd app
flutter run                                    # emulator Android atau simulator iOS
flutter run --dart-define=API_BASE_URL=http://<IP-LAN-MAC>:8080   # peranti fizikal
```

Tekan lama pada peta untuk memilih destinasi. Laluan dikira dari lokasi anda (atau pusat peta jika lokasi tiada).
Carian tempat menggunakan Photon di seluruh dunia dan menyimpan sehingga 10 tempat terkini pada peranti.
Di Android, pautan koordinat `geo:`, Google Maps dan Waze yang dikongsi boleh dibuka dalam FGMap untuk melihat
pratonton laluan; navigasi hanya bermula selepas pengguna menekan **Mula**.

Port hos: API `8080`, Valhalla `8002`, PostGIS `5434` (5432 dan 5433 sering digunakan oleh projek lain).

## Konfigurasi app (`--dart-define`)

| Nama | Lalai |
|---|---|
| `API_BASE_URL` | `http://10.0.2.2:8080` (Android), `http://localhost:8080` (iOS) |
| `MAP_STYLE_LIGHT` | `https://tiles.openfreemap.org/styles/liberty` |
| `MAP_STYLE_DARK` | `https://tiles.openfreemap.org/styles/fiord` |
| `OFFLINE_MANIFEST_URL` | `https://github.com/FaizGusion00/fgmap/releases/download/tiles/manifest.json` |

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
make test                                        # server + app
cd server && go test -short ./...                # tanpa Docker (langkau ujian migrasi PostGIS)
cd app && flutter test --exclude-tags golden     # tanpa golden
cd app && flutter test --tags golden             # golden (dijana pada macOS)
cd app && flutter test --update-goldens --tags golden   # kemas kini golden selepas perubahan UI yang disengajakan
```

Selepas mengubah `api/openapi.yaml` atau fail `.arb`: `make gen`. CI gagal jika kod dijana tidak sepadan.

## Nota penting

- **Geofabrik tiada ekstrak Malaysia sahaja.** Data ialah `malaysia-singapore-brunei`.
- **`postgis/postgis` hanya `amd64`.** Compose menggunakan `imresamu/postgis` (arm64 + amd64) untuk Apple Silicon.
- **Xcode 27:** sasaran iOS minimum 15.0 dan simulator hanya arm64 (lihat `app/ios/Podfile` dan `app/ios/Flutter/*.xcconfig`).
  Jika `xcode-select` masih menunjuk ke CommandLineTools, gunakan `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
  atau `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
- Log server sengaja hanya merekod laluan (path), bukan query atau body, kerana ia mengandungi koordinat pengguna.
- Pakej peta: `maplibre_gl` (lihat [ADR 0002](docs/adr/0002-flutter-map-package.md)). Hos tile:
  [ADR 0001](docs/adr/0001-tile-hosting.md).

## Belum dalam Fasa 0

Auth, laporan komuniti, WebSocket, trafik, cache laluan, circuit breaker, gaya peta tersuai,
Auto-ikut-matahari. Lihat Bahagian 18 pelan.
