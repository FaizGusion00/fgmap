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
| Fail audio (Muzik: import) | Tidak (kekal pada peranti) | Tidak | | | Disalin ke storan app melalui pemilih sistem; tidak dihantar |
| Lokasi kasar (waktu solat rasmi, WaktuSolat API) | Ya | Ya (WaktuSolat API) | Fungsi app | Ya (hanya jika Waktu Azan dihidupkan / lembaran dibuka; boleh dimatikan) | Koordinat dibundarkan ~1 km + tahun/bulan; tiada pengenal pasti |
| Lokasi kasar (cuaca destinasi/laluan, Open-Meteo) | Ya | Ya (Open-Meteo) | Fungsi app | Ya (hanya semasa pratonton/navigasi laluan; gagal senyap jika tiada talian) | Koordinat destinasi dan sehingga 4 titik sampel laluan dibundarkan ~100 m (3 perpuluhan); tiada akaun/kunci/pengenal pasti |
| Lokasi kasar (kualiti udara, Open-Meteo Air Quality) | Ya | Ya (Open-Meteo) | Fungsi app | Ya (hanya apabila lembaran kualiti udara dibuka) | Satu titik GPS atau tempat carian, dibundarkan ~100 m; AQI AS (bukan IPU rasmi JAS) |
| Carian muzik (Audius) | Ya | Ya (Audius) | Fungsi app | Ya (hanya jika Muzik dibuka) | Teks carian dan ID lagu; tiada lokasi |

"Dikongsi" bermaksud dihantar kepada pihak ketiga yang bukan pemproses bagi pihak kita (OpenStreetMap
Foundation, komoot, FOSSGIS, OpenFreeMap, GitHub, Google untuk pautan pendek, Audius dan Radio Browser untuk
Muzik, WaktuSolat API untuk jadual rasmi JAKIM, Open-Meteo untuk cuaca dan kualiti udara). Pengiraan waktu solat pada peranti (kaedah sandaran) tidak menghantar data. Tiada data dijual atau digunakan untuk iklan.

## Kebenaran dan pengisytiharan lain

- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`: peta dan navigasi.
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`: navigasi dengan skrin mati (notifikasi kelihatan).
  Play Console meminta video/penjelasan penggunaan perkhidmatan latar depan jenis lokasi: sediakan demo navigasi.
- Tiada `ACCESS_BACKGROUND_LOCATION`.
- `POST_NOTIFICATIONS`, `WAKE_LOCK`, `INTERNET`.
- `SCHEDULE_EXACT_ALARM` (pengguna membenarkan dalam tetapan sistem) + `RECEIVE_BOOT_COMPLETED`: notifikasi
  Waktu Azan tepat pada waktunya dan dijadual semula selepas but. Bukan `USE_EXACT_ALARM`.
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (perkhidmatan `audio_service`, jenis mediaPlayback): Muzik terus
  dimainkan dengan skrin dikunci; kawalan media pada notifikasi.
- Kategori aplikasi: Peta & Navigasi. Iklan: tiada. Pembelian dalam app: tiada.
