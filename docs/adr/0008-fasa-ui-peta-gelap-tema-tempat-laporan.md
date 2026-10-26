# ADR 0008: Fasa UI/UX (peta gelap, tema matahari, tempat disimpan, laporan tempatan, onboarding, tetapan)

- Status: diterima (disahkan dengan ujian unit/widget; rupa peta, animasi dan GPS sebenar belum diuji pada peranti)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 8.1, 9, 14.3, 14.6, 16.2, 17, 18 (Fasa 2 dan 3, tanpa backend kongsi)
- Audit UI: [docs/ui-audit-0.4.md](../ui-audit-0.4.md)

## Konteks

Fasa 0-1 (peta + navigasi) siap. Fasa 2 (laporan) hanya logik tanpa UI; Fasa 3 (polish) belum bermula. Pemilik memilih
kekal tanpa server (ADR 0004), peta gelap yang jelas, Auto-ikut-matahari, Rumah/Kerja, onboarding dan tetapan lengkap.

## Keputusan

1. **Peta gelap diwarnakan dalam app** (`NightStyle`, `MapStyleLoader`). Gaya `dark` OpenFreeMap kontras rendah dan
   `setLayerProperties` plugin menetapkan sifat tidak dinyatakan kepada null, jadi mengubah lapisan hidup tidak selamat.
   JSON gaya asas (`liberty`) diambil, diwarnakan semula mengikut `source-layer` OpenMapTiles dan kelas jalan (jalan
   raya jingga/kuning, jalan besar putih kebiruan, jalan kecil kelabu-biru, label terang dengan halo gelap, lebar jalan
   x1.2, teks x1.1), dan dihantar sebagai JSON. Cache fail 7 hari; gaya lama jika rangkaian gagal; sandaran ke URL gaya
   gelap jika ambil/hurai gagal atau gaya tidak dikenali (< 5 lapisan dikenali). Garisan laluan dipasang di bawah lapisan
   simbol pertama supaya label tidak dilitupi. Kontras palet diuji (jalan >= 3:1, label >= 4.5:1).
2. **Tema Auto-ikut-matahari** (`AppThemeMode.sun`, `solar.dart`): kiraan terbit/terbenam dalam peranti (ketepatan ~8 min),
   lokasi terakhir disimpan (kemas kini jika > 30 km; lalai Kuala Lumpur), pemasa pada peralihan seterusnya; satu
   `effectiveThemeModeProvider`/`sunDarkProvider` digunakan oleh app dan peta supaya sentiasa sepadan. Peralihan tema 300 ms.
3. **Tempat disimpan** (`saved.v1`): Rumah, Kerja (satu setiap satu), kegemaran (had 30, buang yang paling lama); metadata
   OSM (jenis, saiz) disimpan supaya radius destinasi dikekalkan. Chip pantas di peta, bintang pada hasil, bahagian di
   perancang, simpan destinasi daripada lembaran laluan.
4. **Laporan komuniti, tempatan sahaja**: butang pada peta dan HUD, penanda (sprite per jenis), "Masih ada?" bila
   mengetuk penanda, amaran suara BM/EN sekali setiap laporan di hadapan, soalan semasa dilepasi (tutup sendiri 12 s,
   tiada undi jika tidak dijawab), tetapan hidup/mati. Hanya pelapor melihat laporannya; seam `ReportsRepository`
   kekal untuk backend kemudian. Antara muka UI memaklumkan ini dengan jelas.
5. **Onboarding** (3 halaman, `onboarding.v1`, gate `go_router`): nilai app, privasi yang jujur (teks carian dan koordinat
   perjalanan dihantar ke perkhidmatan awam OSM; tiada akaun), persediaan (kenderaan, bahasa suara, kebenaran lokasi
   dengan penjelasan dahulu). Tiada pakej baharu (bukan Rive).
6. **Tetapan penuh** (`/settings` sebagai halaman): paparan (tema, AMOLED, saiz teks 0.9-1.3x, kurangkan animasi,
   getaran, bahasa app), navigasi dan suara (kelantangan, kelajuan pertuturan), laporan, peta offline, privasi (status
   kebenaran, padam sejarah/tempat/laporan dengan pengesahan), bantuan (sambutan semula, lesen, tentang). `Haptics`
   ialah satu pintu masuk getaran.
7. **Navigasi**: 11 senario pemanduan sintetik (lampu isyarat, kanyon bandar, lonjakan, terowong 40 s, selekoh salah,
   simpang rapat, lebuh raya) lulus tanpa mengubah logik sesi: tiada re-route palsu, kemajuan tidak berundur.
   Ditambah `NavProgress.signalLost` dan mesej HUD "Tiada isyarat GPS. Kedudukan dianggar." berasingan daripada "GPS lemah".
8. **Animasi**: `PressScale` (0.97) pada butang kaca/Mula/pil carian; `Motion.sheet` (pegas redaman kritikal, tanpa lajak)
   untuk lembaran laluan; semua menghormati Reduce Motion (sistem atau tetapan app).

## Tidak dibuat dan sebabnya

- **Animasi "draw-in" laluan, Hero, menu jejari laporan:** tidak dapat disahkan lancar tanpa peranti; risiko kelipan
  pada peta natif lebih besar daripada nilainya. Laporan menggunakan lembaran jenis sedia ada (besar, boleh diakses).
- **Backend kongsi, akaun, eksport/padam akaun:** di luar skop (ADR 0004); padam data tempatan disediakan.
- **Pautan dasar privasi/terma:** teks mesti daripada pemilik/peguam; tidak direka.
- **Unit batu/km, mod malam automatik dalam terowong:** Malaysia metrik; tiada bukti manfaat tanpa ujian lapangan.
- **Gaya "navigasi malam" berasingan:** parameter `NightStyle` sedia untuk diperluas; menunggu tangkapan skrin peranti.

## Akibat

- Rupa sebenar peta gelap bergantung pada struktur gaya OpenFreeMap semasa; jika berbeza, app jatuh ke URL (tiada
  kerosakan) dan `FG_DIAG` mencetak id lapisan untuk penalaan.
- Golden HUD, perancang dan halaman tetapan perlu dijana semula pada macOS.
- Laporan tidak membantu pemandu lain sehingga backend dipilih.
