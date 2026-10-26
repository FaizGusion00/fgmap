# ADR 0009: Laluan alternatif (hingga 10), laluan utama terbaik, tol dan kos minyak

- Status: diterima (logik disahkan dengan ujian unit/widget; tingkah laku sebenar server awam dan peranti belum diuji)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 8 (laluan), 16 (ciri)

## Konteks

Pengguna mahu 5-10 laluan alternatif yang "cantik", dengan laluan UTAMA ialah yang terbaik dan paling selamat
(bukan sekadar yang terpantas seperti Waze), anggaran tol bagi setiap laluan tanpa sumber berbayar, dan maklumat
tambahan yang berguna. Server Valhalla awam hanya memulangkan ~2 alternatif bagi satu permintaan.

## Keputusan

1. **Penjana calon dihad** (`planCandidateRequests`, `MultiRoutePlanner`): selepas laluan biasa (+`alternates: 2`),
   maksimum 8 permintaan tambahan, 2 serentak (jeda 250 ms), berhenti pada kegagalan sistem pertama (429, 5xx, masa,
   rangkaian): tanpa tol, elak lebuh raya, jarak terpendek (`shortest`), dan **lencongan paksa**: bulatan
   `exclude_polygons` (jejari 2% jarak, 250-1400 m, perimeter < 10 km had pelayan awam) pada 20-80% laluan utama,
   tidak menelan asal/destinasi. Permintaan yang tidak menghasilkan laluan (442/170/171) dilangkau tanpa ralat.
2. **Hasil berperingkat** (`ProgressiveRoutePlanner.watch`): laluan biasa dipaparkan serta-merta, alternatif menyusul
   dengan "Mencari laluan lain...". Pilihan pengguna kekal terpilih walaupun senarai disusun semula
   (`RoutePreviewController._pinned`). Kamera dimuatkan sekali dan sekali lagi apabila siap.
3. **Laluan utama = skor terbaik** (`routeScore`, `mergeRouteCandidates`): dalam 5% daripada masa terpantas, pilih
   skor terendah: masa + 6 s/belokan + 90 s/pusingan-U + 900 s feri + 300 s jalan bersekatan masa + 25% masa bagi
   jalan panjang purata < 6 m/s (wakil kasar jalan kecil/sesak; Valhalla tidak mendedahkan kelas jalan dalam
   arahan). Terpantas ditunjuk berasingan jika >= 1 minit lebih laju. Label: Disyorkan, Terpantas, Tanpa tol, Elak
   lebuh raya, Terpendek, Paling mudah, Alternatif.
4. **Penapis**: masa <= min(1.4x, +15 min) terpantas (lantai +3 min), pendua jika liputan >= 0.75 (memo
   `SameRouteMemo` supaya pasangan tidak dikira semula), feri/jalan bersekatan dibuang jika ada pilihan bersih.
5. **UI**: 6 kad, "Lagi N" untuk sehingga 10; kad menunjukkan masa, beza, jarak, belokan, tol/lebuh raya/feri.
6. **Tol**: jalan bertol sebenar daripada bendera `toll` manuver Valhalla; plaza daripada OSM (Overpass) dipadankan
   ke laluan (<= 40 m, kelompok <= 150 m); harga HANYA daripada `assets/tolls/my_tolls.json` yang disahkan (sumber +
   tarikh wajib). Dataset dihantar **kosong**: tiada sumber rasmi boleh-baca-mesin dan tapak pihak ketiga bercanggah
   (lihat `docs/tolls-data.md`). UI jujur: "N plaza, harga tidak diketahui" / "RM x+ (sebahagian)" / "RM x".
7. **Kos minyak**: harga data.gov.my (cache 24 j, sandaran cache <= 30 hari, diambil hanya apabila laluan sedia)
   atau harga sendiri (RON95 berbeza mengikut subsidi); penggunaan L/100 km boleh ditetapkan. Tiada harga = tiada
   anggaran.
8. **Kongsi dan kecemasan**: kongsi destinasi/ETA melalui lembaran sistem (teks + pautan OSM); butang 999/112
   dengan pengesahan dan papan nombor (tiada panggilan automatik), serta kongsi lokasi tepat.

## Akibat dan risiko

- `exclude_polygons` pada server FOSSGIS dan enjin offline 3.9.1 **belum disahkan** terhadap pelayan sebenar
  (rangkaian disekat dalam persekitaran pembangunan); jika ditolak, varian dilangkau dan laluan biasa tetap ada.
- Beban pada server awam: sehingga 9 permintaan setiap pengiraan laluan (dihad dan berperingkat). Hos sendiri
  disyorkan jika pengguna bertambah.
- Skor ialah heuristik, bukan model keselamatan. Pemberat boleh dilaras dalam `route_scoring.dart`.
- Skema respons `fuelprice` data.gov.my dihurai secara toleran (bentuk tidak dapat disahkan dari sini); harga
  sendiri sentiasa boleh mengatasinya.
