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

1. Beri butiran: `LEGAL_REG_NO` (no. pendaftaran syarikat), `LEGAL_ADDRESS`, `LEGAL_EMAIL`.
2. Peguam menyemak kedua-dua dokumen (BM dan EN), lalu tetapkan `LEGAL_REVIEWED=true`.
3. `make check-legal` mesti lulus; `make appbundle LEGAL_EMAIL=... LEGAL_ADDRESS="..." LEGAL_REG_NO=... LEGAL_REVIEWED=true`
   gagal selagi tidak.
4. Jana HTML dan host di URL awam (cth. GitHub Pages) untuk borang kedai:
   `LEGAL_EMAIL=... LEGAL_ADDRESS="..." LEGAL_REG_NO=... python3 tools/legal/render_html.py docs/legal/site`
5. Isi borang kedai mengikut `docs/store/` dan semak jawapan masih sepadan dengan dasar.

## Apabila ciri berubah

Setiap kali app mula menghantar data baharu kepada pihak ketiga (hos baharu, parameter baharu), kemas kini
bahagian 4 dasar privasi **dan** `docs/store/`. Ujian `legal_test.dart` memastikan hos yang dihubungi app
disenaraikan dalam dasar.
