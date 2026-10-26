# ADR 0003: Enjin navigasi belok demi belok

- Status: diterima (Fasa 1)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 8.3, 8.4, 8.5, 14.3

## Keputusan

Enjin navigasi ditulis dalam **Dart tulen** di `app/lib/features/navigation/domain/` (tanpa Flutter UI,
tanpa I/O) dan dipacu oleh lapisan nipis `presentation/` dan `data/`. Tiada pelayan: laluan dan re-route
melalui `RoutePlanner` sedia ada (Valhalla awam atau enjin dalam peranti).

## Aliran data

```
GPS (atau simulasi / GPX)  ->  FixFilter (buang fix buruk, Kalman)
                           ->  RouteTracker (snap ke laluan, tetingkap + arah)
                           ->  OffRouteDetector (ambang adaptif, 3 fix, cooldown)
                           ->  NavigationSession  -> NavProgress (jarak, ETA, manuver seterusnya)
                                                  -> AnnouncementPlanner (suara) -> VoiceGuide (TTS + bunyi)
                                                  -> RerouteRequest -> RoutePlanner
Setiap bingkai (60 fps): VehicleModel (dead reckoning + pembetulan) -> CameraRig -> MapLibre
```

## Keputusan reka bentuk

- **Satu sesi bagi satu laluan.** Re-route mencipta `NavigationSession` baharu; tiada keadaan lapuk.
- **Kedudukan = jarak sepanjang laluan**, bukan indeks titik. Semua logik (manuver, ETA, pengumuman, kamera)
  membandingkan meter.
- **Marker kenderaan tidak mengikut fix terus.** `VehicleModel` memandu kenderaan sepanjang laluan pada kelajuan
  terakhir (suapan ke hadapan) dan hanya membetulkan *ralat* secara beransur-ansur (pemalar 0.35 s). Hasilnya:
  tiada lompatan, tiada undur kerana hingar, dan terus bergerak 90 s tanpa GPS (terowong).
- **Kamera ialah peredam kritikal** (zum, condongan, arah) dengan had kelajuan perubahan, bebas kadar bingkai.
  Zum mengikut kelajuan; menghampiri manuver (diukur dalam *masa*, bukan jarak) kamera menegak dan zum masuk,
  lebih untuk bulatan/pusingan-U; selepas itu kembali ke 3D. Ofset ialah fungsi zum/condongan yang sudah licin,
  jadi kenderaan kekal pada kedudukan skrin yang sama.
- **Pengumuman tiga peringkat** (jauh/dekat/sekarang) dengan jarak bergantung kelajuan (lebuh raya lebih awal);
  hanya peringkat terkini yang diumumkan jika sesi bermula dekat manuver; "kemudian ..." untuk manuver rapat.
- **Ayat arahan dijana sendiri** (BM dan English) daripada jenis manuver Valhalla, bukan teks Valhalla.
- **Bunyi isyarat dijana dalam kod** (WAV 16-bit) supaya tiada aset binari; audio menurunkan, bukan menghentikan, muzik.

## Pengesahan tanpa memandu (Bahagian 8.4)

- `simulateDrive` / `ReplayLocationSource` (butang "Simulasi") dan `parseGpx` + `gpxToFixes` untuk main semula jejak sebenar.
- `test/features/navigation/drive_smoothness_test.dart` memandu seluruh laluan KLCC->KLIA sebenar pada 60 fps dan
  menguji ambang kelicinan (arah, zum, condongan per bingkai; kenderaan kekal di tempatnya pada skrin dan atas laluan).

## Had yang diketahui

- Had laju jalan tidak dipaparkan (Valhalla `/route` tidak memulangkannya; perlu `trace_attributes`).
- Nombor lorong, papan tanda lebuh raya dan kamera kelajuan belum ada.
- Tiada garis panduan "kembali ke laluan" ketika re-route gagal tanpa rangkaian; pengesan mencuba semula tiap 8 saat.
- Pengesahan visual pada peranti sebenar (kesan MapLibre `moveCamera` 60 fps pada telefon lemah) belum dibuat dalam sesi ini.
