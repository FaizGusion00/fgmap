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
- **Semakan 1.1.0: sumber rasmi.** Pengiraan sahaja berbeza beberapa minit daripada jadual rasmi, dan
  pengguna mahu waktu yang "sah". Ditemui **WaktuSolat API** (`api.waktusolat.app`): percuma, tanpa kunci,
  HTTPS, menukar koordinat kepada zon JAKIM (`/v2/solat/gps/{lat}/{lng}`) dan memulangkan jadual bulanan
  e-Solat (cap masa Unix). Jadual itu kini sumber utama (kaedah JAKIM + mazhab Syafie sahaja; itulah yang
  dipakai jadual rasmi); pengiraan pada peranti kekal sebagai sandaran (tiada talian, di luar Malaysia,
  API turun, atau pilihan "Waktu rasmi JAKIM" dimatikan: tiada permintaan rangkaian langsung).
  Hanya koordinat 0.01° (~1 km), tahun dan bulan dihantar; tiada pengenal pasti. Jadual disimpan pada
  telefon (`azan.official.v1`, maks. 6 bulan, sah dalam 15 km) dan dipadam oleh "Padam semua data saya".
  Data dihuraikan dengan ketat (waktu mesti menaik; hari rosak dibuang) supaya respons buruk tidak pernah
  mengatasi pengiraan. Risiko: API komuniti tanpa SLA; sandaran menanganinya. Sumber waktu dipaparkan
  dalam lembaran waktu ("zon WLY01" atau "dikira pada telefon").
- Notifikasi: `flutter_local_notifications` + `timezone`. Lalai bunyi = **azan penuh** (saluran Android
  dengan atribut ALARM supaya kedengaran walaupun kelantangan notifikasi rendah; Jangan Ganggu dihormati).
  Pilihan: nada pendek, senyap, peringatan 5/10/15 minit. Saluran berversi (`azan_full_v1` ...) kerana bunyi
  saluran tidak boleh diubah selepas dicipta. iOS mengehadkan bunyi notifikasi kepada 30 saat: versi
  29 saat digunakan; azan penuh hanya apabila app terbuka.
- Penggera tepat: `SCHEDULE_EXACT_ALARM` yang dibenarkan pengguna (kad dalam tetapan), jatuh balik kepada
  `inexactAllowWhileIdle` (mungkin lewat beberapa minit; UI memberitahu). Bukan `USE_EXACT_ALARM`: polisi
  Play mengehadkannya kepada app jam/kalendar. Jadual 7 hari (dihadkan 60 notifikasi, bawah had iOS 64; yang terdekat dahulu), ID
  tetap mengikut (hari, waktu, peringatan), dijadual semula apabila tetapan berubah, lokasi berpindah
  >= 20 km, app kembali ke hadapan, tengah malam, atau but semula.
- Semasa navigasi aktif: hanya bunyi pendek + cip pada HUD (arahan suara tidak boleh ditenggelamkan oleh
  azan 90 saat), melainkan "Main azan penuh semasa navigasi" dihidupkan. Notifikasi OS ialah laluan
  yang boleh dipercayai apabila app ditutup; apabila app terbuka (atau navigasi aktif) pengawal mengambil
  alih 2 saat sebelum waktu dan **membatalkan notifikasi OS yang sepadan** supaya azan tidak berbunyi dua
  kali dan peraturan navigasi dipatuhi. App di latar tanpa navigasi: OS sahaja yang berbunyi.
- **Pembetulan 1.1.0 (suis azan tidak berfungsi):** pangkalan data `timezone/latest_10y` tiada
  `Asia/Kuala_Lumpur` (pautan IANA ke Singapura). Semua telefon Semenanjung melaporkan ID itu, jadi
  permulaan notifikasi melontar dan ralat ditelan senyap: suis tidak berbuat apa-apa dan tiada azan pernah
  dijadualkan. Kini `resolveTimezone` menggunakan alias (+8) dan jatuh balik kepada ofset peranti;
  permulaan yang gagal tidak lagi di-cache; setiap hasil kebenaran (ditolak, disekat, penggera tepat belum
  dibenarkan) ada dialog jelas dengan butang ke tetapan; kebenaran notifikasi turut diminta semasa sambutan.
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

## Tambahan 1.1.0: HUD manuver, pemilihan laluan dan kamera

### Gambar rajah manuver (`ManeuverDiagram`)
- Ikon Material (terutama `fork_right`, `ramp_right`) sukar dibaca sekilas: "Kekal kanan" kelihatan
  seperti anak panah bercabang tanpa makna, dan "Ambil susur" dengan anak panah lurus langsung tidak
  menunjukkan arah. Diganti dengan gambar rajah simpang yang dilukis sendiri (`CustomPainter`, ruang
  100x100, versi kiri = cermin versi kanan, untuk lalu lintas sebelah kiri): jalan yang diambil =
  garisan tebal + kepala anak panah; jalan lain yang TIDAK diambil = garisan pudar. Belok = jalan lurus
  pudar + laluan membelok; kekal = jalan bercabang dengan satu cabang ditonjolkan; susur = jalan utama
  pudar + cabang keluar; gabung = jalan disertai pudar + laluan masuk; pusingan U. Bulatan kekal gelang +
  nombor keluar; mula/tiba/feri kekal glif Material. Lembaran semua simbol dijaga oleh golden
  `maneuver_diagrams.png`.

### Papan tanda dan kod jalan
- Valhalla memulangkan `sign` (nombor keluar dan "menuju ...") pada cabang, susur dan keluar, tetapi app
  hanya memaparkan nama jalan; kad menunjukkan "Kekal kanan / 3217". Kini `towards` dan `exitNumber`
  dihuraikan, disimpan dalam rekod perjalanan, dan dipaparkan ("Keluar 1306B · Menuju Klang · I-City") serta
  disebut ("Kekal di sebelah kanan menuju Klang"). Untuk belok biasa, nama jalan kekal.
- Kod jalan nombor sahaja ("3217", "2") bukan nama yang bermakna: dikenal pasti sebagai kod (regex
  `[A-Z]{0,3}\s?\d+[A-Z]?`), tidak diutamakan berbanding nama sebenar, dan dipaparkan/disebut "Laluan 3217".

### Kualiti jalan dalam pemilihan laluan "Disyorkan"
- Diukur terhadap Valhalla awam (8 perjalanan, Lembah Klang dan luar bandar): laluan lalai sudah 91-97%
  jalan utama di Lembah Klang, tetapi sesetengah perjalanan luar bandar melalui 25-30% secondary/tidak
  dikelaskan (Seremban-KLIA: 20% secondary + 8% unclassified). Pilihan costing (`maneuver_penalty`,
  `service_penalty`, `use_highways` 1.0) hampir tidak mengubah hasil: Valhalla tiada kawalan untuk
  mengelak tertiari/kampung. Maka kelas jalan SEBENAR dinilai selepas laluan dikira: `trace_attributes`
  (`edge.road_class`) pada laluan yang bersaing (masa dalam 1.15x terpantas, maks. 6 permintaan satu
  carian, tidak untuk re-route) memberi `roadPenalty` = jumlah (pecahan jarak x berat kelas; secondary
  0.06, tertiari 0.30, tidak dikelaskan 0.40, kediaman 0.50, servis 0.80, dihad 0.6) yang ditambah pada
  skor sebagai pecahan masa. Ia hanya mempengaruhi pilihan "Disyorkan" (dan menghalang laluan "dikalahkan"
  oleh laluan yang sedikit lebih laju tetapi melalui jalan kampung); masa dan jarak yang dipaparkan tidak
  berubah. Gagal/tamat masa = tingkah laku lama. Bentuk beberapa laluan calon dihantar ke pelayan yang
  sama dengan had laju (privasi dikemas kini).

### Zum
- Mencubit untuk zum semasa kamera dilepaskan kini diingat sebagai bias zum apabila kamera kembali
  mengikut (sama seperti butang +/-), dan zum automatik (kelajuan, menghampiri simpang) terus berfungsi
  di atasnya. Perubahan < 0.3 tahap dianggap hingar; > 2.5 tahap dianggap meninjau peta dan kamera
  kembali ke zum automatik.


### Semakan 1.2: Radio diperkukuh, YouTube ditolak (keputusan dan bukti)

Permintaan: lagu Melayu/Indonesia/Japan yang banyak "macam Spotify/YouTube Music". Diukur terhadap API sebenar
(31 Okt 2026), bukan diandaikan.

**Mengapa katalog label tiada.** Audius (lagu muat naik pengguna): "siti nurhaliza" = 4 hasil, semuanya
remix/bootleg; Spring = 0. Deezer dan iTunes ada katalog sebenar (Deezer: 235 lagu Siti Nurhaliza; Awie, Ziana
Zain, Exists, Dewa 19, Tulus, YOASOBI ditemui) tetapi **hanya pratonton 30 saat**. Terma Deezer: "Personal
Applications", penggunaan "non-commercial", audio tidak boleh disimpan luar talian, pautan pratonton mempunyai
`exp=` (tamat tempoh). Tiada API percuma yang memberi lagu penuh artis label.

**Ditolak, dengan sebab:**
- `mohd-baquir-qureshi/music-api`: repo satu fail README, tiada lesen, dinyahaktifkan oleh pengarangnya (13 Mei 2024),
  membungkus enjin Gaana/JioSaavn (katalog India, tiada Melayu/Indonesia/Japan), dan endpoint-nya mati
  (`error code: 1042`). Pengikis tidak berlesen: tidak diguna.
- Pengekstrak YouTube (Piped/Invidious/youtube-dl): terma pembangun YouTube melarang secara nyata mengasingkan
  audio, menyimpan/menyalin kandungan, dan menggunakan API tidak didokumenkan (III.E.1, III.D.7, III.I). App Store
  5.2.3 melarang menyimpan/menukar/memuat turun daripada YouTube tanpa kebenaran dan memberi amaran strim juga
  boleh melanggar terma; Play melarang app yang menggalakkan pelanggaran hak cipta. Tiada cara menjadikannya
  "selamat": menyembunyikan ciri daripada penyemak kedai (flag jauh) ialah penipuan dasar dan boleh menamatkan
  akaun pembangun, bukan sekadar membuang app. Ditolak (sama seperti ADR ini sebelum ini).
- Pemain tertanam YouTube rasmi (sah): lagu penuh, tetapi pemain mesti kelihatan (>= 200x200, tiada tindanan),
  tiada main latar, dan carian `search.list` lalai hanya **100 panggilan/hari** untuk seluruh projek (permohonan
  kuota melalui audit pematuhan). Pemandu juga akan melihat video. Tidak dibina; boleh dipertimbang semula
  untuk senarai main kurasi (`playlistItems.list` = 1 unit) jika diputuskan.
- Spotify: strim hanya untuk Premium dan kuota lanjutan memerlukan organisasi berdaftar dengan >= 250k MAU
  (polisi 15 Mei 2025). Apple Music (MusicKit, Android + iOS) sah untuk pelanggan, belum dinilai.

**Dibina (Radio, penuh dan sah):**
- Diukur (strim sebenar disambung dari lokasi pembangun): 150 teratas Malaysia 54/54 HTTPS berfungsi, Indonesia
  114/121, Japan 105/108, **Korea hanya 27/62** (stesen KBS/SBS/MBC besar dikembalikan HTTP error dari luar Korea).
- `ssl_error` (sijil rosak) kini dibuang: OS tidak akan menyambungnya.
- Naik taraf HTTP -> HTTPS **hanya jika disahkan**: 8/30 stesen http Malaysia (RTM Nasional FM, Asyik FM, Klasik
  Nasional, Langkawi FM, Keningau FM, WAI FM Iban...), 9/29 Indonesia, 24/42 Japan menyiar audio melalui HTTPS;
  selebihnya tiada HTTPS dan kekal tersembunyi (ADR 0010 tidak dilonggarkan). Semakan: maks. 30 stesen, 8 selari,
  had 5 saat, hanya pengepala dibaca, keputusan diingat untuk sesi. Privasi dikemas kini (pelayan stesen dihubungi).
- Tajuk ICY ("Artis - Lagu") dipaparkan pada pemain kecil, pemain penuh dan skrin kunci; tajuk kosong/URL/nama stesen
  dibuang (`cleanStreamTitle`). Tidak tersedia untuk strim HLS dan stesen yang tidak menghantarnya.
- Stesen Kegemaran (bintang; pada peranti, maks. 60, dipadam oleh "Padam semua data saya") dan ingatan stesen
  gagal 24 jam (dibenam ke bawah senarai, bukan disembunyikan, kerana kegagalan bergantung pada lokasi).
- Kawasan Japan dan J-pop (Radio Browser `countrycode=JP`, `tag=jpop`); "Melayu" dalam teks muzik jadi "Malay".

**Had:** ICY tidak diuji pada peranti. Kegemaran menyimpan URL strim semasa penyimpanan: stesen yang berpindah
URL perlu disimpan semula. Stesen yang hilang dari Radio Browser: lihat Semakan 1.3.

### Semakan 1.3: stesen disahkan dan ukuran tab Lagu

**Stesen disahkan (`curated_stations.dart`).** Senarai "tertinggal" pada 1.2 sebahagiannya salah: Hitz, Sinar, Mix,
Lite, Melody, Fly, Hot FM, Zayan, Raaga dan Eight sebenarnya ada dalam Radio Browser (Hitz sekadar tamat masa
sekali semasa ukuran). Yang benar-benar hilang atau rosak: ERA, Suria FM, THR Gegar. URL calon daripada direktori
awam disahkan sendiri (sambungan sebenar, audio diterima, segmen HLS diambil) sebelum dimasukkan:
- Suria FM, Sabah FM, Sarawak FM: mount StreamTheWorld `*_FMAAC_SC`; `icy-name` strim sepadan dengan stesen.
- ERA dan THR Gegar: Revma (ID `crec9cmbv4uvv`, `cn0zcqsbv4uvv`, akhiran sama seperti stesen Astro lain). URL penuh
  `.../playlist.m3u8` bagi ERA dalam direktori itu mengembalikan HTTP 400 (basi); bentuk asas `stream.rcs.revma.com/<id>`
  berfungsi dan membawa ICY. Revma hanya memulangkan ID sebagai `icy-name`, jadi **identiti ERA bergantung pada
  direktori awam ditambah semakan kandungan** (lagu yang bersiaran ialah lagu Melayu, "Insomniacks, Yonnyboii -
  Bersuara"). Jika pengguna melaporkan salah stesen, buang entri ini.
- Digabung ke hadapan senarai Malaysia; stesen Radio Browser dengan nama sama (atau sama + frekuensi) diganti;
  jika direktori tidak dapat dicapai senarai ini masih dipaparkan. Semak semula: `python3 -I
  tools/radio/check_curated_stations.py`. Tiada token dilangkau dan tiada wilayah dipintas.
- **Tidak boleh ditambah:** J-WAVE, TOKYO FM, NACK5 (dan Inter FM, FM Yokohama) hanya disiarkan melalui radiko yang
  dikunci kepada Japan tanpa strim awam; mengambilnya bermakna memintas sekatan wilayah. Molek FM, Kool 101, Salam FM
  dan Capital FM: tiada URL awam ditemui (mount StreamTheWorld yang dicuba tidak wujud). Tidak diteka.
  Japan kekal dilayan oleh NHK World, Listen.moe, Gensokyo, BOX City Pop, asia DREAM radio, J1 Hits (semuanya sah dan
  disahkan menyiar).

**Tab Lagu (Audius) diukur semula**, 300 hasil teratas setiap pertanyaan. Angka kelihatan banyak ("Malay" 290,
"K-pop" 297) tetapi itu padanan teks pada tajuk/nama pengguna, bukan lagu bahasa itu: "Malay" -> "Green Malay",
"SPRUNG (feat. Malay)"; "Indonesia" -> "Bangga Indonesia (Remix)"; "K-pop" -> remix demo/produser; "Spring" ->
"Flume & Eprom - Spring". Dikira berapa hasil yang benar-benar menyebut nama artis (padanan serpihan perkataan
lain dibuang secara manual): Siti Nurhaliza 3 (remix DJ dan satu penyanyi lain), Ziana Zain 0, Awie 0, Dewa 19 1 (audio
lirik muat naik pengguna), Sheila on 7 9 (muat naik pengguna), Spring/Tulus/Raisa 0 artis berkenaan (hanya perkataan
"spring" atau serpihan nama lain). BTS/BLACKPINK/NewJeans: remix dan muat naik pengguna, bukan rilis rasmi
(sebahagiannya tampak seperti salinan tidak berlesen, risiko semakan Play).
Kesimpulan: tab Lagu **tidak** menyediakan katalog Melayu/Indonesia/Korea/Japan arus perdana; cip cadangan di situ
memberi hasil bising untuk bahasa/negara. Radio ialah laluan yang berfungsi. Cadangan terbuka: cip Malay/Indonesia/
Japan/K-pop membuka tab Radio pada kawasan itu (belum dibuat; mengubah tingkah laku cip sedia ada).

## Semakan 1.4 (lagu penuh: Apple Music, dan sumber percuma yang ditolak)

**Keperluan:** lagu **penuh** (bukan pratonton 30 saat, bukan radio) untuk Melayu/Indonesia/Korea/Japan arus perdana,
percuma dan boleh diterbitkan di Play Store dan App Store. Keputusan diserahkan kepada penulis app.

**Sumber yang diukur dan ditolak** (semua diukur terus, tarikh 2026-10-31):
- **Internet Archive:** volum besar (Siti Nurhaliza 62 item, Sheila on 7 139, Dewa 19 127, dangdut 2,245, K-pop 1,072,
  city pop 799) tetapi kandungan ialah muat naik pengguna bagi album komersial ("DEWA 19 Full Album", Mariya Takeuchi
  "30th Anniversary") dengan label "Public Domain" yang diletak sendiri oleh penuggah. Hampir pasti tanpa kebenaran
  pemilik hak; risiko dasar IP Play/App Store. **Ditolak.**
- **Openverse** (agregat Jamendo/Wikimedia/Freesound; tanpa kunci, anonim 20/min dan 200/hari): "Siti Nurhaliza",
  "Melayu", "Malaysia", "dangdut", "keroncong", "lagu raya", "J-pop" 0 hasil; "Malay" 1, "K-pop" 1, "Korean" 10,
  "Japanese" 147 (padanan tajuk seperti "16 Japanese Words"). Hanya lesen komersial: Malay/K-pop/J-pop/dangdut 0. Hampir
  semua `by-nc-*`. Carian tidak berstruktur memakan 25 hingga 50 saat dan beberapa ralat HTTP. Terma: wajib nyatakan
  "dibuat menggunakan Openverse"; mereka berhak mengenakan bayaran untuk penggunaan komersial. **Tidak dimasukkan:** tiada
  faedah untuk sasaran dan menambah kos latensi serta kewajipan lesen.
- **Free To Use:** tiada API awam (laman ialah kulit JavaScript; hanya imej lesen peribadi/komersial) dan kandungannya
  muzik latar untuk pencipta kandungan. Endpoint dalaman yang tidak didokumenkan tidak digunakan.
- **ccMixter:** carian kabur ("malay" -> "Himalayan Freedom"). **Jamendo terus:** perlu `client_id`, terma menuntut lesen
  berbayar untuk penggunaan komersial, kandungan indie.
- **SayaMusicAPI / Free Music Search / CCMusic Search:** hanya membungkus API di atas; SayaMusicAPI memanggil JioSaavn
  (RPC laman tidak rasmi dengan User-Agent palsu) dan metadata lalu pelayan pihak ketiga. **Unstream:** kaedah tidak
  rasmi. **Navidrome/Ampache/Gonic/Koel/Black Candy:** pelayan untuk fail milik sendiri, tiada katalog.
- Spotify (Premium sahaja, mod pembangun 25 pengguna), YouTube (lihat 1.1/1.2).

**Keputusan: Apple Music melalui MusicKit (iOS), untuk pelanggan.** Satu-satunya laluan sah ke katalog label penuh
(Siti Nurhaliza, Spring, Awie, K-pop, J-pop, Indonesia) dengan SDK rasmi. Pelaksanaan:
- `packages/fg_apple_music` (plugin natif iOS, Swift): `MusicAuthorization`, `MusicCatalogSearchRequest` (lagu sahaja),
  `ApplicationMusicPlayer`. Tiada token pembangun dalam kod: MusicKit meminta sendiri bagi identiti app apabila
  perkhidmatan MusicKit diaktifkan pada App ID. Saluran `fgmaps/apple_music` dan `.../events` (gambar pemain 0.5 s).
- Dart: `TrackSource.appleMusic`, `AppleMusicEngine`, `RoutingMusicEngine` (just_audio untuk radio/Audius/fail, MusicKit
  untuk Apple; satu enjin aktif; gambar enjin tidak aktif dibuang), `AppleMusicController`. Carian Lagu: Apple Music
  dahulu kemudian Audius, setiap sumber gagal berasingan.
- Kebenaran **tidak pernah diminta sendiri**; dialog sistem hanya muncul apabila pengguna mengetik "Sambung Apple Music".
  `NSAppleMusicUsageDescription` ditambah (tanpanya iOS menamatkan app apabila kebenaran diminta).
- Privasi: tiada akaun/token/sejarah diterima app; dasar privasi (BM/EN) dan ujian `legal_test` mewajibkan "Apple Music".
- Android: tiada kesan (kad tidak dipaparkan). SDK Android MusicKit ialah binari yang dimuat turun secara manual daripada
  Apple (versi yang ditemui 2021) dan tidak disertakan; **majoriti pengguna Malaysia ialah Android, jadi ciri ini
  hanya sampai kepada pelanggan iPhone.**

**Had yang diketahui (jujur):**
- MusicKit tiada kawalan kelantangan: suara navigasi **menjeda** lagu Apple Music (walaupun mod "perlahankan"), lalu
  menyambung. Penyama dan slider kelantangan app tidak berkesan pada lagu Apple Music.
- Baris gilir tidak boleh bercampur Apple + Audius: mengetik lagu Apple hanya menyusun lagu Apple dalam hasil itu.
- Skrin kunci/Now Playing lagu Apple diurus MusicKit sendiri (perkhidmatan audio app tidak dimulakan untuknya).
- **Pengesahan:** kod Swift lulus `swiftc -typecheck` terhadap SDK iPhoneOS 27.1 (peranti dan simulator); logik Dart
  diuji dengan saluran palsu. **Belum diuji pada peranti sebenar** dengan langganan Apple Music: carian katalog
  storefront `my`, main, perubahan lagu, jeda/sambung suara navigasi dan skrin kunci perlu diuji tangan.

**Untuk menghidupkan dalam release (langkah penulis app, tidak boleh dibuat dalam kod):**
1. developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > `com.fguniversal.fgmap` > App Services >
   hidupkan **MusicKit**; jana semula profil provisioning.
2. Bina dengan `--dart-define=APPLE_MUSIC=true` (lalai: hidup dalam debug/profile, **mati dalam release** supaya pengguna
   tidak melihat kad yang belum berfungsi).
3. Uji pada iPhone dengan langganan Apple Music aktif sebelum menghantar ke semakan.
