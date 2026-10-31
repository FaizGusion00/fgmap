# ADR 0012: Waktu Azan, Muzik percuma dalam app, dan Mod mudah

Status: diterima (0.6.0). Ujian pada peranti sebenar masih diperlukan (lihat "Had").

## Konteks

Pengguna utama ialah pemandu yang lemah membaca peta dan warga emas. Tiga permintaan: (1) ikon manuver
(terutama bulatan) yang boleh dibaca dalam setengah saat; (2) waktu solat dan azan untuk lokasi semasa;
(3) cari dan dengar muzik dalam app semasa memandu, dengan suara navigasi tetap jelas. Semua mesti kekal
dalam falsafah RM0 / tanpa kunci API / tanpa pelayan sendiri (ADR 0004) dan HTTPS sahaja (ADR 0010).

## Keputusan

### Ikon manuver dan HUD
- Bulatan dilukis sendiri (`RoundaboutExitIcon`): satu gelang jalan tebal, tangkai masuk pendek, dan nombor
  simpang keluar besar di tengah. Glif Material `roundabout_right` (lawan jam, untuk lalu lintas kanan)
  dengan nombor bertindih dibuang. Teks kad dipendekkan ("Ambil simpang keluar ke-2" / "Take the 2nd exit");
  ayat bersuara penuh tidak berubah. Ordinal Inggeris diperbetulkan (21st, bukan 21th).
- Pusingan U menggunakan glif kanan (Malaysia memandu di kiri); susur lurus menggunakan glif lurus; gabung
  kiri dicerminkan. Ikon utama 44 -> 52 px (potret), "Kemudian" 22 -> 26 px. Perkataan "Bersedia" muncul
  150 m sebelum manuver.
- Android Auto menerima `maneuverKind` + `roundaboutExit` dan memetakan ke `Maneuver.TYPE_*` hos
  (`ROUNDABOUT_ENTER_AND_EXIT_CW` + nombor keluar), jadi skrin kereta sepadan dengan telefon.

### Panduan lorong
- Pelayan Valhalla awam (3.9.1) **tidak memulangkan `lanes`** untuk mana-mana laluan Malaysia yang diuji
  (4 laluan, 0 manuver berlorong): liputan `turn:lanes` OSM di Malaysia nipis. Maka dua lapisan:
  (1) jika data lorong wujud (Valhalla hadapan, jubin peranti, kawasan lain), `Lane` dihurai daripada
  topeng bit dan dilukis sebagai jalur lorong dengan lorong yang sah/aktif diserlahkan; (2) jika tiada,
  petunjuk sisi "Guna lorong kiri/kanan" diterbitkan daripada jenis manuver (belok/keluar/susur ikut
  sisi; pusingan U kanan; bulatan keluar 1 = kiri, keluar >= 3 = kanan). Dipaparkan dalam 700 m dan
  disebut pada peringatan jauh/dekat ("... Guna lorong kanan."), bukan pada arahan "sekarang".
- Tiada pengambilan `turn:lanes` melalui Overpass: kuota penggunaan wajar dan kelewatan tidak sepadan
  dengan nilai pada liputan semasa.

### Peta malam gaya Waze
- `NightPalette` ditukar daripada hampir hitam (#0F141B) kepada biru laut tua (#13213A) dengan jalan
  kelabu-biru cerah dan lebuh raya kuning; semua jalan >= 4.5:1 terhadap latar (minor 6.2:1), label
  >= 11:1. Mod AMOLED (hitam tulen) kekal sebagai pilihan tema.

### Mod mudah (`app.easyMode`)
- Satu suis (Tetapan > Paparan; juga dalam sambutan). Kesan: teks sekurang-kurangnya 115%; HUD 25% lebih
  besar (ikon/butang) dan 15% (nombor); kad arahan berkontras tinggi (biru tua + putih / hitam + kuning,
  >= 7:1) dengan sempadan 2 px; butang sampingan hanya Laporkan, suara dan tetapan; tiada butang zum;
  Simulasi tersembunyi di sebalik "Lanjut"; pil carian "Ke mana?" dan cip Rumah/Kerja 56 dp.
- Disebarkan melalui `EasyModeScope` (InheritedWidget) supaya widget HUD kekal tanpa `ref` dan ujian yang
  memasang widget secara berasingan tidak berubah. Kad potret kekal < 110 px (had ujian susun atur).

### Waktu Azan
- Pengiraan **pada peranti** dengan `adhan_dart` (port Adhan, MIT, tiada rangkaian). Lalai "JAKIM
  (Malaysia)" = pratetap Singapura pakej itu (Subuh 20°, Isyak 18°, Zohor +1 min, bundar ke atas) kerana
  JAKIM menggunakan sudut yang sama. Jadual rasmi e-Solat menambah ihtiyat dan menggunakan satu jadual
  untuk seluruh zon, jadi nilai berbeza beberapa minit (Subuh paling ketara, ~7 min di KL). UI menyatakan
  "anggaran; ikut jadual rasmi untuk berbuka dan imsak". Pengguna boleh menukar kaedah (MWL, Mesir,
  Karachi, Umm al-Qura) dan mazhab Asar.
- Tiada API waktu solat: semua sumber dalam talian sama ada berkunci, berkuota atau tiada jaminan. Pengiraan
  tempatan berfungsi luar talian dan tiada data keluar.
- Notifikasi: `flutter_local_notifications` + `timezone`. Lalai bunyi = **azan penuh** (saluran Android
  dengan atribut ALARM supaya kedengaran walaupun kelantangan notifikasi rendah; Jangan Ganggu dihormati).
  Pilihan: nada pendek, senyap, peringatan 5/10/15 minit. Saluran berversi (`azan_full_v1` ...) kerana bunyi
  saluran tidak boleh diubah selepas dicipta. iOS mengehadkan bunyi notifikasi kepada 30 saat: versi
  29 saat digunakan; azan penuh hanya apabila app terbuka.
- Penggera tepat: `SCHEDULE_EXACT_ALARM` yang dibenarkan pengguna (kad dalam tetapan), jatuh balik kepada
  `inexactAllowWhileIdle` (mungkin lewat beberapa minit; UI memberitahu). Bukan `USE_EXACT_ALARM`: polisi
  Play mengehadkannya kepada app jam/kalendar. Jadual 2 hari (<= 20 notifikasi, bawah had iOS 64), ID
  tetap mengikut (hari, waktu, peringatan), dijadual semula apabila tetapan berubah, lokasi berpindah
  >= 20 km, app kembali ke hadapan, tengah malam, atau but semula.
- Semasa navigasi aktif: hanya bunyi pendek + cip pada HUD (arahan suara tidak boleh ditenggelamkan oleh
  azan 90 saat), melainkan "Main azan penuh semasa navigasi" dihidupkan. Notifikasi OS tetap dihantar.
- Lokasi: kedudukan dibundarkan ke 0.01° (~1 km; ralat waktu < 10 saat), ditulis hanya selepas berpindah
  >= 20 km; sandaran: lokasi matahari (0.1°) atau bandar yang dipilih daripada senarai 21 bandar. Kunci
  `azan.lat/lng` dipadam oleh "Padam semua data saya".
- Rakaman azan: "The Adhan - Muslim Call to Prayer - Aaqib Azeez" (Wikimedia Commons, CC BY-SA 4.0),
  dibundel sebagai karya berasingan dengan atribusi (`assets/audio/LICENSE-azan.txt`, halaman lesen).
  Satu-satunya rakaman penuh berlesen jelas yang ditemui; rakaman CC0 ialah rakaman jalanan yang bising.
  `res/raw/keep.xml` melindunginya daripada pengecilan sumber.

### Muzik
- Sumber dipilih: **Audius** (API awam tanpa kunci; Audius Open Music License 2 Julai 2025 §1.2 memberi
  "Music Players" pihak ketiga lesen menstrim; atribusi hanya wajib untuk kegunaan komersial tetapi kami
  paparkan artis + "via Audius" + pautan), **Radio Browser** (pangkalan data stesen komuniti, percuma,
  tanpa kunci; cermin de1/fi1/at1 dicuba mengikut tertib; satu kiraan klik tanpa nama setiap main), dan
  **fail yang diimport** pengguna (disalin ke `Documents/music`; tiada kebenaran media).
- Ditolak: Jamendo (`client_id`, kuota 35k/bulan, terma bukan komersial 2013: kunci dalam repo awam dan
  kuota yang boleh dimatikan melanggar "percuma selamanya"); Internet Archive (tiada katalog berstruktur);
  `on_audio_query` (tidak diselenggara). Tiada pemuat turun YouTube atau pengikis.
- Hanya strim radio **HTTPS** ditunjukkan: build release melarang cleartext. Banyak stesen Malaysia `http://`
  (9 daripada 40 teratas) tidak akan muncul; keadaan kosong menerangkannya.
- Pemain: `just_audio` + `audio_service` (kawalan skrin kunci; `MainActivity` ialah `AudioServiceActivity`,
  dimulakan malas pada main pertama) + `audio_session`. Penyama: `AndroidEqualizer` dalam saluran paip;
  pratetap Normal/Bes/Trebel/Suara/Tersuai dipetakan ke jalur peranti; iOS tiada penyama (dinyatakan jujur).
- **Suara navigasi mengatasi muzik**: `AudioCoordinator` (Dart) dipanggil oleh `QueuedVoiceGuide` sebelum
  bunyi isyarat dan selepas ayat; pemain memperlahankan kepada 20% (lalai) atau menjeda (tetapan). Dibuat
  pada peringkat Dart supaya sama di Android dan iOS dan boleh diuji; `handleInterruptions: false` pada
  pemain supaya tidak diperlahankan dua kali. TTS juga meminta fokus audio sementara (`focus: true`) supaya
  app muzik lain turut memperlahankan.
- Tiada pemain kecil pada HUD navigasi (kad manuver dan pandangan kereta diutamakan); Muzik dibuka dari
  lembaran tetapan navigasi, dan pemain kecil muncul di skrin utama.

## Had dan risiko
- Katalog Audius dimuat naik pengguna; sebahagian mungkin melanggar hak cipta. OML menanggung rugi
  pemain, tetapi semakan Play mungkin bertanya. Sandaran: sembunyikan Audius di sebalik tetapan.
- Pengurus bateri OEM (Xiaomi, Huawei) boleh mematikan audio latar belakang.
- Fail `.caf` iOS didaftarkan dalam `project.pbxproj` tanpa Xcode (sama seperti ADR 0010); sahkan di Mac.
- Ujian nilai mutlak waktu solat hanya dijalankan apabila zon masa ujian +08:00.
- Golden dijana pada Flutter 3.47.8 (CI 3.41.7); semak toleransi 0.5% dalam CI.
