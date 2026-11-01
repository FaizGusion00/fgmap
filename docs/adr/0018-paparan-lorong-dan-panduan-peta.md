# ADR 0018: Paparan lorong, anak panah arah, label belokan dan pin tempat

Status: diterima. Dilaksanakan dalam app (potret); Android Auto menerima lorong sebenar; CarPlay hanya
ayat sisi. Lihat "Had" untuk apa yang belum disahkan pada peranti.

## Konteks

Pemandu (kereta dan motosikal) paling terbantu apabila simpang yang rumit ditunjukkan dengan jelas:
lorong mana yang patut diambil, jalan mana yang dimasuki, dan tempat yang dikenali (stesen minyak,
kedai) sebagai penanda. Data lorong sebenar datang daripada Valhalla (`turn:lanes` OSM) tetapi **jarang
ada di Malaysia**. Server awam FOSSGIS yang dipakai (ADR 0004) tidak memberi data lorong yang tiada
dalam OSM.

## Keputusan

### Kotak lorong (`LanePanel`, `lane_plan.dart`)
- Dua sumber, satu rupa: data sebenar (`LanePlan.estimated == false`) dan **anggaran** yang diterbitkan
  daripada jenis manuver (lalu lintas kiri: belok kanan = lorong paling kanan, dll.). Anggaran hanya
  menyebut **sisi** dan ditanda "Anggaran lorong" pada kotak; ia tidak mengaku tahu bilangan lorong.
- Kotak muncul pada jarak mengikut kelajuan dan kenderaan (`laneViewWithinM`: kereta 200-500 m,
  motosikal 260-650 m). Pada jarak lebih jauh (hingga 700 m) hanya jalur kecil atau ayat.
- Potret sahaja. Mendatar (~390 px tinggi) kekal dengan jalur/ayat ringkas supaya jalan di hadapan
  tidak terlindung.
- Dalam lorong yang disyorkan hanya arah yang sebenarnya disyorkan menyala (`LaneSlot.highlighted`);
  "lurus" dalam lorong "lurus + kanan" dimalapkan.
- Bulatan: gambar atas ke bawah dengan keluar yang diambil disorot. Valhalla hanya memberi nombor
  keluar, bukan jumlah keluar, jadi jalan lain dilukis skema (sekurang-kurangnya tiga keluar) tanpa
  dakwaan bilangan sebenar. Gambar ini hiasan sahaja untuk pembaca skrin (glif kad sudah menyebut keluar).
- Mod mudah (kontras tinggi) menyorot dengan warna kad (putih/kuning), bukan biru.

### Peta
- **Anak panah arah** (`fg-route-chevrons`): titik tetap pada jalan setiap 50 m (kelipatan jarak
  laluan, bukan relatif kepada kereta, supaya tidak "berjalan" bersama kereta), 14 anak panah di
  hadapan, dihantar semula hanya apabila yang pertama bertukar. Disembunyikan apabila laluan lapuk.
- **Label belokan**: nama jalan yang dimasuki di titik belok (dalam 1000 m), teks putih dengan halo
  warna laluan.
- **Pin tempat** (hanya semasa navigasi): lapisan `poi` jubin OpenMapTiles untuk sembilan kategori
  (`poi_category.dart`); ikon POI gaya asal (`poi_r1/r7/r20`) disembunyikan supaya tidak bertindih.
- Sifat lapisan ialah fungsi tulen (`overlay_layer_props.dart`) supaya ungkapan gaya boleh disahkan
  terhadap `@maplibre/maplibre-gl-style-spec`.

### Kereta
- **Android Auto**: hanya lorong **sebenar** dihantar (`carLanesFor`), kerana UI lorong asli kereta
  tiada label anggaran. `Step.addLane` + `setLanesImage` (imej dilukis dalam `CarLanes.kt`); jika apa-apa
  gagal, lorong digugurkan dan manuver kekal. Tanpa data lorong, ayat sisi menjadi `cue`.
- **CarPlay**: hanya ayat sisi sebagai varian arahan. `CPLaneGuidance`/`CPLane` (iOS 17.4/18) **tidak**
  digunakan: konvensyen sudut tidak didokumenkan dalam SDK dan tidak dapat disahkan tanpa CarPlay
  sebenar; lorong tercermin lebih buruk daripada tiada lorong.

## Had
- Lapisan MapLibre (anak panah, label, pin) disahkan terhadap spesifikasi gaya dan ujian unit, tetapi
  belum dilihat pada peranti/emulator dalam sesi ini; `CarLanes.kt` dikompil tetapi belum diuji pada
  kepala unit atau DHU; Swift dikompil terhadap SDK iOS sahaja.
- Anggaran lorong tidak tahu bilangan lorong sebenar. Penambahbaikan sebenar ialah set data lorong
  untuk simpang utama (keputusan berasingan).
