# Google Play listing — FGMaps

Salin ke Play Console → Store presence. Bahasa utama: Melayu (ms-MY); tambah English (en-US).

## Identiti

| Medan | Nilai |
|---|---|
| Nama app | FGMaps |
| Package name | `com.fguniversalempire.fgmaps` |
| Kategori | Peta & navigasi |
| Tag e-mel sokongan | `faizhiruko00@gmail.com` |
| Laman web | (pilihan) https://faiznasirweb.netlify.app/ |
| Dasar privasi (URL) | https://faizgusion00.github.io/fgmap/privacy.en.html |

## Teks pendek (80 aksara max)

**ms:** Navigasi Malaysia — luar talian, suara BM, tol & laluan alternatif.

**en:** Malaysia navigation — offline, Malay voice, tolls & alt routes.

## Teks penuh

**ms:**
FGMaps ialah app navigasi untuk Malaysia. Laluan dikira dalam telefon anda, termasuk mod luar talian selepas muat turun pek peta.

• Navigasi belok demi belok (Bahasa Melayu & English)
• Peta luar talian Malaysia
• Sehingga 10 laluan alternatif (terpantas, terpendek, tiada tol)
• Anggaran tol dan kos minyak
• Carian tempat, Rumah/Kerja, dan cari berhampiran
• Tema Cerah, Gelap, AMOLED dan Matahari
• Waktu Azan rasmi JAKIM dengan notifikasi walaupun app ditutup
• Muzik dan radio dalam app (Malaysia, Indonesia, Korea, K-pop)
• Mod mudah untuk warga emas dan panduan lorong
• Percuma — tiada akaun, tiada iklan, tiada penjejakan

Data peta © penyumbang OpenStreetMap. Dibangunkan oleh Faiz Nasir · FG Universal Empire Company.

**en:**
FGMaps is navigation built for Malaysia. Routes are calculated on your phone, including offline mode after you download the map pack.

• Turn-by-turn navigation (Malay & English)
• Offline maps for Malaysia
• Up to 10 alternative routes (fastest, shortest, no-toll)
• Toll and fuel cost estimates
• Place search, Home/Work, and nearby search
• Light, Dark, AMOLED and Sun themes
• Official JAKIM prayer times with notifications even when the app is closed
• Music and radio in the app (Malaysia, Indonesia, Korea, K-pop)
• Easy mode for older drivers and lane guidance
• Free — no account, no ads, no tracking

Map data © OpenStreetMap contributors. Built by Faiz Nasir · FG Universal Empire Company.

## Aset grafik (folder `docs/store/assets/`)

| Fail | Saiz Play | Kegunaan |
|---|---|---|
| `icon-512.png` | 512×512 | Ikon hi-res |
| `feature-graphic-1024x500.png` | 1024×500 | Feature graphic |
| `phone-*.png` | min. 2 telefon | Tangkapan skrin (jana daripada promo / peranti) |

## Binari sedia muat naik

| Item | Laluan |
|---|---|
| AAB (73 MB) | `app/build/app/outputs/bundle/release/app-release.aab` |
| Simbol debug (simpan) | `app/build/symbols/` |
| Kunci upload + sandaran | `app/android/upload-keystore.jks` + `UPLOAD_KEY_BACKUP.txt` (luar git) |

Bina semula: `make appbundle` (memerlukan `key.properties` + `legal.release.env`).

## Langkah Console selepas AAB

1. Create app → Upload AAB ke **Internal testing** (atau Closed).
2. Host `docs/legal/site/` (GitHub Pages) → tampal URL `privacy.ms.html` / `privacy.en.html` sebagai Dasar privasi.
3. Isi Data safety mengikut `play-data-safety.md`.
4. App content: kategori, sasaran umur, ads = No.
5. Foreground service (lokasi): terangkan navigasi + video/demo ringkas.
6. Muat naik `docs/store/assets/icon-512.png`, `feature-graphic-1024x500.png`, dan `phone-0*.png`.
7. Simpan `UPLOAD_KEY_BACKUP.txt` dalam password manager, kemudian padam fail itu daripada disk kerja.
