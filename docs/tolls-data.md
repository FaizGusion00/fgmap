# Data kadar tol (`app/assets/tolls/my_tolls.json`)

## Keadaan semasa

| Liputan | Sumber | Status |
|---|---|---|
| Sistem **tertutup**: PLUS (Utara-Selatan, ELITE, KLIA), LPT1, WCE, LEKAS, SKVE, SDE | Kalkulator tol rasmi Lembaga Lebuhraya Malaysia (LLM), melalui rangkak awam `mohdsyahid/kadar-tol-malaysia` (MIT) | Ada, kelas 1 (kereta) |
| Lebuh raya **harga tetap** yang pengendalinya menyiarkan jadual teks: LDP, SPRINT (LITRAK), KESAS, LLB (Butterworth), MEX, AKLEH, GCE, LKSA, SILK, SUKE, DASH (Prolintas) | Halaman tambang rasmi pengendali (URL dan tarikh ambil disimpan bagi setiap entri) | Ada, kelas 1 |
| Lain-lain harga tetap (NPE, BESRAYA, DUKE, SPE, KLK, GCE/LATAR lain, jambatan Pulau Pinang, SMART, dll.) | Tiada jadual teks rasmi ditemui (DUKE hanya imej tidak bertarikh; LLM tiada kadarnya) | **Tidak diketahui** |
| Motosikal | LLM tiada kelas motosikal | **Tidak diketahui** (bukan percuma, bukan kelas lain) |

Tiada angka direka. Sumber pihak ketiga yang menyenaraikan kadar saling **bercanggah** (cth. Jalan Duta ke
Ipoh Kelas 1: RM21.73 pada satu tapak, RM17.50 pada yang lain), jadi tiada satu pun dipakai.

Kelas kenderaan LLM (`transCode`): 1 = kereta, 2 = van/lori kecil, 3 = lori besar, 4 = teksi (50% kelas 1),
5 = bas (75% kelas 1). Disahkan daripada data (Alor Pongsu ke Alor Setar: kelas 1 RM1.64, kelas 4 RM0.82,
kelas 5 RM1.23). Pembetulan: versi 0.5.0 tersilap memetakan motosikal ke kelas 4 (teksi).

## Cara data dijana

`tools/tolls/build_tolls.py` (tanpa kebergantungan) dijalankan oleh `.github/workflows/tolls-data.yml`
(setiap Isnin, atau apabila skrip/alias berubah, atau secara manual). Runner GitHub boleh mencapai Overpass;
persekitaran pembangunan tidak boleh.

1. Muat turun JSON kadar (setiap pasangan plaza masuk-keluar) daripada `mohdsyahid/kadar-tol-malaysia`.
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

- **Plaza masuk tidak dipadankan**: jika plaza masuk sistem tertutup tiada koordinat atau tidak dikesan OSM,
  larian bermula di plaza seterusnya dan kos boleh **kurang daripada sebenar** tanpa amaran. Plaza yang
  tidak dipadankan disenaraikan dalam laporan workflow; tambah alias jika perlu.
- Lebuh raya harga tetap: perjalanan campuran (cth. KLCC ke KLIA melalui AKLEH, SPE, MEX) dipaparkan "RM x+".
- Anggaran ialah kelas 1, lalu lintas biasa; tiada diskaun/hari kenaan/kad diskaun.
- Kadar baharu (gazet) hanya masuk selepas sumber LLM dan workflow dijalankan semula.
- Sumber ialah rangkak awam bagi kalkulator LLM oleh pihak ketiga (satu penyelenggara); koordinat plaza
  daripada OpenStreetMap (ODbL, atribusi diperlukan).
- Pencarian plaza memerlukan internet (Overpass); luar talian = tiada maklumat plaza (jalan bertol Valhalla
  masih ada). Tol tanpa palang (MLFF) mungkin tiada dalam OSM.
- Padanan dan pengiraan belum diuji pada peranti dengan laluan sebenar; sahkan beberapa laluan yang diketahui.
