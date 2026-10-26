# ADR 0006: Lokasi stabil, kereta 3D dan HUD responsif

- Status: diterima (disahkan dengan ujian unit/widget dan imej render; belum diuji pada peranti sebenar)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 8.3, 8.5B, 14.3

## Konteks

Empat masalah dilaporkan semasa menggunakan app:

1. Lokasi pengguna tidak stabil: baik pada mulanya, tetapi selepas keluar ke app lain sebentar (tanpa menutup app)
   dan kembali, titik lokasi dan kamera "lari" ke tempat lain.
2. Kereta semasa memandu rata dan tidak kelihatan 3D.
3. Kad arah belok terlalu besar, tidak responsif, dan pada skrin mendatar kereta tidak kelihatan.
4. Sesekali berkelip dan tidak lancar.

Punca yang dijumpai dalam kod:

- Titik lokasi peta datang daripada enjin GPS asli MapLibre, sedangkan kamera "ikut saya" datang daripada strim
  geolocator yang berasingan. Dua sumber yang tidak sentiasa bersetuju. Enjin asli menunjukkan "lokasi terakhir" yang
  lapuk sebaik app dibuka semula, dan strim geolocator tidak menyemak umur fix (platform menghantar fix tersimpan
  sebaik langganan).
- `lastKnownFix()` (tanpa had umur) digunakan juga selepas app dibuka semula dari latar belakang, dan jika fix segar
  setepat 20 m tidak tiba dalam 12 saat, kamera ditinggalkan di lokasi lapuk itu.
- Kereta ialah sprite rata pada lapisan peta, dikemas kini 60 kali sesaat melalui panggilan platform berasingan
  daripada kamera (dua panggilan setiap bingkai). Sprite rata hanya menjadi kepingan nipis pada kamera condong 60 darjah.
- Kad manuver: ikon 72 px, jarak 42 px, sentiasa selebar skrin; tiada susun atur mendatar.
- Butang kompas asli peta muncul dan hilang setiap kali arah peta melintasi utara; tiga sumber GeoJSON ditulis semula
  walaupun hanya satu yang berubah.

## Keputusan

1. **Satu sumber lokasi untuk peta (`UserLocationTracker`).** Satu langganan GPS yang menyuap titik lokasi (melalui
   `ManualLocationSource` MapLibre) DAN kamera. Setiap fix ditapis (`FixFilter`: lapuk, tidak tertib, terlalu kasar,
   lompatan mustahil), dilicinkan, dan hingar ketika pegun ditahan. Selepas app kembali dari latar belakang penapis
   dimulakan semula dan kedudukan lama ditandakan lapuk (cincin ketidakpastian luas) sehingga fix segar tiba.
   Penjejak kini kekal hidup semasa laluan dipratonton supaya titik lokasi tidak membeku; ia digantung hanya di
   latar belakang dan semasa navigasi (yang memiliki GPS sendiri). `IdleFollow` kini hanya niat mengikut, bukan pemilik
   strim.
2. **Selepas latar belakang tidak terbang ke lokasi terakhir.** `lastKnownFix()` hanya untuk pelancaran sejuk.
   `currentFix(fallbackAccuracyMeters:)` memulangkan fix segar terbaik yang kurang tepat (sehingga 150 m) apabila yang
   tepat tidak kunjung tiba, dan hanya untuk meletakkan kamera, bukan sebagai asal laluan.
3. **Kereta 3D dilukis oleh Flutter, bukan lapisan peta, semasa kamera mengikut.** `CarMesh` (model poligon rendah, ukuran
   kereta sebenar) dan `CarRenderer` (unjuran dengan sudut condong dan arah yang SAMA seperti kamera, lorek Lambert,
   bayang) di dalam `VehicleOverlay`. Tapaknya tepat di titik skrin yang dikira kamera (`CameraRig.screenOffset`), jadi
   sentiasa di atas laluan dan tiada panggilan platform untuk kereta. Lapisan peta (sprite pandangan atas yang dilukis
   oleh enjin yang sama) digunakan HANYA apabila kamera tidak mengikut (peta digerakkan, pandangan keseluruhan) dan
   semasa peralihan masuk kamera, kerana ketika itu kereta mesti terikat koordinat. Arah kereta relatif kepada kamera
   dilicinkan kerana arah kenderaan (kord ke hadapan) boleh melonjak belasan darjah dalam satu bingkai di ramp.
4. **HUD padat dan responsif (`NavHudMetrics`).** Kad manuver ~85 px (potret), lebih kecil lagi dan di kiri atas pada
   skrin mendatar; panel perjalanan terapung di kiri bawah; butang di kanan bawah; bahagian tengah dibiarkan kosong.
   Kamera menaikkan kereta pada skrin mendatar (`carScreenOffsetLandscape`) dan mengurangkan zum sedikit pada paparan
   pendek. Penskalaan teks sistem dihad 115% pada HUD (lingkaran dan kad bersaiz tetap).
5. **Lembaran ringkasan laluan boleh digulung** dan tingginya dihad pada skrin pendek (mendatar), kerana dahulu ia
   melimpah di bawah ~420 px.
6. **Kurangkan kerja platform dan kelipan.** Kompas asli dimatikan semasa navigasi; hanya sumber GeoJSON yang berubah
   ditulis semula.

## Pembetulan selepas ujian naik motor (versi 0.3.1)

1. **Simpang tepat masa.** Kenderaan dianchor pada masa fix DIUKUR (latensi dihad 2.5 s), bukan masa tiba.
   `NavigationSession.refreshLive` (4 Hz) mengira banner, jarak dan pengumuman daripada kedudukan kenderaan
   yang diunjur; manuver dianggap dilalui `0.7 s` sebelum titiknya supaya paparan tidak ketinggalan.
2. **Tamat tepat.** Tiba hanya dalam radius 12-25 m dari hujung laluan, ATAU selepas melepasi titik terdekat,
   ATAU berhenti dekat hujung (bukan lagi 25-50 m). Sambungan akhir bertitik dilukis dari hujung laluan
   (titik jalan yang disnap) ke destinasi sebenar.
3. **Garisan melekat pada kereta, dan peta lancar pada zum rendah.** Laluan dihantar SEKALI dan dipangkas
   dengan `line-gradient` (`lineMetrics`), pecahan dikira dalam ruang Mercator (nisbah geodesik tersasar
   puluhan meter pada laluan panjang). Dahulu GeoJSON laluan dijana semula setiap 15 m, dan pada zum rendah
   (seluruh laluan kelihatan) ini membuat peta memasang jubin semula dan tersangkut. Sandaran: hantar baki
   laluan jika platform menolak `line-gradient`.
4. **Motosikal.** `CarMesh.motorcycle` (penunggang), ikon ikut kenderaan terpilih, `use_trails: 0` untuk
   costing `motorcycle`; larangan motor di lebuh raya mengikut tag OSM yang dihormati Valhalla.
5. **Mod gelap.** Palet kenderaan gelap (badan cerah, halo kuat, kontur terang di atas jalan), tepi laluan
   terang, kad manuver biru tua + teks putih, garis tepi kaca lebih jelas; semuanya diuji nisbah kontras.
6. **Diagnostik** (`--dart-define=FG_DIAG=true`): kadar dan RTT kamera, latensi fix GPS, dan senarai id lapisan
   gaya peta.

## Tidak dibuat dan sebabnya

- **Pemulihan kontras gaya peta gelap (jalan/label):** `setLayerProperties` plugin menghantar semua sifat dan
  menetapkan yang null semula, jadi mengubah satu sifat lapisan yang tidak dikenali boleh merosakkan lebar atau
  warna lain; gaya OpenFreeMap tidak dapat diambil dari persekitaran pembangunan. Senarai id lapisan (FG_DIAG)
  disediakan supaya penalaan boleh dibuat dengan data sebenar.

- **Model 3D sebenar (glTF) atau `fill-extrusion` pada lapisan peta:** plugin `maplibre_gl` tidak menyokong model, dan
  `fill-extrusion` tidak dapat disahkan secara visual tanpa peranti; lukisan Flutter boleh diuji dan dirender di sini.
- **Mematikan `trackCameraPosition` semasa mengikut kenderaan** (menjimatkan satu mesej platform setiap bingkai): mematikannya
  menjadikan `cameraPosition` null, yang memutuskan peralihan masuk. Perlu dinilai dengan profil pada peranti.

## Akibat

- Golden HUD (`navigation_hud_golden_test`) perlu dijana semula pada macOS (`flutter test --update-goldens --tags golden`)
  kerana rupa kad manuver, panel dan butang berubah.
- Penjejak lokasi menggunakan GPS (ketepatan tinggi, penapis jarak 5 m) selama peta kelihatan dan app di latar depan,
  walaupun pengguna sudah menggerakkan peta. Ini harga titik lokasi yang sentiasa betul; ia berhenti di latar belakang.
