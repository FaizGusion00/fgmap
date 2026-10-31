# AwAS camera dataset

Sumber rasmi: senarai lokasi kamera AwAS JPJ (PDF), cth.
https://www.jpj.gov.my/wp-content/uploads/2025/04/LOKASI-PENGUATKUASAAN-KAMERA-AwAS-TERKINI-15.07.2024-1-1.pdf

Aset app: `app/assets/cameras/awas_my.json`

## Menyegarkan

1. Muat turun PDF/CSV terkini JPJ.
2. Geokod penanda KM lebuh raya dengan rujukan OSM/PLUS yang dipercayai.
3. **Jangan** cipta pin jika keyakinan rendah — buang entri itu.
4. Kemas kini `asOf` dan senarai `cameras`.
5. Jalankan ujian: `flutter test test/features/cameras/`

Ini **bukan** daftar lengkap semua kamera Malaysia (polis bergerak, AES lain, dll.).
