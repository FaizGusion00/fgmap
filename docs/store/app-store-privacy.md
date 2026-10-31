# Apple App Store: App Privacy ("nutrition labels") dan manifes

Sepadan dengan `app/ios/Runner/PrivacyInfo.xcprivacy`. Semak semula sebelum menghantar.

## Data yang dikumpul (semua: tidak dikaitkan dengan identiti, tidak untuk penjejakan)

| Jenis | Tujuan | Dikaitkan dengan pengguna | Penjejakan |
|---|---|---|---|
| Lokasi tepat | Fungsi app | Tidak | Tidak |
| Sejarah carian | Fungsi app | Tidak | Tidak |
| Carian muzik (teks, kepada Audius) | Fungsi app | Tidak | Tidak |

Data tidak dikumpul: maklumat hubungan, pengenal pasti, pembelian, penggunaan, diagnostik, kewangan, kenalan,
kandungan pengguna (laporan jalan kekal pada peranti).

## Penjejakan

Tiada (`NSPrivacyTracking` = false). Tiada domain penjejakan. Tiada ATT prompt diperlukan.

## API "required reason"

- UserDefaults: CA92.1 (shared_preferences; hanya data dalam app sendiri).
- Pakej pihak ketiga membawa manifes privasi masing-masing; semak laporan privasi Xcode (Product > Archive >
  Generate Privacy Report) pada Mac sebelum menghantar dan tambah mana-mana kategori yang dilaporkan.

## String kebenaran (Info.plist)

- `NSLocationWhenInUseUsageDescription`: menunjukkan kedudukan dan titik mula laluan.
- `NSLocationAlwaysAndWhenInUseUsageDescription`: navigasi giliran demi giliran termasuk apabila skrin mati.
  `UIBackgroundModes` = location, audio (suara navigasi dan Muzik). Terangkan dalam Review Notes.
- Notifikasi (Waktu Azan): diminta hanya apabila pengguna menghidupkan azan. Bunyi notifikasi iOS dihadkan
  30 saat: `azan_short.caf` (29 s) digunakan; azan penuh hanya apabila app terbuka.

## Belum diuji pada Mac

Pendaftaran `PrivacyInfo.xcprivacy` dalam `project.pbxproj` dibuat tanpa Xcode. Buka projek di Xcode, sahkan fail
muncul di bawah Runner dan dalam Build Phases > Copy Bundle Resources.
