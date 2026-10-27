# Google Play: Data safety (jawapan cadangan)

Disediakan daripada aliran data sebenar app (lihat Dasar Privasi bahagian 3-4). **Semak semula** sebelum
menghantar borang; jawapan mesti sepadan dengan apa yang app lakukan pada versi yang diterbitkan.

## Soalan peringkat atas

| Soalan | Jawapan |
|---|---|
| App mengumpul atau berkongsi data pengguna yang diperlukan? | Ya |
| Semua data pengguna disulitkan dalam transit? | Ya (HTTPS sahaja; `network_security_config` melarang cleartext) |
| Pengguna boleh meminta data dipadam? | Ya: Tetapan > Privasi > Padam semua data saya. Tiada akaun dan tiada data di pelayan kami |
| Mengikuti Dasar Keluarga? | Tidak ditujukan kepada kanak-kanak |

## Jenis data

| Jenis | Dikumpul? | Dikongsi? | Tujuan | Pilihan? | Catatan |
|---|---|---|---|---|---|
| Lokasi tepat | Ya | Ya (perkhidmatan peta/laluan) | Fungsi app | Boleh ditolak (ciri terhad) | Asal laluan, navigasi, nama lokasi semasa. Tidak disimpan di pelayan kami |
| Lokasi kasar | Ya | Ya | Fungsi app | Boleh ditolak | Keutamaan hasil carian |
| Carian (sejarah carian) | Ya | Ya (Photon/Nominatim) | Fungsi app | Ya | Teks carian dihantar untuk mendapat hasil; sejarah disimpan pada peranti sahaja |
| ID peranti / iklan | Tidak | Tidak | | | |
| Maklumat peribadi (nama, e-mel) | Tidak | Tidak | | | Tiada akaun |
| Kewangan, kenalan, foto, fail | Tidak | Tidak | | | |
| Log ranap / diagnostik | Tidak (tidak dihantar) | Tidak | | | Log ralat tempatan, pengguna menyalin sendiri jika mahu |

"Dikongsi" bermaksud dihantar kepada pihak ketiga yang bukan pemproses bagi pihak kita (OpenStreetMap
Foundation, komoot, FOSSGIS, OpenFreeMap, GitHub, Google untuk pautan pendek). Tiada data dijual atau
digunakan untuk iklan.

## Kebenaran dan pengisytiharan lain

- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`: peta dan navigasi.
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`: navigasi dengan skrin mati (notifikasi kelihatan).
  Play Console meminta video/penjelasan penggunaan perkhidmatan latar depan jenis lokasi: sediakan demo navigasi.
- Tiada `ACCESS_BACKGROUND_LOCATION`.
- `POST_NOTIFICATIONS`, `WAKE_LOCK`, `INTERNET`.
- Kategori aplikasi: Peta & Navigasi. Iklan: tiada. Pembelian dalam app: tiada.
