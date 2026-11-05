# Data kadar tol (`app/assets/tolls/my_tolls.json`)

## Keadaan semasa

| Liputan | Sumber | Status |
|---|---|---|
| Sistem **tertutup**: PLUS (Utara-Selatan, ELITE, KLIA), LPT1, WCE, LEKAS, SKVE, SDE | Kalkulator tol rasmi Lembaga Lebuhraya Malaysia (LLM), **dirangkak terus** (`tools/tolls/llm_api.py`) | Ada, kelas 1 (kereta) |
| Semua lebuh raya **harga tetap** dalam kalkulator LLM (KESAS, LDP, SPRINT, NPE, BESRAYA, DUKE, SUKE, LATAR, KLK, SMART, LINKEDUA, BKE, SPDH, GRANDSAGA, jambatan Pulau Pinang, dll.) | Kalkulator LLM (`getTollRate/<lebuh raya>/<plaza>/null`) | Ada, kelas 1, jika plaza dapat dipadankan dengan OSM |
| Sandaran jika LLM tidak dapat dicapai | `mohdsyahid/kadar-tol-malaysia` + halaman tambang pengendali (`open_sources.py`, `reported_sources.json`) | Sandaran sahaja |
| Motosikal | LLM tiada kelas motosikal | **Tidak diketahui** (bukan percuma, bukan kelas lain) |

Dalam app, halaman **CCTV & tol** juga ada kalkulator LLM langsung (semua 5 kelas) untuk semakan tepat.

### Padanan plaza: titik booth, bukan purata (1.7.0)

Plaza persimpangan ada booth di kedua-dua belah lebuh raya. Sebelum 1.7.0 koordinat plaza ialah purata semua
booth dalam 1.5 km, yang bagi plaza seperti Port Dickson, Seremban dan Ebor jatuh **di atas laluan utama**:
setiap kenderaan yang lalu "melalui" plaza itu. Jika plaza masuk/keluar sebenar tidak dikesan, plaza palsu ini
menjadi masuk/keluar dan harga jatuh ke pasangan bersebelahan (laporan penguji: Setia Alam ke JB "RM1.72").

Sekarang setiap plaza membawa `booths` (titik booth OSM sebenar). Booth yang ialah nod jalan OSM (`boothsOnWay`,
~98%) dipadankan dalam 6 m: garisan Valhalla mengikut jalan yang sama dan melalui nod itu (< 1 m), jadi laluan
utama yang lalu 10-20 m di sebelah booth susur (cth. SPE di Setiawangsa) tidak dikira. Booth lain: 25 m. Booth
yang sudah menjadi plaza sistem tertutup tidak dipakai semula oleh plaza harga tetap yang sama nama (Bukit Raja
NKVE lawan Grand Sepadu). Jaring keselamatan: jika jalan bertol berterusan > 15 km sebelum plaza masuk atau selepas plaza keluar
tanpa plaza lain, perjalanan itu **tidak diketahui** (bukan harga rendah). Ujian regresi:
`test/features/route_preview/toll_booths_test.dart` (laluan Valhalla sebenar Setia Alam ke JB = RM37.15).

Tiada angka direka. Sumber pihak ketiga yang menyenaraikan kadar saling **bercanggah** (cth. Jalan Duta ke
Ipoh Kelas 1: RM21.73 pada satu tapak, RM17.50 pada yang lain), jadi tiada satu pun dipakai.

Kelas kenderaan LLM (`transCode`): 1 = kereta, 2 = van/lori kecil, 3 = lori besar, 4 = teksi (50% kelas 1),
5 = bas (75% kelas 1). Disahkan daripada data (Alor Pongsu ke Bukit Merah: kelas 1 RM1.64, kelas 4 RM0.82,
kelas 5 RM1.23). Pembetulan: versi 0.5.0 tersilap memetakan motosikal ke kelas 4 (teksi).

## Cara data dijana

`tools/tolls/build_tolls.py` (tanpa kebergantungan) dijalankan oleh `.github/workflows/tolls-data.yml`
(setiap Isnin, atau apabila skrip/alias berubah, atau secara manual). Boleh juga dijalankan setempat:
`python3 tools/tolls/llm_api.py --cache c.json --out llm.json` kemudian
`python3 tools/tolls/build_tolls.py --llm-dataset llm.json --overpass-file overpass.json --out ... --report ...`.

1. Rangkak kalkulator LLM (`llm_api.py`: getHighway, getPlazaEnter, getPlazaExit, getTollRate; 4 permintaan
   serentak dengan jeda, ~7k permintaan). Jika gagal: JSON `mohdsyahid/kadar-tol-malaysia`.
2. Muat turun nod plaza OSM Malaysia (`barrier=toll_booth` / `highway=toll_gantry`) melalui Overpass.
3. Padankan nama plaza LLM dengan nama nod OSM (singkatan dinormalkan, arah S/U/B/T dipadankan, kelompok
   <= 1.5 km, pengendali digunakan untuk memutuskan kembar) untuk mendapatkan **koordinat**. Pengecualian
   manual: `tools/tolls/aliases.json` (kunci `"<id lebuh raya>:<nama plaza LLM>"`, nilai `osmName` atau
   `lat`/`lon` yang diambil daripada nod OSM sebenar).
4. Tulis `my_tolls.json` (skema 2) dan laporan padanan (plaza **tidak dipadankan** / **ambigu**, beserta calon
   OSM). Workflow meng-commit hasilnya ke branch supaya perubahan data kelihatan dalam kajian kod.

Lebuh raya harga tetap: `tools/tolls/open_sources.py` memuat turun halaman tambang pengendali dan menghurai
jadual kelas 1 dengan corak yang ketat; jika bentuk halaman berubah penghurai **gagal dengan jelas** (dilaporkan,
tiada angka lapuk ditulis). Koordinat plaza diambil daripada nod OSM yang namanya mengandungi kata kunci plaza DAN
pengendalinya sepadan (nama sahaja bercampur, cth. "Pantai" pada NPE dan SPRINT).

Plaza tanpa koordinat kekal dalam matriks tetapi tidak boleh dipadankan dengan laluan, jadi laluan yang
melaluinya dipaparkan sebagai sebahagian/tidak diketahui.

### Skema versi 2

```json
{
  "version": 2,
  "currency": "MYR",
  "source": "Lembaga Lebuhraya Malaysia (...)",
  "lastVerified": "2026-08-31",
  "closed": [
    {
      "id": "1",
      "name": "Lebuhraya Utara-Selatan (PLUS)",
      "plazas": [{ "id": "1", "name": "AYER KEROH", "lat": 2.27, "lng": 102.29 }],
      "matrix": [0.0, 1.2, "..."]
    }
  ],
  "open": []
}
```

- `matrix` ialah jadual N x N kadar kelas 1 (RM), baris = plaza masuk, lajur = plaza keluar, mengikut
  susunan `plazas`; `null` = tiada laluan/kadar.
- `lastVerified` ialah tarikh data LLM diambil (bukan tarikh gazet kadar).
- `open` (harga tetap): satu kadar setiap plaza `{id,name,lat,lng,type:"open",ratesRm:{"1":2.5},source,verifiedOn}`;
  `source` (URL) dan `verifiedOn` wajib, entri tanpa jejak dilangkau. Versi 1 (hanya `plazas`) masih dibaca.

`TollRates.parse` keras: versi tidak dikenali, matriks bukan N x N, nilai bukan nombor positif, dan koordinat
di luar Malaysia dilangkau; fail rosak memberi dataset kosong (app tidak rosak).

## Cara app mengira

- **Jalan bertol sebenar** laluan: daripada bendera `toll` manuver Valhalla (data OSM). Contoh KLCC ke KLIA:
  "Lebuhraya Maju (E20)", "E6".
- **Plaza tol**: dikesan daripada OSM (Overpass) dalam kotak sempadan laluan, dipadankan ke garisan laluan
  (<= 40 m) dan dikelompokkan (<= 150 m).
- Setiap plaza dipadankan dengan plaza dataset terdekat dalam 250 m.
- **Sistem tertutup**: dalam satu larian plaza **berturutan** pada sistem yang sama, plaza pertama = masuk dan
  plaza terakhir = keluar; kos = `matrix[masuk][keluar]`. Larian pada sistem berbeza dijumlah berasingan.
- Plaza tidak dipadankan, satu plaza tunggal pada sistem tertutup, atau pasangan tanpa kadar = tidak diketahui.

Anggaran dipaparkan sebagai "Tol RM x" hanya jika SEMUA plaza pada laluan ada harga; jika sebahagian,
"RM x+ (sebahagian)"; jika tiada, bilangan plaza sahaja. Sentiasa disertai penafian "anggaran sahaja".

## Had yang diketahui

- **Plaza tidak dipadankan / tiada dalam OSM**: plaza OSM pada laluan yang tidak sepadan dengan dataset dikira
  "tidak diketahui" dan memecahkan larian sistem tertutup, jadi jumlah dipaparkan "RM x+" (had bawah), bukan
  angka tepat. Kes senyap hanya jika plaza itu tiada langsung dalam OSM (tidak dikesan pada laluan): kos boleh
  kurang daripada sebenar tanpa penanda. Plaza yang tidak dipadankan disenaraikan dalam laporan workflow.
- Plaza OSM bernama sama pada lebuh raya berbeza (cth. "Putrajaya": ELITE dan MEX) dipadankan dengan koordinat
  manual dalam `aliases.json` (disahkan dengan laluan KLCC ke KLIA dalam `test/fixtures`).
- Kadar lebuh raya harga tetap diambil daripada halaman pengendali dan boleh lapuk jika pengendali lambat
  mengemas kini; setiap entri menyimpan URL sumber dan `verifiedOn`. Untuk SILK dan DASH hanya plaza yang
  disahkan (Sungai Balak; Kota Damansara) diberi harga; plaza lain kekal tidak diketahui kerana halaman
  pengendali tidak menyatakan plaza mana yang dimaksudkan.
- Lebuh raya harga tetap: perjalanan campuran (cth. KLCC ke KLIA melalui AKLEH, SPE, MEX) dipaparkan "RM x+".
- Anggaran ialah kelas 1, lalu lintas biasa; tiada diskaun/hari kenaan/kad diskaun.
- Kadar baharu (gazet) hanya masuk selepas sumber LLM dan workflow dijalankan semula.
- Sumber ialah rangkak awam bagi kalkulator LLM oleh pihak ketiga (satu penyelenggara); koordinat plaza
  daripada OpenStreetMap (ODbL, atribusi diperlukan).
- Pencarian plaza memerlukan internet (Overpass); luar talian = tiada maklumat plaza (jalan bertol Valhalla
  masih ada). Tol tanpa palang (MLFF) mungkin tiada dalam OSM.
- Padanan dan pengiraan belum diuji pada peranti dengan laluan sebenar; sahkan beberapa laluan yang diketahui.
