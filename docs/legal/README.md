# Dokumen undang-undang FGMaps

Dasar Privasi dan Terma Penggunaan (BM dan EN) ialah **draf**. Ia ditulis mengikut aliran data sebenar app
dan prinsip Akta Perlindungan Data Peribadi 2010 (Malaysia), tetapi **belum disemak peguam** dan bukan
nasihat undang-undang. Semakan peguam diperlukan sebelum app diterbitkan.

## Sumber tunggal

Teks sebenar: `app/assets/legal/{privacy,terms}.{ms,en}.md`. Ia dipaparkan dalam app (Tetapan > Privasi) dan
dijana menjadi HTML untuk web. Jangan sunting salinan lain.

Pemegang tempat `{{entity}}`, `{{regNo}}`, `{{address}}`, `{{email}}` diisi daripada
`app/lib/core/config/legal_config.dart` (atau `--dart-define=LEGAL_...`).

## Sebelum terbit (pintu pelancaran)

1. Salin `app/android/legal.release.env.example` → `legal.release.env` dan isi
   `LEGAL_REG_NO`, `LEGAL_ADDRESS`, `LEGAL_EMAIL`.
2. Semakan: `LEGAL_REVIEWED=true` selepas peguam; atau `owner` untuk muat naik ujian
   (notis draf kekal dalam app).
3. `make check-legal` / `make appbundle` memuat `legal.release.env` secara automatik.
4. Jana HTML dan host di URL awam (GitHub Pages / Netlify) untuk borang kedai:
   `set -a; . app/android/legal.release.env; set +a; python3 tools/legal/render_html.py docs/legal/site`
   Sumber siap: `docs/legal/site/` (privacy.ms.html ialah URL tipikal untuk Play Console).
5. Isi borang kedai mengikut `docs/store/` dan semak jawapan masih sepadan dengan dasar.

## Apabila ciri berubah

Setiap kali app mula menghantar data baharu kepada pihak ketiga (hos baharu, parameter baharu), kemas kini
bahagian 4 dasar privasi **dan** `docs/store/`. Ujian `legal_test.dart` memastikan hos yang dihubungi app
disenaraikan dalam dasar.
