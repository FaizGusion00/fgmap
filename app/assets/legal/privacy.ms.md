# Dasar Privasi FGMaps

Versi {{version}} · Berkuat kuasa {{effective}}

## 1. Siapa kami

FGMaps ("app") dikendalikan oleh **{{entity}}** (No. pendaftaran: {{regNo}}), beralamat di {{address}}. Pembangun: {{developer}}. Untuk sebarang soalan privasi, hubungi **{{email}}**.

## 2. Ringkasan

- Tiada akaun, tiada iklan, tiada analitik dan tiada penjejakan.
- Sejarah carian, tempat disimpan (Rumah, Kerja, kegemaran), sejarah perjalanan, laporan dan tetapan kekal pada telefon anda. Kami tidak mempunyai pelayan yang menyimpannya.
- Untuk memaparkan peta, mencari tempat dan mengira laluan, app menghantar permintaan terus ke perkhidmatan awam pihak ketiga (bahagian 4). Kami tidak mengendalikan perkhidmatan itu dan tidak menerima salinan permintaan anda.
- Anda boleh memadam semua data tempatan pada bila-bila masa: Tetapan > Privasi > Padam semua data saya.

## 3. Data yang disimpan pada telefon anda sahaja

- Tetapan app (tema, bahasa, suara navigasi, jenis kenderaan dan sebagainya).
- Sejarah carian dan destinasi terkini.
- Sejarah perjalanan (ringkasan pilihan perjalanan selesai: jarak, tempoh, nama destinasi, dan anggaran tol/minyak jika diketahui). Disimpan mengikut tempoh yang anda pilih dalam Tetapan (lalai 90 hari; atau 30 hari, selamanya, atau dimatikan). Tidak pernah dimuat naik.
- Stesen radio kegemaran (nama dan alamat strim) dan stesen yang gagal disambung dalam 24 jam lalu, pada telefon anda sahaja.
- Tempat disimpan: Rumah, Kerja dan kegemaran, termasuk koordinat yang anda pilih atau lokasi semasa yang anda simpan.
- Laporan jalan (kemalangan, sekatan dan sebagainya) yang anda buat. Buat masa ini ia hanya disimpan pada telefon anda dan tidak dikongsi dengan pengguna lain.
- Simpanan sementara: hasil carian berhampiran (hingga 30 hari), gaya peta, peta luar talian yang anda muat turun, dan kedudukan kasar (dibundarkan kira-kira 11 km) untuk mengira waktu matahari terbit dan terbenam bagi tema automatik.
- Log ralat ringkas pada telefon (jika dihidupkan), yang tidak mengandungi koordinat atau URL dan tidak dihantar ke mana-mana kecuali anda salin dan hantar sendiri.
- Waktu Azan: kedudukan kasar (dibundarkan kira-kira 1 km) atau bandar yang anda pilih disimpan untuk menentukan waktu solat dan menjadualkan notifikasi. Waktu solat diambil daripada jadual rasmi JAKIM (bahagian 4) atau dikira pada telefon anda sendiri jika tiada talian atau anda mematikan pilihan itu; jadual bulanan yang diambil disimpan pada telefon.
- Muzik: fail audio yang anda import dari telefon disalin ke storan app; tetapan pemain (penyama, tingkah laku semasa suara navigasi) juga disimpan di sini.

Data ini tidak disandarkan ke awan (sandaran Android dimatikan).

## 4. Data yang dihantar kepada pihak ketiga

App perlu menghubungi perkhidmatan berikut untuk berfungsi. Setiap satu turut menerima alamat IP anda dan maklumat sambungan biasa, dan memprosesnya mengikut dasar privasi mereka sendiri.

- **Peta (OpenFreeMap):** permintaan jubin dan gaya peta. Ia mendedahkan kawasan yang anda lihat.
- **Carian tempat (Photon oleh komoot, Jerman; sandaran Nominatim oleh Yayasan OpenStreetMap, UK):** teks yang anda taip dan kedudukan anggaran anda sebagai keutamaan hasil. Apabila anda memilih "Guna lokasi semasa" untuk Rumah atau Kerja, kedudukan tepat dihantar sekali untuk mendapatkan nama alamat.
- **Laluan dan had laju (Valhalla oleh FOSSGIS e.V., Jerman):** kedudukan GPS semasa anda sebagai asal, destinasi, arah perjalanan, jenis kenderaan dan pilihan laluan. Semasa navigasi, app mengira semula laluan jika anda menyimpang, dan menghantar bentuk laluan untuk mendapatkan had laju. Semasa pratonton, bentuk beberapa laluan calon juga dihantar (tanpa pengenal pasti) untuk mengetahui kelas jalannya supaya laluan yang disyorkan mengutamakan jalan utama berbanding jalan kampung.
- **Tempat berhampiran dan plaza tol (Overpass API; cermin di Eropah):** titik tengah atau kotak sempadan kawasan yang dicari.
- **Peta luar talian (GitHub Releases):** muat turun pek peta yang anda pilih. Hanya alamat IP dan butiran muat turun yang terlibat.
- **Harga petrol (data.gov.my, Kerajaan Malaysia):** permintaan tanpa data peribadi; hanya alamat IP.
- **Pautan peta pendek (maps.app.goo.gl, Google):** hanya apabila anda membuka pautan yang dikongsi dengan anda; app meminta pautan itu untuk mengetahui destinasinya.
- **Waktu solat rasmi (WaktuSolat API, api.waktusolat.app):** hanya apabila Waktu Azan dihidupkan atau lembaran waktu solat dibuka dan pilihan "Waktu rasmi JAKIM" aktif. API komuniti ini mengambil jadual e-Solat JAKIM; ia menerima kedudukan kasar anda (dibundarkan kira-kira 1 km) serta tahun dan bulan, dan memulangkan jadual bulan untuk zon JAKIM anda. Tiada pengenal pasti dihantar. Matikan pilihan itu untuk menghentikan permintaan (waktu kemudian dikira pada telefon).
- **Cuaca (Open-Meteo, api.open-meteo.com):** hanya apabila anda pratonton atau menavigasi laluan dan jalur cuaca dipaparkan. Ia menerima destinasi dan sehingga empat titik sampel sepanjang laluan, setiap satu dibundarkan kira-kira 100 m (3 perpuluhan), lalu memulangkan suhu, kod cuaca dan kebarangkalian hujan. Tiada akaun, kunci API atau pengenal pasti dihantar. Jika permintaan gagal atau anda tiada talian, jalur cuaca hanya disembunyikan (soft-fail) dan tiada perkara lain berubah.
- **Kualiti udara (Open-Meteo, air-quality-api.open-meteo.com):** hanya apabila anda membuka lembaran kualiti udara. Ia menerima satu titik — fix GPS anda atau tempat yang anda cari — dibundarkan kira-kira 100 m, lalu memulangkan AQI AS serta kepekatan pencemar. Ini bukan IPU rasmi Jabatan Alam Sekitar. Tiada akaun atau pengenal pasti dihantar. Jika permintaan gagal, bacaan berhampiran yang baru mungkin dipaparkan sebagai cache, atau lembaran menyatakan tidak tersedia.
- **Muzik: Audius (Audius API dan nod kandungan yang dikendalikan pihak ketiga):** hanya apabila anda membuka Muzik dan mencari atau memainkan lagu; teks carian dan ID lagu yang dimainkan dihantar (tiada lokasi). Lagu dimainkan secara strim dan tidak disimpan.
- **Muzik: Radio Browser (cermin komuniti di Eropah) dan pelayan strim stesen radio itu sendiri:** hanya apabila anda membuka tab Radio atau memainkan stesen; senarai stesen bagi kawasan yang anda pilih diminta dan satu kiraan "main" tanpa nama dihantar setiap kali anda memainkan stesen. Bagi stesen yang hanya disenaraikan melalui HTTP biasa, app turut menyemak (sehingga 30 setiap senarai, hanya pengepala respons, tiada audio dimuat turun) sama ada stesen itu juga menjawab melalui HTTPS, dan memaparkannya hanya jika ya; ini menghubungi pelayan stesen berkenaan, yang melihat alamat IP dan nama app anda, sama seperti apabila anda memainkannya. Strim datang terus daripada pelayan stesen (HTTPS sahaja).
- **Muzik: Apple Music (iPhone sahaja, MusicKit Apple):** hanya jika anda mengetik "Sambung Apple Music" di tab Lagu. iOS meminta kebenaran anda dahulu; selepas itu carian dan main lagu pergi dari telefon anda terus ke Apple di bawah dasar privasi Apple sendiri, menggunakan langganan Apple Music anda sendiri. FGMaps tidak menerima akaun, nama, e-mel, token atau sejarah mendengar: ia hanya tahu sama ada anda memberi akses dan sama ada langganan anda boleh memainkan lagu penuh, dan tiada apa-apa tentang ini dihantar ke pelayan kami. Tiada di Android.

Perkhidmatan ini dikendalikan di luar Malaysia (terutamanya Eropah, dan GitHub di Amerika Syarikat).

Apabila anda menekan **Kongsi** atau **Kecemasan**, app menyediakan teks (nama destinasi, masa tiba, atau koordinat anda) untuk dihantar melalui aplikasi lain pilihan anda, atau membuka papan nombor telefon. App tidak melihat siapa penerimanya dan tidak membuat panggilan tanpa pengesahan anda.

## 5. Kebenaran yang diminta

- **Lokasi (tepat dan kasar):** menunjukkan kedudukan anda, sebagai asal laluan dan untuk navigasi belok demi belok. Hanya digunakan semasa app dibuka atau semasa navigasi aktif (perkhidmatan latar depan dengan notifikasi kelihatan).
- **Skrin kekal hidup dan notifikasi:** supaya navigasi tidak terputus dan anda nampak ia sedang berjalan; notifikasi juga digunakan untuk Waktu Azan jika anda menghidupkannya.
- **Penggera tepat (Android 12+) dan but semula:** supaya notifikasi azan berbunyi tepat pada waktunya dan dijadualkan semula selepas telefon dihidupkan semula. Hanya jika Waktu Azan dihidupkan; tanpa kebenaran penggera tepat, notifikasi mungkin lewat beberapa minit.
- **Main media di latar belakang:** supaya Muzik terus dimainkan apabila skrin dikunci, dengan kawalan pada skrin kunci.
- **Akses fail (pemilih sistem):** hanya fail audio yang anda pilih sendiri untuk diimport ke Muzik.
- **Internet:** untuk bahagian 4.

Anda boleh menarik balik kebenaran bila-bila masa dalam tetapan telefon. Sebahagian ciri tidak akan berfungsi tanpa lokasi.

## 6. Asas dan tujuan pemprosesan

Kami memproses data hanya dengan persetujuan anda (anda memberi kebenaran lokasi dan menggunakan ciri berkenaan) dan hanya untuk menjalankan fungsi app yang anda minta. Kami tidak menggunakan data untuk pengiklanan, pemprofilan atau dijual.

## 7. Berapa lama data disimpan

Data tempatan kekal sehingga anda memadamnya atau menyahpasang app. Simpanan sementara dibuang secara automatik apabila luput. Pihak ketiga menyimpan data mengikut dasar mereka; kami tidak mengawal tempoh itu.

## 8. Pemindahan ke luar Malaysia

Kerana pelayan di bahagian 4 berada di luar Malaysia, data yang dihantar ke pelayan itu dipindahkan merentas sempadan. Dengan menggunakan ciri berkenaan, anda bersetuju dengan pemindahan itu.

## 9. Hak anda

Mengikut Akta Perlindungan Data Peribadi 2010 (Malaysia) dan prinsipnya, anda berhak meminta akses dan pembetulan data peribadi anda, dan menarik balik persetujuan. Kerana kami tidak menyimpan data anda di pelayan, anda boleh melihat, mengubah dan memadam semuanya terus dalam app. Untuk sebarang permintaan lain, hubungi {{email}}.

## 10. Keselamatan

Semua komunikasi rangkaian menggunakan HTTPS. Data tempatan disimpan dalam ruang storan app yang terasing dan tidak disandarkan ke awan. Tiada sistem yang selamat sepenuhnya; gunakan kunci skrin telefon, terutama jika anda menyimpan Rumah dan Kerja.

## 11. Kanak-kanak

App ini tidak ditujukan kepada kanak-kanak bawah 13 tahun dan kami tidak sengaja mengumpul data mereka.

## 12. Perubahan dasar ini

Jika dasar ini berubah, versi dan tarikh berkuat kuasa di atas dikemas kini, dan perubahan penting akan dimaklumkan dalam app.

## 13. Hubungi kami

{{entity}}
{{address}}
E-mel: {{email}}
