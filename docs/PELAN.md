# Pelan Projek: FGMap, Aplikasi Navigasi Komuniti Malaysia

> **Nama app:** **FGMap** (lihat Bahagian 15)
>
> **Developed by:** Faiz Nasir · **Owned by:** FG Universal Empire Company
>
> **Stack:** Flutter (mobile) · Go (backend) · PostgreSQL + PostGIS · OpenStreetMap + MapLibre + Valhalla
>
> **Skop:** Malaysia sahaja · **Fokus:** laju, selamat, stabil, UI/UX cantik dengan animasi lancar

> Salinan verbatim pelan asal yang menjadi rujukan "Bahagian N" dalam kod, ADR dan README. Pelaksanaan Fasa 0
> menyimpang daripadanya pada beberapa perkara kecil yang direkodkan dalam [adr/](adr/) dan README (cth. ekstrak data
> ialah Malaysia-Singapura-Brunei, `maplibre_gl` dipilih, sasaran iOS minimum 15.0).

---

## 1. Visi & Skop

**Visi:** Aplikasi navigasi yang terasa premium dan pantas, dengan laporan komuniti masa nyata (polis, kemalangan, bahaya, sesak) khusus untuk jalan-jalan Malaysia.

**Termasuk dalam MVP:**
- Peta, lokasi live, carian tempat
- Pilih laluan, navigasi belok demi belok dengan arahan suara (BM + English)
- Laporan komuniti dengan pengesahan pengguna lain
- Tema cerah / gelap / auto, tempat disimpan (Rumah / Kerja), tetapan penting (senarai penuh di Bahagian 16-17)

**Selepas MVP:** trafik live berwarna, sejarah perjalanan, mata & lencana, peta offline, CarPlay / Android Auto.

**Di luar skop (buat masa ini):** negara lain, pengangkutan awam, tempahan, iklan.

---

## 2. Prinsip Teras

| Prinsip | Maksud dalam amalan |
|---|---|
| **Laju** | Skrin peta muncul dalam saat pertama; tiada jank; respons API pantas |
| **Selamat** | Data lokasi dilindungi; auth kukuh; penyalahgunaan dikawal |
| **Stabil** | Tahan kehilangan GPS / internet; tiada crash masa memandu |
| **Selamat memandu** | UI besar, kontras tinggi, interaksi minimum semasa bergerak |
| **Cantik** | Design system konsisten, animasi bermakna (bukan hiasan kosong) |

---

## 3. Arkitektur Keseluruhan

```
┌──────────────────────┐
│   Flutter App        │  MapLibre · Riverpod · Rive/animasi
│  (iOS + Android)     │
└─────────┬────────────┘
          │ HTTPS (REST) + WebSocket (live)
┌─────────▼────────────┐        ┌───────────────────┐
│   Go API Gateway     │───────▶│  Valhalla         │  routing, map-matching
│  (chi, auth, rate    │        │  (data Malaysia)  │
│   limit, WS hub)     │        └───────────────────┘
│                      │        ┌───────────────────┐
│                      │───────▶│  Photon/Nominatim │  carian alamat/tempat
│                      │        └───────────────────┘
└─────────┬────────────┘        ┌───────────────────┐
          │                     │  Tile server /    │  tile vektor peta
          │                     │  PMTiles + CDN    │
┌─────────▼────────────┐        └───────────────────┘
│ PostgreSQL + PostGIS │  pengguna, laporan, probe, agregat trafik
│  (+ Redis pilihan)   │
└──────────────────────┘
```

**Keputusan penting:**
- Flutter bercakap dengan **satu** backend sahaja (Go). Go yang panggil Valhalla/Photon. Ini memudahkan keselamatan, cache dan rate limit.
- Laporan & trafik dihantar live melalui **WebSocket** berdasarkan kawasan (tile/geohash), bukan siaran global.
- Redis **pilihan** pada permulaan. Satu instance Go + PostgreSQL sudah cukup untuk MVP; tambah Redis bila perlu skala mendatar.

---

## 4. Tech Stack Terperinci

### 4.1 Flutter
| Keperluan | Pilihan |
|---|---|
| Peta | `maplibre` / `maplibre_gl` (semak pakej paling terkini semasa implementasi) |
| State management | Riverpod |
| Navigasi skrin | `go_router` |
| HTTP | `dio` (interceptor auth, retry, timeout) |
| WebSocket | `web_socket_channel` + lapisan reconnect sendiri |
| Lokasi | `geolocator` + foreground service (Android) / background location (iOS) |
| Suara | `flutter_tts` (arahan dijana dalam BM & English) |
| Enjin navigasi | Dart sendiri (snap ke laluan, kesan menyimpang, pencetus arahan); rujuk Ferrostar (BSD) sebagai asas algoritma. Lihat Bahagian 4.4 dan 8.5 |
| Storan setempat | `drift` (SQLite) untuk cache; `flutter_secure_storage` untuk token |
| Model / codegen | `freezed`, `json_serializable` |
| Animasi | Animasi implisit/eksplisit Flutter, `flutter_animate`, **Rive** untuk splash/onboarding/ikon animasi |
| Ralat & analitik | Sentry atau Firebase Crashlytics |
| Tetapan | `shared_preferences` (tempatan, dimuat sebelum frame pertama) + sync ke server melalui `user_settings` |
| Notifikasi & widget | `flutter_local_notifications`, FCM (push), `home_widget` (kemudian) |
| Maklumat app | `package_info_plus` (versi/build untuk skrin Tentang) |
| Ujian | `flutter_test`, golden tests, `integration_test` |

### 4.2 Go
| Keperluan | Pilihan |
|---|---|
| Router | `chi` |
| DB driver | `pgx` + `pgxpool` |
| Query | `sqlc` (SQL ditaip, selamat, laju) |
| Migrasi | `goose` atau `atlas` |
| WebSocket | `coder/websocket` |
| Auth | JWT (access) + refresh token berputar |
| Validasi | `go-playground/validator` |
| Log | `log/slog` (structured JSON) |
| Metrik & trace | Prometheus + OpenTelemetry |
| Ujian | table-driven tests + `testcontainers-go` (PostgreSQL sebenar) |

### 4.3 Data & Infra
- **PostgreSQL 16+ dengan PostGIS** (wajib: `geography(Point,4326)` + indeks GiST)
- **Valhalla** untuk routing + map-matching; data **OSM Malaysia** (extract Geofabrik), kemas kini berkala
- **Photon** (atau Nominatim) untuk geocoding
- **Tile peta:** mula dengan **OpenFreeMap** (percuma, tanpa API key); sediakan pelan sandaran hos sendiri (Planetiler + nginx / PMTiles). Lihat Bahagian 4.4
- **Docker Compose** untuk dev; kontena untuk produksi
- **Reverse proxy:** Caddy atau Nginx (TLS auto); Cloudflare di hadapan
- Hos di rantau **Malaysia / Singapura** untuk latensi rendah

### 4.4 Stack Percuma (RM0) dan Syarat Sebenar

**Matlamat:** tiada bayaran per-request untuk mana-mana API peta. Semua komponen di bawah percuma dan tanpa had panggilan. Dua kos yang tidak dapat dielak ialah **server** dan **yuran akaun store** (lihat bawah).

| Lapisan | Pilihan percuma | Syarat / risiko |
|---|---|---|
| Data jalan & POI | **OpenStreetMap** melalui ekstrak Malaysia dari **Geofabrik** (dikemas kini harian) | Lesen ODbL: wajib atribusi |
| Paparan peta (tile) | **OpenFreeMap** (awam, tiada API key, tiada had paparan; dibiayai derma) | Tiada SLA. Tile planet dikemas kini mingguan, jadi jalan baharu mungkin lambat muncul pada paparan. Sediakan sandaran hos sendiri. |
| Renderer peta | **MapLibre** (`maplibre_gl` untuk Flutter) | Sumber terbuka |
| Routing + map-matching | **Valhalla**, hos sendiri | Perisian percuma; perlu server. Menyokong trafik live yang boleh dikemas kini semasa runtime. |
| Carian alamat / tempat | **Photon** atau **Nominatim**, hos sendiri | Jangan guna Nominatim awam untuk produksi (lihat bawah) |
| Logik navigasi | Enjin Dart sendiri, rujuk **Ferrostar** (BSD) | Tiada plugin Flutter rasmi yang ditemui; lihat nota bawah |
| Backend & DB | Go + PostgreSQL/PostGIS | Percuma; perlu server |
| Push, crash report | FCM, Crashlytics / Sentry (tier percuma) | Semak had tier semasa |

**Jangan guna untuk produksi:**
- **Server tile awam OSM**: bukan untuk app produksi, kapasiti terhad.
- **Nominatim awam**: maksimum 1 permintaan sesaat untuk keseluruhan app (bukan per pengguna), wajib cache, dan autocomplete (cari semasa menaip) tidak dibenarkan. Kerana itu carian FGMap guna Photon/Nominatim **hos sendiri**.

**Nota Ferrostar:** SDK navigasi sumber terbuka (BSD) berasaskan MapLibre, dengan logik teras dalam Rust dan sokongan Valhalla. Platform yang didokumenkan: iOS, Android dan web (serta React Native). Saya tidak jumpa plugin Flutter rasmi. Pilihan: (a) bina enjin Dart sendiri sambil belajar algoritma Ferrostar (cadangan untuk MVP); (b) panggil teras Rust melalui `flutter_rust_bridge` kemudian jika perlu.

**Hos percuma (satu-satunya kos sebenar):**
- Dev: PC / laptop sendiri + Cloudflare Tunnel untuk ujian luar.
- Oracle Cloud Always Free (Arm): kuota **dikurangkan kepada 2 OCPU / 12 GB** mulai 15 Jun 2026 menurut laporan. Cukup untuk Valhalla data Malaysia + Go + PostgreSQL pada skala beta kecil, tetapi tiada jaminan kapasiti dan terma boleh berubah. Semak dokumentasi rasmi sebelum bergantung padanya.
- Selepas pengguna bertambah, server berbayar tidak dapat dielak. Rancang bajet kecil dari awal.

**Yuran akaun store (bukan API peta):** Apple Developer Program berbayar tahunan; Google Play yuran pendaftaran sekali. Semak harga semasa.

---

## 5. Struktur Projek

### 5.1 Flutter (feature-first)
```
lib/
├─ main.dart
├─ app/                    # router, tema, bootstrap, DI
├─ core/
│  ├─ network/             # dio client, interceptors, ws client
│  ├─ storage/             # drift, secure storage
│  ├─ location/            # servis GPS, penapis Kalman, adaptive sampling
│  ├─ theme/               # warna, tipografi, motion tokens
│  ├─ widgets/             # komponen kongsi (butang, sheet, chip, skeleton)
│  └─ utils/
├─ features/
│  ├─ map/                 # peta, kamera, marker kereta animasi
│  ├─ search/              # carian, cadangan, tempat terkini
│  ├─ route_preview/       # pilihan laluan, ETA, perbandingan
│  ├─ navigation/          # turn-by-turn, suara, re-route
│  ├─ reports/             # hantar & lihat laporan, undi
│  ├─ traffic/             # overlay trafik
│  ├─ profile/             # akaun, statistik, lencana
│  ├─ settings/            # semua tetapan (tema, navigasi, suara, privasi...)
│  ├─ places/              # tempat disimpan, tempat terkini, kategori
│  ├─ offline_maps/        # muat turun peta mengikut negeri
│  ├─ about/               # versi, lesen, kredit pembangun & pemilik
│  └─ onboarding/          # kebenaran, pengenalan
└─ l10n/                   # BM & English
```

Setiap feature: `data/` (repo, DTO) → `domain/` (model, use case) → `presentation/` (widget, controller).

### 5.2 Go
```
cmd/api/main.go
internal/
├─ config/
├─ http/            # handler, middleware (auth, ratelimit, recover, logging)
├─ ws/              # hub, bilik mengikut geohash, heartbeat
├─ auth/
├─ routing/         # klien Valhalla (+ cache)
├─ geocode/         # klien Photon
├─ reports/         # logik laporan, reputasi, luput
├─ traffic/         # agregasi probe → kelajuan segmen jalan
├─ store/           # kod sqlc dijana
└─ jobs/            # cron: luput laporan, agregat, bersih data lama
migrations/
api/openapi.yaml    # sumber kebenaran kontrak API
```

> **Tip kestabilan:** tulis `openapi.yaml` dahulu, jana klien Dart dan stub Go daripadanya. Frontend dan backend tak akan tersasar.

---

## 6. Skema Database (PostgreSQL + PostGIS)

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name  text,
  email         citext UNIQUE,            -- null untuk akaun anonim
  apple_sub     text UNIQUE,
  google_sub    text UNIQUE,
  reputation    int NOT NULL DEFAULT 0,
  points        int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE devices (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform    text NOT NULL,              -- ios | android
  push_token  text,
  last_seen   timestamptz
);

CREATE TYPE report_type AS ENUM
  ('police','accident','hazard','traffic_jam','road_closed','broken_down','flood',
   'fallen_tree','pothole','traffic_light_fault','speed_camera');

CREATE TABLE reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id),
  type        report_type NOT NULL,
  location    geography(Point,4326) NOT NULL,
  heading     smallint,
  confirms    int NOT NULL DEFAULT 0,
  denies      int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL,
  status      text NOT NULL DEFAULT 'active'  -- active | expired | removed
);
CREATE INDEX reports_geo_idx ON reports USING GIST (location);
CREATE INDEX reports_active_idx ON reports (expires_at) WHERE status = 'active';

CREATE TABLE report_votes (
  report_id uuid REFERENCES reports(id) ON DELETE CASCADE,
  user_id   uuid REFERENCES users(id) ON DELETE CASCADE,
  vote      smallint NOT NULL,            -- +1 sahkan, -1 tolak
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (report_id, user_id)
);

-- Probe lokasi anonim untuk trafik; dipartisi mengikut masa, dibuang selepas 7 hari
CREATE TABLE location_probes (
  id          bigserial,
  recorded_at timestamptz NOT NULL,
  location    geography(Point,4326) NOT NULL,
  speed_kmh   real,
  heading     smallint,
  anon_trip   uuid NOT NULL               -- ID perjalanan rawak, BUKAN user_id
) PARTITION BY RANGE (recorded_at);

CREATE TABLE segment_speeds (
  segment_id   bigint NOT NULL,           -- ID edge dari Valhalla / OSM way
  bucket_start timestamptz NOT NULL,      -- cth. setiap 5 minit
  avg_kmh      real NOT NULL,
  samples      int NOT NULL,
  PRIMARY KEY (segment_id, bucket_start)
);

CREATE TABLE saved_places (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label     text NOT NULL,                -- Rumah | Kerja | custom
  name      text,
  location  geography(Point,4326) NOT NULL
);

-- Tetapan disegerakkan antara peranti
CREATE TABLE user_settings (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  data        jsonb NOT NULL DEFAULT '{}',   -- tema, navigasi, suara, privasi...
  updated_at  timestamptz NOT NULL DEFAULT now()
);
```

**Prinsip privasi dalam skema:** probe trafik guna `anon_trip` yang rawak dan ditukar setiap perjalanan, tiada kaitan dengan `user_id`. Jangan simpan titik awal/akhir tepat perjalanan dalam data trafik.

---

## 7. Reka Bentuk API

**REST (`/v1`)**

| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/auth/anonymous` | Akaun peranti tanpa daftar (kurang geseran) |
| POST | `/auth/apple` · `/auth/google` | Log masuk / naik taraf akaun |
| POST | `/auth/refresh` | Putar refresh token |
| GET | `/search?q=&lat=&lng=` | Cari tempat/alamat (cache) |
| POST | `/route` | Pelan laluan + alternatif + ETA |
| GET | `/reports?bbox=` | Laporan aktif dalam kawasan |
| POST | `/reports` | Hantar laporan baru |
| POST | `/reports/{id}/vote` | Sahkan / tolak |
| POST | `/probes` | Hantar probe (batch, anonim) |
| GET/POST/DELETE | `/places/saved` | Tempat disimpan |
| GET | `/me` · PATCH `/me` | Profil, statistik |
| GET/PUT | `/me/settings` | Baca / simpan tetapan (sync antara peranti) |
| DELETE | `/me` | Padam akaun & data (wajib) |

**WebSocket (`/v1/stream`)**
- Klien subscribe kepada sel geohash sekitar lokasi semasa
- Server push: `report.created`, `report.updated`, `report.expired`, `traffic.update`
- Heartbeat 20-30s; klien reconnect dengan exponential backoff + jitter
- Mesej padat (JSON mula-mula; pertimbang Protobuf bila perlu)

**Konvensyen:** versi `/v1`, ralat seragam `{code, message}`, idempotency key untuk `POST /reports`, pagination berasaskan cursor.

---

## 8. Peta, Routing & Navigasi

### 8.1 Peta
- Style vektor **custom** (gelap & cerah) supaya rupa unik, bukan peta generik
- Lapisan: jalan, bangunan 3D ringan (zum tinggi), POI terpilih, overlay trafik, marker laporan
- Hadkan POI/label pada zum rendah untuk prestasi
- Fasa kemudian: **peta offline** (muat turun mengikut negeri)

### 8.2 Routing (Valhalla)
- Costing `auto`, dengan alternatif laluan (2-3)
- Elak tol / elak lebuh raya sebagai pilihan pengguna
- **Arahan suara:** jangan bergantung pada ayat teks Valhalla. Jana ayat **BM & English sendiri** daripada jenis manuver (`maneuver type`) dan nama jalan, supaya sebutan dan nada terkawal.
- Cache laluan popular di Go (kunci: asal/destinasi dibundarkan + pilihan)

### 8.3 Enjin navigasi (dalam app)
1. **Penapis lokasi:** tapis GPS lompat/tak tepat (Kalman ringkas + buang titik berkualiti rendah)
2. **Map-matching:** snap ke jalan terdekat berdasarkan arah; guna data laluan setempat, tidak panggil server setiap saat
3. **Pengesanan di luar laluan:** jika menyimpang melebihi ambang masa/jarak, minta **re-route** (dengan debounce)
4. **Pencetus arahan suara:** ikut jarak & kelajuan (lebih awal di lebuh raya)
5. **ETA:** kemas kini berdasarkan kelajuan semasa + agregat trafik
6. **Ketahanan:** jika internet hilang, teruskan navigasi guna laluan yang sudah dimuat turun

### 8.4 Ujian navigasi tanpa memandu
- Bina **GPX replayer**: main semula jejak GPS sebenar (Lebuhraya PLUS, jalan KL) sebagai mock location. Ini cara paling berkesan untuk uji navigasi, re-route dan kes terowong.

### 8.5 Ketepatan Lokasi & Re-route Pantas

**Realiti:** ketepatan bergantung pada tiga perkara: GPS peranti, data jalan OSM, dan algoritma app. Tiada app boleh menjamin "tidak pernah silap" (terowong, bangunan tinggi dan jalan baharu memang mencabar), tetapi reka bentuk di bawah menjadikannya sangat dekat.

**A. Lokasi yang tepat**
- Minta ketepatan tertinggi untuk navigasi (`LocationAccuracy.bestForNavigation` dalam `geolocator`); sampel lebih kerap semasa navigasi.
- Buang fix berkualiti rendah (accuracy besar) dan lompatan mustahil; tapis dengan Kalman ringkas.
- Guna kelajuan dan arah (bearing) peranti, bukan koordinat sahaja.
- Dalam terowong / isyarat hilang: **dead reckoning** (unjur kedudukan ikut kelajuan terakhir + arah laluan) sehingga GPS pulih.

**B. Snap ke jalan**
- Proses di dalam app setiap fix: unjur titik ke segmen laluan terdekat yang searah. Tiada panggilan rangkaian.
- Marker kereta dilicinkan antara fix (interpolasi), bukan melompat.

**C. Kesan salah jalan (off-route)**
- Menyimpang = jarak ke laluan melebihi ambang **adaptif** (bergantung accuracy GPS semasa) **dan** arah bertentangan, untuk 2-3 fix berturut-turut.
- Debounce supaya tidak re-route palsu di persimpangan rapat atau flyover selari.

**D. Re-route cepat**
1. Sebaik menyimpang disahkan, hantar permintaan ke server FGMap dengan **kedudukan semasa + arah (heading)**. Valhalla boleh menerima heading supaya tidak mencadangkan pusingan-U mustahil.
2. Server Valhalla berada di rantau yang sama (Malaysia/Singapura), jadi latensi kecil. **Sasaran: laluan baharu < 1.5 saat (p95).**
3. Sementara menunggu: UI terus berjalan dengan mesej "Mengira semula laluan…" dan bunyi isyarat ringkas; marker kekal licin.
4. Tanpa internet: pandu pengguna kembali ke laluan asal (garis ke titik laluan terdekat) sehingga rangkaian pulih.

**E. Data yang sentiasa dikemas kini**
- Muat turun ekstrak Malaysia dari Geofabrik setiap hari; **bina semula graf Valhalla** secara berjadual (cadangan: mingguan, harian jika masa bina mengizinkan), dengan swap tanpa downtime (bina dahulu, tukar kemudian).
- Tile paparan OpenFreeMap dikemas kini mingguan, jadi paparan dan routing mungkin berbeza seketika. Jika perbezaan mengganggu, hos tile sendiri dari ekstrak yang sama dengan Valhalla.
- Butang **"Laporkan masalah peta"** (jalan salah, arah jalan, sekatan belok) masuk baris gilir semakan. Pembetulan dibuat terus dalam OpenStreetMap supaya semua pengguna OSM turut mendapat manfaat dan data FGMap bertambah baik pada kitaran seterusnya.
- Peringkat lanjutan: gunakan jejak GPS anonim untuk mengesan jalan yang hilang atau sekatan belok yang salah.

---

## 9. Laporan Komuniti

**Aliran:**
1. Pengguna tekan butang laporan → pilih jenis (1-2 ketukan, UI besar)
2. App hantar jenis + lokasi semasa (bukan lokasi yang ditaip)
3. Server sahkan kemasukan, simpan, tolak ke pengguna sekitar melalui WebSocket
4. Pengguna lain lalu kawasan itu → prompt "Masih ada?" (Ya / Tiada)
5. `confirms` naik → masa luput dilanjutkan; `denies` melebihi ambang → laporan dibuang

**Masa luput lalai (boleh laras):** polis 1-2 jam · kemalangan 1 jam · bahaya 3 jam · sesak 30 minit · jalan ditutup 6 jam · banjir 3 jam · pokok tumbang 3 jam · lubang jalan 24 jam · lampu isyarat rosak 2 jam.

**Anti-penyalahgunaan:**
- Laporan mesti dibuat dari lokasi pengguna sebenar (semak kelajuan & kebolehpercayaan GPS)
- Had kadar per pengguna & per kawasan (cooldown)
- Skor reputasi: laporan yang disahkan menaikkan skor; laporan palsu menurunkan; reputasi rendah → laporan perlu pengesahan lebih sebelum dipaparkan
- Tiada kandungan teks bebas pada MVP (hanya jenis tetap) untuk elak spam dan kandungan berbahaya

---

## 10. Trafik Live (Fasa Lanjutan)

1. App hantar probe anonim secara batch (setiap beberapa saat semasa navigasi, hanya jika pengguna benarkan)
2. Go padankan titik ke segmen jalan (map-matching) dan agregat purata kelajuan per segmen per 5 minit
3. Bandingkan dengan kelajuan bebas aliran → hijau / kuning / merah
4. Hantar kemas kini overlay melalui WebSocket + tile trafik
5. Peringkat seterusnya: suap data trafik ke Valhalla supaya **ETA dan pemilihan laluan** sedar trafik

> Perlu ambang pengguna minimum supaya data bermakna. Sebelum itu, paparkan laporan komuniti sahaja.

---

## 11. Prestasi (Sasaran Terukur)

| Metrik | Sasaran |
|---|---|
| Frame rate | 60 fps stabil; 120 fps pada peranti yang menyokong |
| Cold start → peta kelihatan | < 2 saat pada telefon pertengahan |
| Lokasi → kamera peta | Terasa serta-merta (interpolasi, bukan lompat) |
| API p95 (bukan routing) | < 200 ms |
| Routing p95 | < 1.5 s |
| WS: laporan baru → sampai ke pengguna sekitar | < 2 s |
| Saiz app | Pantau; elak aset berat |
| Bateri semasa navigasi | Pantau & optimumkan (GPS adaptif) |

**Teknik Flutter:**
- Guna **profile mode** pada peranti sebenar (bukan emulator) untuk ukuran; Flutter DevTools untuk jank
- Gunakan `const` widget, `RepaintBoundary` pada elemen beranimasi, elak rebuild satu skrin penuh
- Pisahkan kerja berat (parse, agregat) ke `Isolate`
- Marker & overlay peta diurus melalui layer MapLibre, bukan ratusan widget Flutter
- Cache imej/ikon; aset vektor/Rive berbanding GIF
- Pre-warm peta semasa splash; elak shader jank dengan renderer moden Flutter (Impeller) dan uji pada Android sebenar

**Teknik Go/DB:**
- Indeks GiST + query `ST_DWithin`; elak `ST_Distance` pada seluruh jadual
- Connection pool dilaras; `context` timeout pada semua panggilan
- Cache (in-memory atau Redis) untuk carian & laluan popular
- Partition + retention untuk `location_probes`
- Ukur sebelum optimum: `EXPLAIN ANALYZE`, pprof

**Bateri:** kekerapan GPS adaptif (lebih jarang ketika berhenti / di lebuh raya lurus), batch hantaran rangkaian, hentikan WebSocket bila app di latar tanpa navigasi.

---

## 12. Keselamatan & Privasi

### 12.1 Auth & akses
- Akaun anonim peranti bagi permulaan lancar; naik taraf ke Apple / Google sign-in
- **Nota iOS:** jika menawarkan log masuk pihak ketiga (Google), Apple biasanya memerlukan Sign in with Apple juga. Semak garis panduan App Store semasa.
- Access token tempoh pendek (~15 min) + refresh token berputar & boleh dibatalkan; simpan dalam `flutter_secure_storage`
- Kata laluan (jika ada) guna **argon2id**
- Semua endpoint sensitif memerlukan auth; kawalan akses per sumber (pengguna hanya akses data sendiri)

### 12.2 Pengerasan API
- TLS di mana-mana; HSTS; sijil dilangganan automatik
- Rate limiting per IP & per pengguna (lebih ketat pada `/auth`, `/reports`)
- Validasi input ketat; had saiz body; timeout
- Query SQL melalui sqlc / parameterized (tiada concatenation)
- Rahsia dalam secret manager / env, bukan dalam repo
- Pertimbangkan **attestation** (Play Integrity / App Attest) untuk kurangkan bot dan app palsu
- Certificate pinning: pilihan (kompromi dengan kerumitan pusing sijil)
- Audit log untuk tindakan pentadbiran

### 12.3 Privasi lokasi (kritikal)
- Minta kebenaran lokasi secara berperingkat, dengan penjelasan jelas ("kenapa kami perlu")
- Probe trafik: anonim, rawak ID perjalanan, buang awal/akhir perjalanan, retensi pendek
- Jangan jual / kongsi data lokasi. Polisi privasi jelas.
- Sediakan **eksport & padam akaun/data** dalam app
- Malaysia: lokasi ialah data peribadi di bawah **PDPA 2010** (rujuk juga pindaan terkini). Dapatkan nasihat peguam untuk polisi privasi, persetujuan, retensi dan pemberitahuan pelanggaran data sebelum lancar.

### 12.4 Keselamatan pemandu
- Lumpuhkan input teks semasa bergerak; butang besar; gestur minimum
- Disclaimer jelas: patuhi undang-undang trafik; pelaporan oleh penumpang atau melalui suara
- Fasa kemudian: perintah suara untuk laporan ("Hei, ada road block")

---

## 13. Kestabilan, Ujian & DevOps

### 13.1 Ketahanan (resilience)
- Kehilangan GPS (terowong/bangunan): teruskan unjuran kedudukan berdasarkan kelajuan & arah sehingga isyarat pulih
- Kehilangan internet: navigasi dari laluan tersimpan; baris gilir laporan & probe, hantar semula (offline queue)
- WebSocket: reconnect automatik + sync semula laporan yang terlepas
- Server: graceful shutdown, health check, circuit breaker ke Valhalla/Photon, fallback mesej mesra
- Feature flag / remote config untuk matikan ciri bermasalah tanpa keluarkan versi baru

### 13.2 Strategi ujian
| Lapisan | Alat |
|---|---|
| Logik (map-matching, ETA, arahan) | Unit test (Dart & Go) |
| UI | Widget + golden tests (skrin utama dalam tema gelap & cerah) |
| Aliran penuh | `integration_test` + GPX replayer |
| API | Table-driven tests + PostgreSQL sebenar (testcontainers) |
| Beban | k6: REST + WebSocket (cth. 5k sambungan serentak) |
| Keselamatan | Semakan OWASP API Top 10, scan dependency (`govulncheck`, `dart pub outdated`) |
| Beta sebenar | Pemandu ujian sebenar di KL, Lembah Klang, Penang, JB |

### 13.3 CI/CD
- GitHub Actions: `flutter analyze` + test, `golangci-lint` + `go test`, build kontena
- Keluaran: Fastlane / Codemagic → TestFlight & Google Play internal testing
- Persekitaran: dev → staging → produksi; migrasi DB automatik tetapi disemak

### 13.4 Pemantauan
- Sentry/Crashlytics (app); Prometheus + Grafana (server); alert untuk ralat, latensi, ruang cakera
- Backup PostgreSQL harian + uji pemulihan secara berkala (backup tak diuji = tiada backup)

---

## 14. Reka Bentuk UI/UX & Animasi

### 14.1 Hala tuju visual
**Rasa:** moden, bersih, premium, fokus pada peta. UI "terapung" di atas peta dengan bottom sheet dan kad kaca (blur ringan), bukan app penuh menu.

**Design tokens (cadangan permulaan, boleh diubah):**

| Token | Cerah | Gelap |
|---|---|---|
| Primary | `#2563EB` | `#4F8BFF` |
| Accent (aksi/CTA) | `#00C2A8` | `#19D3B8` |
| Amaran / polis | `#F59E0B` | `#FBBF24` |
| Bahaya / kemalangan | `#EF4444` | `#F87171` |
| Latar | `#F7F9FC` | `#0B1220` |
| Permukaan (kad/sheet) | `#FFFFFF` | `#141C2E` |
| Teks utama | `#0F172A` | `#E6EAF2` |

- **Tipografi:** Plus Jakarta Sans atau Inter (bundle dalam app, jangan muat turun masa jalan). Nombor besar & berat untuk ETA/kelajuan.
- **Grid:** 4/8 pt; sudut membulat 16-24 pt pada sheet; sasaran sentuh minimum 48 pt (lebih besar semasa navigasi)
- **Ikon:** set konsisten (garis seragam) + ikon laporan khas yang beranimasi
- **Mod gelap/cerah:** Ikut sistem / Cerah / Gelap / Auto ikut matahari / Hitam AMOLED; peta & UI bertukar serentak dengan peralihan lembut (butiran: Bahagian 14.6)

### 14.2 Prinsip motion
1. **Bermakna:** setiap animasi menerangkan perubahan (dari mana, ke mana)
2. **Pantas:** 150-300 ms untuk kebanyakan peralihan; 400-600 ms hanya untuk momen istimewa
3. **Semula jadi:** guna lengkung ease-out / spring, bukan linear
4. **Tak mengganggu pemandu:** animasi dikurangkan semasa bergerak laju
5. **Hormati "Reduce Motion"** sistem; sediakan versi statik
6. **Konsisten:** satu set token durasi & lengkung dalam `core/theme/motion.dart`

### 14.3 Animasi utama (yang buat app terasa "gempak")
- **Marker kereta:** bergerak licin antara titik GPS (interpolasi + putaran arah dilicinkan), bukan melompat
- **Kamera navigasi:** ikut kereta, condong (tilt) + zum mengikut kelajuan; peralihan lembut bila menyimpang atau zum keluar
- **Lukisan laluan:** garisan laluan "dilukis" dari asal ke destinasi ketika pratonton; laluan alternatif pudar kelabu
- **Bottom sheet:** snap 3 tahap (peek / separuh / penuh) dengan fizik spring; kandungan berubah mengikut tahap
- **Kad manuver:** slaid + skala ringan bila belok seterusnya berubah; ikon anak panah beranimasi
- **Butang laporan:** menu jejari (radial) yang mekar dengan stagger; haptic ringan semasa pilih
- **Marker laporan:** muncul dengan "pop" kecil; pulse perlahan pada laporan baru; pudar bila luput
- **Peralihan skrin:** shared element / Hero dari kad tempat → pratonton laluan
- **Loading:** skeleton shimmer, bukan spinner bulat di mana-mana
- **Onboarding & splash:** animasi Rive ringan (logo, ilustrasi kebenaran lokasi)
- **Mikro-interaksi:** butang ada tindak balas tekan (skala 0.97), toggle bersprinkle, haptic selektif
- **Mod malam automatik:** peralihan warna lembut bila masuk terowong / matahari terbenam

### 14.4 Skrin utama
1. Splash → Onboarding (nilai app + kebenaran lokasi dengan penjelasan)
2. **Peta utama:** carian terapung, butang lokasi/kompas, butang laporan, Rumah/Kerja pantas
3. Carian: cadangan live, tempat terkini, kategori (petrol, makan, masjid)
4. **Pratonton laluan:** 2-3 pilihan, ETA, jarak, tol, amaran trafik; butang "Mula"
5. **Navigasi:** kad manuver besar, ETA/kelajuan/had laju, butang laporan, mute, ringkasan laluan
6. Ketibaan: ringkasan perjalanan + ucapan + prompt simpan tempat
7. Laporan: pemilih jenis + pengesahan "Masih ada?"
8. Profil: statistik, lencana, tetapan (unit, suara, tema, privasi)
9. Tetapan privasi: kawalan data, eksport, padam akaun

### 14.5 Responsif & boleh akses
- **Telefon (portrait & landscape):** susun atur adaptif; landscape navigasi letak kad manuver di tepi
- **Tablet / lipat:** panel carian di sisi, peta penuh di sebelah
- Sokong saiz teks sistem (Dynamic Type), kontras WCAG AA minimum, label Semantics untuk pembaca skrin
- Penjagaan "safe area", notch, dan gestur navigasi Android/iOS
- **Bahasa:** Bahasa Melayu (lalai) + English; sedia untuk tambah Mandarin / Tamil kemudian
- **Dalam kereta (kemudian):** CarPlay & Android Auto (CarPlay memerlukan kelayakan / entitlement daripada Apple; mohon awal)

---

### 14.6 Tema Cerah & Gelap (Pelaksanaan)

**Pilihan untuk pengguna:**
- **Ikut sistem** (lalai) · **Cerah** · **Gelap** · **Auto ikut matahari**
- Auto ikut matahari: tukar ke gelap bila matahari terbenam di lokasi semasa. Waktu dikira dari koordinat dengan formula solar, jadi tiada panggilan rangkaian.
- Pilihan tambahan **Hitam AMOLED**: latar hitam tulen, jimat bateri pada skrin OLED dan kurang silau malam hari.

**Pelaksanaan Flutter:**
- Material 3 `ThemeData` untuk cerah & gelap, ditambah `ThemeExtension` untuk token khas (warna trafik, warna jenis laporan, permukaan kaca). Tiada warna hard-coded dalam widget.
- Pilihan tema dibaca **sebelum frame pertama** (semasa splash) supaya tiada kilat putih bila app dibuka dalam mod gelap.
- Peralihan tema dianimasikan lembut (~300 ms). Status bar, navigation bar, ikon app dan splash ada varian cerah/gelap.

**Peta (tiga style):**
- **Cerah**: jalan jelas, POI ringan
- **Gelap**: kontras selesa untuk malam
- **Navigasi malam**: jalan lebih menonjol, label lebih besar, kurang silau
- Tukar style dengan peralihan lembut (cross-fade) dan elak muat semula penuh tile. Sahkan pada peranti sebenar.

**Ujian:** golden test setiap skrin utama dalam cerah, gelap dan AMOLED; semak kontras WCAG AA pada ketiga-tiganya.

---

## 15. Identiti, Nama & Kredit

### 15.1 Cadangan nama (belum disemak ketersediaan)

| Nama | Maksud | Kelebihan | Nota |
|---|---|---|---|
| **Tuju** | tujuan / destinasi | Pendek, mudah sebut, nada positif | Semak konflik nama |
| **Hala** | arah / haluan | Pendek, catchy, jelas kaitan navigasi | Mungkin ada produk lain guna nama ini; semak |
| **Lorong** | lane / laluan kecil | Unik, terasa Malaysia | Lebih panjang |
| **Arah** | direction | Sangat jelas | Terlalu generik, susah dilindungi sebagai jenama |
| **LajuGo** | laju + go | Campuran BM-English, jelas fungsi | Kurang rasa premium |

**Keputusan: FGMap.** Nama ini mengaitkan app dengan jenama syarikat (FG) dan terus jelas fungsinya (peta). Nama lain di atas disimpan sebagai cadangan. Semak ketersediaan FGMap di MyIPO, App Store, Play Store, domain dan handle sosial sebelum logo dan kempen dibuat.

### 15.2 Kriteria pemilihan nama
- Pendek (6 huruf atau kurang) dan mudah disebut dalam BM, English, Mandarin dan Tamil
- Tiada maksud buruk dalam bahasa utama Malaysia
- Tidak menyerupai Waze, Google Maps atau jenama navigasi sedia ada
- Domain (`.com` / `.my`), handle sosial, nama di App Store dan Play Store tersedia
- Semak pendaftaran jenama di **MyIPO** (kelas perisian / aplikasi mudah alih) sebelum membuat logo dan kempen

### 15.3 Kredit & pemilikan

- **Developed by:** Faiz Nasir
- **Owned by:** FG Universal Empire Company

**Dipaparkan di:**
- Skrin **Tentang** dalam Tetapan (lihat Bahagian 17)
- Footer kecil pada splash / skrin loading (pilihan)
- Butiran listing App Store dan Play Store
- Polisi Privasi dan Terma Perkhidmatan

**Teks cadangan:**
> © 2026 FG Universal Empire Company. Developed by Faiz Nasir. All rights reserved.
> Data peta © penyumbang OpenStreetMap.

**Perkara organisasi:**
- Daftar akaun pembangun Apple dan Google atas nama syarikat. Akaun organisasi biasanya memerlukan nombor D-U-N-S dan dokumen syarikat; semak keperluan terkini kerana ia boleh berubah.
- Letak repositori kod di bawah organisasi syarikat.
- Sediakan perjanjian bertulis tentang pemilikan kod / IP antara pembangun dan syarikat (rujuk peguam).

---

## 16. Ciri-Ciri Aplikasi

**Keutamaan:** **MVP** (ada semasa beta) · **Selepas MVP** (versi 1.x) · **Kemudian** (peta hala tuju)

### 16.1 Navigasi & laluan
| Ciri | Keutamaan | Nota |
|---|---|---|
| Navigasi belok demi belok + suara BM/English | MVP | Teras |
| Pilihan laluan: terpantas / terpendek / elak tol / elak lebuh raya | MVP | Valhalla menyokong pilihan costing |
| Laluan alternatif (2-3) | MVP | |
| Had laju + amaran bila melebihi | MVP | Data had laju OSM tidak lengkap; tunjuk bila ada |
| Mod kenderaan **motosikal** | Selepas MVP | Sangat relevan di Malaysia; Valhalla ada costing motosikal |
| Mod lori / van | Kemudian | |
| Berbilang perhentian | Selepas MVP | |
| Kongsi ETA live dengan keluarga (pautan sementara) | Selepas MVP | Perlu token kongsi di backend |
| Anggaran kos tol | Kemudian | Perlu dataset tol sendiri |
| Panduan lorong (lane guidance) | Kemudian | Bergantung kualiti data |
| Cadangan masa bertolak | Kemudian | Perlu data sejarah trafik |

### 16.2 Carian & tempat
| Ciri | Keutamaan | Nota |
|---|---|---|
| Carian dengan cadangan live | MVP | |
| Rumah / Kerja + tempat disimpan | MVP | |
| Kategori pantas: petrol, makan, surau/masjid, tandas, ATM, hospital | MVP | Daripada POI OSM |
| Tempat letak kereta berhampiran destinasi | Selepas MVP | |
| Stesen cas EV | Selepas MVP | |
| R&R / hentian lebuh raya | Selepas MVP | |
| Carian dengan suara | Selepas MVP | |

### 16.3 Komuniti & keselamatan
| Ciri | Keutamaan | Nota |
|---|---|---|
| Laporan: polis, kemalangan, bahaya, sesak, jalan ditutup, kenderaan rosak | MVP | |
| Laporan **banjir** | MVP | Relevan musim tengkujuh |
| Pengesahan "Masih ada?" oleh pengguna lain | MVP | |
| Mod pemandu selamat (UI ringkas & besar semasa bergerak) | MVP | |
| Laporan: pokok tumbang, lubang jalan, lampu isyarat rosak | Selepas MVP | Jenis baharu dalam enum `report_type` |
| Bantuan kecemasan: dail 999 / 112 pantas + kongsi lokasi tepat ke kenalan | Selepas MVP | |
| Notifikasi amaran banjir / bahaya di kawasan disimpan | Kemudian | |
| Amaran kamera / had laju | Kemudian | Semak undang-undang tempatan dan polisi store dahulu |

### 16.4 Pengalaman & penglibatan
| Ciri | Keutamaan | Nota |
|---|---|---|
| Statistik perjalanan (jarak, masa, kelajuan purata) | Selepas MVP | |
| Mata, lencana dan ranking mingguan | Selepas MVP | |
| Avatar kenderaan pada peta (kereta / motosikal pilihan) | Selepas MVP | Menambah rasa "gempak" |
| Ringkasan tahunan boleh dikongsi | Kemudian | |

### 16.5 Sambungan & ekosistem
| Ciri | Keutamaan | Nota |
|---|---|---|
| Peta offline mengikut negeri | Selepas MVP | |
| Waktu solat semasa perjalanan + ingatan berhenti di surau | Selepas MVP | Sumber data waktu solat diputuskan kemudian |
| Widget skrin utama (ETA ke Rumah / Kerja) | Kemudian | |
| Pintasan Siri / Google Assistant | Kemudian | |
| Perintah suara hands-free | Kemudian | |
| CarPlay & Android Auto | Kemudian | CarPlay perlukan kelayakan khas daripada Apple |

---

## 17. Tetapan (Settings)

**Prinsip UX tetapan:**
- Tetapan **boleh dicari** (kotak carian di atas)
- Perubahan berkuat kuasa **serta-merta**, tiada butang Simpan; pratonton langsung untuk tema dan saiz teks
- Lalai yang bijak, supaya kebanyakan pengguna tak perlu ubah apa-apa
- Setiap kumpulan ringkas, dengan ikon dan penerangan satu baris
- Butang **Tetapkan semula ke lalai** per kumpulan
- Tetapan **disegerakkan** antara peranti melalui `user_settings` (lihat Bahagian 6 dan 7)

### 17.1 Paparan & Tema
- Tema: Ikut sistem · Cerah · Gelap · Auto ikut matahari
- Hitam AMOLED (hidup/mati)
- Gaya peta: Standard · Ringkas (kurang POI)
- Warna aksen (beberapa pilihan)
- Bangunan 3D (hidup/mati)
- Orientasi peta: utara di atas · ikut arah perjalanan
- Saiz teks (ikut sistem + penyesuaian dalam app)
- Animasi: Penuh · Dikurangkan · Mati
- Maklum balas haptic (hidup/mati)

### 17.2 Navigasi
- Jenis kenderaan: Kereta · Motosikal · Lori/Van
- Laluan lalai: terpantas / terpendek; elak tol, elak lebuh raya, elak feri
- Sensitiviti re-route: Cepat · Seimbang · Konservatif
- Paparan navigasi: 2D · 3D
- Tunjuk had laju (hidup/mati) + ambang amaran (cth. +0, +5, +10 km/j)
- Kekalkan skrin hidup semasa navigasi
- Unit: kilometer / batu

### 17.3 Suara & Bunyi
- Bahasa arahan: Bahasa Melayu · English
- Jenis suara (ikut pilihan TTS peranti)
- Kelantangan arahan (berasingan daripada kelantangan media)
- Tahap suara: Semua arahan · Amaran sahaja · Senyap
- Kecilkan audio lain semasa arahan (ducking)
- Bunyi amaran laporan (hidup/mati)

### 17.4 Laporan & Amaran
- Jenis laporan yang dipaparkan di peta (tapis mengikut jenis)
- Jenis laporan yang diumumkan secara suara
- Jarak amaran sebelum laporan
- Prompt "Masih ada?" (hidup/mati)
- Notifikasi amaran kawasan (banjir dll., apabila ciri ada)

### 17.5 Peta Offline
- Muat turun mengikut negeri / kawasan
- Kemas kini automatik (Wi-Fi sahaja)
- Urus storan, padam peta

### 17.6 Privasi & Keselamatan
- Hantar data trafik anonim (hidup/mati)
- Sejarah perjalanan: simpan / auto-padam selepas 30 / 90 hari / jangan simpan
- Mod tidak kelihatan kepada kenalan (apabila ciri kongsi ada)
- Kunci app dengan biometrik (pilihan)
- Urus peranti yang dilog masuk
- Eksport data saya
- **Padam akaun dan semua data**
- Status kebenaran lokasi + pintasan ke tetapan sistem

### 17.7 Akaun
- Profil (nama paparan, avatar)
- Tempat disimpan (Rumah, Kerja, lain-lain)
- Sambung / naik taraf akaun Apple / Google
- Log keluar

### 17.8 Notifikasi
- Amaran kawasan, ringkasan mingguan, kemas kini app
- Waktu senyap (jangan ganggu)

### 17.9 Bateri & Data
- Mod jimat bateri (GPS adaptif, animasi dikurangkan)
- Mod jimat data
- Muat turun besar hanya melalui Wi-Fi

### 17.10 Aksesibiliti
- Kontras tinggi
- Teks besar
- Kurangkan gerakan
- Sokongan pembaca skrin (label Semantics)

### 17.11 Bahasa
- Bahasa app: Bahasa Melayu · English (Mandarin dan Tamil kemudian)

### 17.12 Bantuan & Tentang
- Pusat bantuan, hubungi sokongan, hantar maklum balas
- Versi app dan nombor build
- Lesen sumber terbuka dan atribusi OpenStreetMap
- Polisi Privasi · Terma Perkhidmatan
- **Developed by Faiz Nasir · Owned by FG Universal Empire Company**
- © 2026 FG Universal Empire Company. All rights reserved.

### 17.13 Menu pembangun (tersembunyi)
- Log diagnostik, hantar laporan ralat, tukar persekitaran (staging/produksi), main semula GPX. Hanya dalam build dalaman.

---

## 18. Pelan Fasa & Anggaran Masa

> Anggaran untuk **seorang pembangun sepenuh masa**. Laraskan jika ada pasukan atau kerja separuh masa.

| Fasa | Fokus | Hasil | Anggaran |
|---|---|---|---|
| **0. Asas & spike** | Setup repo, CI, design tokens; spike Valhalla + tile + MapLibre; keputusan hos tile | Peta Malaysia dipaparkan; satu laluan dikira | 1-2 minggu |
| **1. Peta & navigasi** | Lokasi live, carian, pratonton laluan, navigasi, suara, re-route | App boleh navigasi A→B dengan UI cantik | 5-7 minggu |
| **2. Akaun & laporan** | Auth anonim + Apple/Google, API laporan, WebSocket, undi & luput, anti-spam asas | Laporan komuniti live | 3-5 minggu |
| **3. Polish UI/UX** | Animasi penuh, tema cerah/gelap/auto, skrin tetapan lengkap, onboarding, haptics, aksesibiliti, prestasi | Rasa premium, 60 fps stabil | 3-4 minggu |
| **4. Trafik live** | Probe anonim, agregat segmen, overlay warna, ETA sedar trafik | Peta trafik berwarna | 4-6 minggu |
| **5. Beta & lancar** | Ujian lapangan, beban, keselamatan, PDPA/polis privasi, kajian store | TestFlight / Play beta → lancar | 4-6 minggu |
| **6. Selepas lancar** | Ciri berstatus 'Selepas MVP' dan 'Kemudian' (Bahagian 16): peta offline, kongsi ETA, widget, CarPlay/Android Auto, perintah suara | Pertumbuhan | Berterusan |

**Status (0.4.0):** Fasa 0-1 siap. Fasa 2 dilaksanakan tanpa backend kongsi (laporan tempatan, tiada akaun). Fasa 3: tema
(termasuk Auto-ikut-matahari), onboarding, tetapan, peta gelap, aksesibiliti asas dan mikro-interaksi siap; animasi lanjutan
(draw-in laluan, radial, Hero) dan profil 60 fps pada peranti belum. Fasa 4-5 belum. Lihat ADR 0008.

**Jumlah MVP bawa ke beta:** kira-kira **4-6 bulan** untuk seorang pembangun. Jangkaan sebenar bergantung pengalaman, kerumitan Valhalla/tile, dan skop yang dikekalkan.

---

## 19. Risiko & Mitigasi

| Risiko | Kesan | Mitigasi |
|---|---|---|
| Kualiti data OSM kurang di sesetengah kawasan | Alamat/POI tak tepat | Semak liputan di bandar utama; sumbang pembetulan ke OSM; sediakan butang "laporkan tempat salah" |
| Kos hos Valhalla / tile / DB | Belanja bulanan naik | Mula kecil, ukur penggunaan, cache agresif, CDN untuk tile |
| Bergantung pada perkhidmatan percuma pihak ketiga (OpenFreeMap) | Tiada SLA; boleh terhenti atau berubah | Pelan sandaran hos tile sendiri; jangan hard-code satu URL (guna config / remote config) |
| Kuota hos percuma berubah (cth. Oracle Always Free dikurangkan) | Server tiba-tiba berhenti atau berbayar | Jangan bergantung pada satu penyedia; automasi deploy supaya mudah berpindah |
| Janji "percuma selamanya" tidak realistik pada skala besar | Kos server naik bila pengguna bertambah | Anggar kos per 1,000 pengguna awal; rancang sumber hasil / pembiayaan |
| Bateri & kebenaran lokasi latar (iOS/Android) | Penolakan store / pengguna rimas | Ikut garis panduan terkini; GPS adaptif; jelaskan kebenaran dengan baik |
| Data trafik tak cukup pengguna | Trafik tak tepat | Lancar dengan laporan komuniti dahulu; tunjuk trafik bila ambang data dicapai |
| Penyalahgunaan laporan | Kepercayaan hilang | Reputasi, cooldown, jenis tetap, moderasi |
| Privasi / kepatuhan PDPA | Risiko undang-undang | Privasi dalam reka bentuk, retensi singkat, nasihat peguam |
| Skop terlalu besar | Projek tak siap | Kunci MVP; setiap ciri baharu mesti gantikan yang lain |
| Prestasi pada Android lama | Jank / crash | Uji pada peranti pertengahan & lama; tetapkan peranti minimum |

---

## 20. Senarai Semak Sebelum Lancar

**Teknikal**
- [ ] 60 fps stabil pada peranti sasaran (profile mode)
- [ ] Uji GPX replayer: lebuhraya, bandar, terowong, re-route
- [ ] Uji tanpa internet dan GPS hilang
- [ ] Ujian beban REST + WebSocket lulus
- [ ] Backup & pemulihan DB diuji
- [ ] Crash-free rate dipantau; alert aktif

**Keselamatan & undang-undang**
- [ ] Semakan OWASP API Top 10, scan dependency
- [ ] Polis privasi + terma perkhidmatan (disemak peguam)
- [ ] Eksport & padam akaun berfungsi
- [ ] Pengisytiharan privasi & lokasi di App Store / Play Console tepat
- [ ] Atribusi OpenStreetMap dipaparkan (keperluan lesen ODbL)

**Produk**
- [ ] Onboarding jelas, kebenaran dijelaskan
- [ ] Tema cerah, gelap, AMOLED dan Auto diuji (tiada kilat putih semasa buka app)
- [ ] Dynamic Type, Reduce Motion, kontras tinggi diuji
- [ ] Tetapan tersimpan, disegerakkan dan dipulih dengan betul selepas kemas kini app
- [ ] Kredit "Developed by Faiz Nasir · Owned by FG Universal Empire Company" dipaparkan dalam skrin Tentang dan butiran store
- [ ] BM & English disemak oleh penutur natif
- [ ] Beta dengan pemandu sebenar di beberapa bandar
