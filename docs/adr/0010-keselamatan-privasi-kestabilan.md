# ADR 0010: Keselamatan, privasi, dokumen undang-undang dan kestabilan

- Status: diterima (konfigurasi natif dijaga ujian regresi fail; tingkah laku pada peranti dan Mac belum diuji)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 12, 13, 20

## Keputusan

### Keselamatan
- Android: `allowBackup=false` + peraturan ekstrak/sandaran yang mengecualikan semua domain; `network_security_config`
  (HTTPS sahaja, hanya CA sistem; build debug dikecualikan untuk 10.0.2.2/localhost sahaja); R8 minify + shrink
  eksplisit; `make appbundle` (`--obfuscate`, `FGMAP_STORE_BUILD=1` menggagalkan build tanpa kunci release);
  baiki kategori intent `android.intent.category.DEFAULT` yang tersalah taip.
- iOS: `PrivacyInfo.xcprivacy` (tiada penjejakan; lokasi tepat + sejarah carian untuk fungsi app; UserDefaults
  CA92.1). Didaftarkan dalam projek Xcode tanpa Xcode: sahkan di Mac.
- Build release menolak titik akhir bukan-HTTPS (`AppConfig.insecureEndpoints`).
- Semua log melalui `logDiag` (senyap dalam release; URL dan koordinat dibuang). Label pautan luaran dibersihkan
  (aksara kawalan/bidi, <= 80). Pautan Overpass POST (koordinat tidak dalam URL). UA `FGMap/0.5`.
- CI: Dependabot, CodeQL (Kotlin/Java), OSV-scanner, SBOM CycloneDX.

### Privasi
- Lokasi untuk tema matahari dibundar 0.1 darjah. "Padam semua data saya" memadam sejarah, tempat disimpan,
  laporan, simpanan carian berhampiran, lokasi matahari dan log ralat.
- Dasar Privasi dan Terma (BM/EN) dalam app dan sumber tunggal `assets/legal/*.md`; setiap hos yang dihubungi app
  mesti disebut (diuji). Borang kedai dalam `docs/store/`.
- **Draf, belum disemak peguam.** `LegalConfig` ada pemegang tempat `[DIISI]`; `make check-legal` dan
  `make appbundle` gagal sehingga butiran diisi dan `LEGAL_REVIEWED=true`.

### Kestabilan
- `FlutterError.onError` + `PlatformDispatcher.onError` merekod ke log ralat tempatan (50 entri, dibersihkan,
  tidak dihantar; Tetapan > Bantuan > Salin laporan ralat); `ErrorWidget` ramah dalam release.
- `RetryInterceptor`: cuba semula sekali (jitter) untuk GET/HEAD idempoten yang memintanya (gaya peta, manifes
  offline, harga minyak, pautan pendek). Carian dan laluan sengaja tidak (ada sandaran lebih pantas).
- `FrameMonitor` (`--dart-define=FG_DIAG=true`) mencetak peratus jank setiap 5 s untuk pengukuran pada peranti.
- Carian berhampiran: peringkat awal pantas dan progresif, hedge cermin, parse dalam isolate, stale-while-
  revalidate, warm-up (lihat `nearby_search.dart`).

## Tidak dibuat (susulan, jujur)
- Tandatangan manifest peta offline (perlukan ed25519 dan kunci yang pemilik jana); hos sendiri Photon/Overpass/Valhalla.
- Penstrukturan semula `MapScreen.build` (rebuild terpilih) dan pengukuran 60 fps: tiada peranti di sini; pemantau
  jank disediakan untuk anda ukur dahulu sebelum mengoptimumkan.
- Sepanduk "tiada internet" (connectivity_plus) tidak dibina.
- Anggaran harga tol: dataset kosong sehingga sumber rasmi disahkan.
