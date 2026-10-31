# ADR 0013: Kamera sepanjang laluan, widget ETA, dan CarPlay

Status: diterima. Along-route POI, AwAS/OSM camera alerts, Open-Meteo weather, trip history,
multi-stop, widget ETA (Android + Dart) dan jambatan CarPlay (Swift) sudah dalam repo.
Sasaran WidgetKit iOS dan entitlement CarPlay Navigation masih langkah luar (lihat "Had").

## Konteks

Pemandu mahu (1) amaran kamera/had laju sepanjang laluan yang dipilih, (2) cuaca ringkas di destinasi,
(3) ETA ke Rumah/Kerja tanpa membuka app, dan (4) FGMaps di CarPlay seperti Android Auto. Semua mesti kekal
dalam falsafah RM0 / tanpa kunci API / tanpa pelayan sendiri (ADR 0004), HTTPS sahaja dan privasi (ADR 0010),
dan tidak boleh mengganggu build Android Auto / `STORE_BUILD`.

## Keputusan

### Kamera: OSM Overpass sepanjang laluan sahaja (tiada LLM GIS dalam v1)
- Sumber data ialah OpenStreetMap melalui **Overpass API**, ditanya **hanya untuk koridor laluan aktif**
  (jalur sempit sekitar polyline yang dipilih, dipecah kepada kotak sempadan kecil dan di-cache setempat
  mengikut jubin). Tiada muat turun seluruh negara, tiada pemprosesan latar.
- Tag yang digunakan: `highway=speed_camera`, `enforcement=maxspeed|traffic_signals|average_speed`,
  `device=camera` yang berkaitan penguatkuasaan. Hasil ditapis mengikut jarak ke laluan dan arah perjalanan.
- **Tiada LLM / "AI GIS" dalam v1.** Menyoal model untuk "mencari kamera" tidak boleh disahkan, tidak
  boleh diulang, dan menambah kos/privasi. Padanan ialah geometri deterministik (jarak titik ke garisan).
  Jika kelak dipertimbangkan, ia keputusan berasingan dengan ujian ketepatan.
- **AwAS**: sistem AwAS (Automated Awareness System, JPJ/PDRM) mempunyai senarai lokasi awam yang tidak
  lengkap dan berubah. Disimpan sebagai **JSON terkurasi** dalam aset (`assets/…`), dengan sumber dan tarikh
  semakan. Pengguna boleh menghidupkan **togol "kamera OSM"** sebagai tambahan.
- **Kejujuran UI**: amaran dilabelkan mengikut sumber (*AwAS (senarai terkurasi)* atau *OSM (komuniti)*)
  dan tetapan menyatakan "mungkin tidak lengkap atau lapuk; patuhi had laju yang dipaparkan jalan". Tiada
  janji "semua kamera"; tiada ketiadaan amaran ditafsirkan sebagai selamat.

### Cuaca: Open-Meteo
- Cuaca ringkas (suhu, hujan, kod cuaca) di destinasi/titik laluan guna **Open-Meteo** (percuma, tanpa
  kunci, HTTPS). Satu permintaan kecil bagi satu titik, di-cache (cth. 30 minit), gagal senyap jika luar
  talian. Hanya koordinat dihantar (bukan identiti pengguna).

### Widget skrin utama (ETA Rumah/Kerja): dasar bateri
- Pakej `home_widget`. Dart menulis rentetan siap-paparan (`eta_widget_payload.dart`) ke storan widget;
  Android (`EtaWidgetProvider`, `AppWidgetProvider` tanpa kemas kini berkala) dan iOS (WidgetKit) hanya
  **membaca dan melukis**.
- **Tiada kemas kini berkala**: `updatePeriodMillis = 0`, tiada `WorkManager`/`BGTaskScheduler`, tiada
  strim GPS untuk widget. Pengemas kini (`EtaWidgetUpdater`) dipanggil hanya apabila:
  1. app dilancar atau diteruskan (resume) (`map_screen`), atau
  2. Rumah/Kerja ditukar (`savedPlacesControllerProvider`).
- Had **15 minit** antara larian (kecuali tempat berubah); langkau semasa navigasi aktif; kandungan sama
  tidak menulis semula / melukis semula widget.
- Lokasi: hanya `lastKnownFix` (tanpa membangunkan GPS). Pengiraan: satu permintaan laluan Valhalla (tamat
  masa 6 saat, `alternates: 0`) setiap destinasi, maksimum dua; jika gagal / luar talian / lebih 150 km,
  **anggaran jarak** (garis lurus x 1.3 / 40 km/j) ditanda `~`. Tempat belum ditetapkan -> CTA
  "Tetapkan dalam FGMaps" (ketik widget membuka app).
- Kos: ketika widget kelihatan tetapi app tidak dibuka, data boleh lapuk. Ini sengaja (bateri dan privasi
  lebih utama daripada ketepatan sesaat). Pengguna membuka app untuk memuat semula.
- iOS: stub `app/ios/EtaWidget/EtaWidget.swift` ada tetapi **belum menjadi sasaran Xcode**; menambah
  *Widget Extension* + App Group `group.com.fguniversalempire.fgmaps` dan `pod install` ialah langkah Xcode
  manual.

### CarPlay: jambatan dalam repo, entitlement di luar
- `CarBridge.swift` mencerminkan `CarBridge.kt`: saluran `com.fguniversalempire.fgmaps/car`, kaedah
  `session` (Flutter -> native) serta `search`, `openPlace`, `endNavigation`, `recenter`, `pan`
  (native -> Flutter). Kontrak diuji dalam `carplay_channel_test.dart`. `CarPlaySceneDelegate` memaparkan
  `CPMapTemplate` + `CPNavigationSession` (manuver, jarak, ETA, Tamat) dan carian/pusatkan.
- **Entitlement CarPlay Navigation (`com.apple.developer.carplay-maps`) diluluskan oleh Apple, di luar
  kawalan repo.** Kod dipasang tanpa entitlement: iOS tidak mencipta adegan CarPlay, jadi pelancaran app
  tidak terjejas. Fail `.entitlements` sengaja **tidak** dikomit sehingga kelulusan. Senarai semak:
  [docs/carplay-setup.md](../carplay-setup.md).
- Android Auto tidak diubah; `STORE_BUILD` kekal hanya mengunci hos Android Auto.

## Akibat dan had
- Data kamera OSM/AwAS tidak lengkap; UI mesti sentiasa mengakuinya.
- Widget boleh lapuk antara pelancaran app; tiada janji masa nyata.
- `UIApplicationSupportsMultipleScenes = true` (syarat CarPlay) membenarkan berbilang tetingkap pada iPad;
  semak jika iPad menjadi sasaran rasmi.
- CarPlay: peta belum dilukis pada `CPWindow` (hanya templat); susulan ialah MapLibre native. Sambungan
  CarPlay ketika app tidak berjalan menunjukkan "Buka FGMaps pada iPhone" sehingga enjin Flutter hidup.
- Kod Swift CarPlay ditulis tanpa SDK iOS pada mesin ini (tidak dikompil/diuji pada peranti); wajib
  dibina dan diuji dalam Xcode + Simulator CarPlay selepas entitlement ada.
