# ADR 0011: Pembetulan selepas ujian jalanan 0.5.1 (reroute, kereta di selekoh, alternatif, label)

Status: diterima (0.5.2). Pengesahan pada peranti sebenar masih diperlukan (lihat "Had").

## Konteks

Ujian jalanan melaporkan: (1) re-route lambat dan tidak stabil; (2) kereta lewat/hanyut di selekoh;
(3) tiada 5-10 laluan alternatif; (4) laluan paling jauh dan lama dipilih sebagai "terbaik".

## Keputusan dan bukti

### Alternatif 5-10 (diukur terhadap Valhalla awam, 8 perjalanan 4-330 km)
- `alternates` dihadkan 2 (alt4 memberi hasil sama). Bulatan `exclude_polygons` sering kembali ke laluan sama.
- Titik lalu (`through`) 7% jarak di kiri/kanan laluan utama menghasilkan laluan berbeza (satu leg).
- Penapis asal (1.4x, +15 min, liputan penuh 0.75) memberi 3-8 pilihan; penapis berperingkat
  (1.6x/+25 min dan banding bahagian tengah sahaja) memberi >= 5 pada kesemua 8 perjalanan.
- `MultiRoutePlanner`: hanya 429 dan ralat enjin menghentikan permintaan; kegagalan sementara dicuba semula
  sekali dan 3 kegagalan berturutan menghentikan. Dahulu satu timeout menghentikan semuanya, senyap.

### Label dan pilihan laluan
- Kod label konsisten, tetapi "Disyorkan" hanya menimbang masa dan "Terpendek" kerap hilang.
- Kini: kos jarak 40 s/km melebihi laluan terpendek dalam skor; laluan yang lebih jauh DAN lebih lama
  (>= 3% pada kedua-dua) tidak boleh dilabel istimewa; "Terpendek" diberi sebelum "Tiada tol"/"Tanpa lebuh raya";
  "Tanpa lebuh raya" mesti benar-benar tiada lebuh raya; kad pertama stabil semasa laluan tiba berperingkat;
  kad menunjukkan beza masa dan jarak.

### Reroute
- Penyimpangan dikesan melalui ambang jarak sahaja (arah hanya mempercepat pengesahan); hysteresis 60%;
  perlahan: 2x ambang dan 4 s; tempoh grace 6 s (ambang 1.5x) bagi sesi re-route.
- Cooldown, permintaan tertunda dan "mengira semula" dipegang oleh pengawal (bertahan merentas sesi):
  8 s selepas berjaya, 3 s selepas gagal. Dahulu sesi baharu kehilangan cooldown dan boleh berulang.
- Asal diunjur ke hadapan (kelajuan x RTT, maks 80 m); `heading_tolerance` 45; tamat masa segera 4 s;
  jawapan lewat dibuang jika pemandu sudah kembali ke laluan.

### Kereta di selekoh (simulator realistik, `realistic_drive_test.dart`)
Sebelum -> selepas (persimpangan 12 m): ralat arah maks 55 -> 12 deg; ralat kedudukan maks 5.5 -> 2.5 m;
heading GPS lewat 1.5 s: 6.2 -> 2.5 m; jejari 25 m: 11.6 -> 7.2 m; hingar GPS lurus p95 3.4 -> 1.9 m.
- Selekoh paparan dilengkungkan (R 12 m, hanya paparan; padanan GPS kekal pada polyline) dan arah ialah tangen.
- Penapis alfa (0.5) pada kedudukan sepanjang laluan; ekstrapolasi menggunakan pecutan (membrek ke selekoh).
- `RouteTracker`: penalti heading kecil untuk beza sudut sederhana (heading GPS lewat ~1 s di selekoh).
- Latensi kamera native diukur (EMA `moveCamera`); pose kamera diunjur sejauh itu dan yaw kereta dikira
  terhadap arah kamera yang sedang dipaparkan: drift kamera p95 4.5 -> 1.1 m pada 100 ms.

## Had
- Tiada rakaman GPS sebenar atau peranti: kesan sebenar bergantung pada RTT peta native dan GPS peranti.
  Gunakan `--dart-define=FG_DIAG=true` untuk melihat RTT kamera dan latensi fix.
- Selekoh paparan menggunakan jejari tetap 12 m; bulatan/lengkung besar bergantung pada bentuk polyline Valhalla.
- Banner arahan masih menunjukkan arahan terakhir semasa "mengira semula" (tidak diubah; menjejas golden HUD).
- Golden lembaran laluan perlu dijana semula (teks penafian dan kad berubah).
