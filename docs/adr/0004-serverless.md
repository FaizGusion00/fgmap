# ADR 0004: Tanpa server sendiri (menggantikan Go + PostGIS + Valhalla di server)

- Status: diterima
- Tarikh: 2026-10-26
- Menggantikan: bahagian 3, 5.2, 6 dan 7 pelan asal (Go API, PostgreSQL/PostGIS, kontrak OpenAPI)

## Konteks

Pemilik mahu app berfungsi sebaik dipasang, tanpa kos pelayan sama sekali, dan boleh dikemas kini dari dalam app.
Fasa 0 asal membina Go API di hadapan Valhalla hos sendiri; ia berfungsi, tetapi memerlukan mesin yang sentiasa hidup.

## Keputusan

Tiada server FGMap. App hanya menggunakan fail setempat dan API awam percuma:

1. **Laluan online:** server Valhalla awam FOSSGIS terus dari app. Permintaan dan penghuraian respons
   dipindahkan daripada Go ke Dart (`valhalla_codec.dart`); fixture ujian ialah respons sebenar kedua-dua server.
2. **Laluan offline:** `valhalla-mobile` (Valhalla dalam peranti) melalui plugin `packages/fgmap_valhalla`, terhadap
   pek tile yang dimuat turun. Kontrak plugin hanya `open(tar)` / `route(json)` / `close()` dengan JSON Valhalla
   mentah, supaya satu penghurai digunakan untuk online dan offline.
3. **Dasar hybrid** (`HybridRoutePlanner`): online dahulu; kegagalan sistem (rangkaian, masa tamat, 5xx, 429, 401/403)
   jatuh ke offline jika pek dipasang. "Tiada laluan" dan "permintaan tidak sah" daripada online ialah muktamad.
4. **Pek tile tanpa server:** `tools/tiles/build.sh` + `.github/workflows/tiles.yml` membina pek mingguan daripada
   Geofabrik dan menerbitkannya ke GitHub Release `tiles`. Pekerjaan berjadual ialah "server" data. Manifest mengandungi
   versi, saiz dan sha256 (pek termampat dan hasil ekstrak).
5. **Carian:** Photon awam, dengan debounce, pembatalan permintaan lapuk dan cache sesi.

## Keselamatan pek yang dimuat turun

Enjin natif memetakan fail tile ke memori, jadi manifest dianggap tidak dipercayai: skema ketat; nama fail hanya
aksara selamat (tiada laluan, `..`, URL); sha256 pek termampat disahkan sebelum ekstrak; saiz dan sha256 hasil
ekstrak disahkan sebelum pemasangan; versi Valhalla mesti sama dengan yang tertanam; pemasangan atomik dan
enjin ditutup sebelum fail diganti. Tiada URL manifest lalai selain yang ditetapkan oleh pemilik.

## Akibat

- **Tiada tempat simpan dikongsi:** laporan komuniti (polis, kemalangan) ditangguh. Pilihan masa depan: servis
  serverless percuma (Firebase/Supabase), yang bukan RM0 pada skala.
- **Kebergantungan pada server awam tanpa SLA** untuk laluan online dan carian. Mitigasi: jatuh balik offline,
  `User-Agent` yang mengenal pasti app, debounce, boleh ditukar melalui `--dart-define`. Terma FOSSGIS untuk app awam
  **belum disahkan** (halaman terma tidak dapat dibaca); semak sebelum lancar dan hos sendiri jika perlu.
- **ETA online dan offline berbeza** (data kelajuan berbeza): lencana "Offline" dipaparkan pada laluan offline.
- **Data offline hanya setepat pek terakhir** (mingguan). Online lebih segar.
- **Saiz muat turun ~254 MB** (680 MB di cakera selepas ekstrak). Pengguna disoal sebelum memuat turun pada data mudah alih.
- **iOS belum disahkan:** lihat README.
- Kod dan infra yang dibuang: `server/`, `infra/` (Compose, Valhalla server), `api/openapi.yaml`, klien Dart dijana.
