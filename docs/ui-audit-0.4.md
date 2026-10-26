# Audit UI/UX 0.4 (render PNG setiap skrin, cerah/gelap/AMOLED)

Kaedah: setiap skrin dirender dengan harness ujian (peta palsu), dilihat satu-satu. Peta sebenar (tile) tidak
termasuk; rupa peta gelap disemak di peranti. Dijalankan pada 0.3.4+7.

| Skrin | Penemuan | Tindakan |
|---|---|---|
| Peta utama | Tiada butang Laporkan; tiada akses pantas Rumah/Kerja; ikon awan (peta offline) dan ikon tala (tetapan) tidak jelas tanpa tooltip; kawalan zum dan lokasi sudah mencukupi | M3 chip Rumah/Kerja, M4 butang Laporkan, tooltip dikekalkan |
| Perancang carian | Sejarah semua ikon generik; tiada bintang simpan; chip kategori jatuh ke 3 baris tidak sekata; tiada Rumah/Kerja | M3 (Rumah/Kerja, bintang), ikon mengikut jenis OSM |
| Hasil carian | (0.3.2) jenis + jarak sudah ada | Dikekalkan |
| Tetapan (sheet) | Satu sheet padat; pilihan tema berlabel "Auto" (sebenarnya ikut sistem) dan tiada "Matahari"; tiada Privasi/Suara terperinci/Laporan/Bahasa/Tentang lesen | M2 (nama "Sistem", pilihan Matahari), M6 halaman penuh |
| Tentang | Struktur baik; tiada lesen/bantuan | M6 |
| Sheet laporan | Jelas, butang besar (>= 90 px), nota jujur "disimpan pada peranti sahaja"; grid 3 lajur meninggalkan "Banjir" sendirian | M4 grid 4 lajur / jejari |
| Pratonton laluan | Berfungsi, kontras baik; butang "Cuba lagi" berada tengah bawah pada keadaan ralat (tidak sebaris) | Selaraskan baris tindakan (M8) |
| HUD navigasi | Kad manuver jelas, butang sisi hanya ikon (tooltip ada) tanpa butang Laporkan; gelembung kelajuan tiada had laju bersebelahan jika data ada | M4 butang laporan pada butang sisi; had laju sedia ada dipaparkan bila ada |
| Mod gelap peta | Gaya `dark` OpenFreeMap kontras rendah (laporan pengguna) | M1 gaya malam diwarnakan semula |

Keputusan: item di atas dimasukkan ke langkah M1-M8; baki yang tidak dapat disahkan tanpa peranti dinyatakan dalam ADR 0008.
