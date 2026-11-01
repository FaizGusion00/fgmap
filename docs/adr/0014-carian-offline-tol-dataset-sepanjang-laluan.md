# ADR 0014: Carian offline, tol daripada dataset, dan carian sepanjang laluan gabungan

Status: diterima (2026-11-01). Indeks dibina oleh `tools/places/build_places.py` dan diterbitkan oleh
`.github/workflows/tiles.yml` bersama pek laluan. App: `features/search/data/offline_places_db.dart`,
`offline_geocoder.dart`; tol: `route_preview/data/toll_finder.dart` (`DatasetTollFinder`).

## Konteks

Ujian pemilik pada telefon sebenar:
- Peta offline hanya mengandungi tile **laluan** Valhalla. Tanpa internet, carian tempat gagal sepenuhnya.
- Kad laluan memaparkan "Tol" tanpa harga. Plaza dicari melalui Overpass (kotak sempadan seluruh laluan),
  satu laluan demi satu, hanya selepas SEMUA calon laluan selesai. Setiap kelompok laluan baharu pula
  memadam anggaran yang sudah ada.
- R&R dan minyak cepat; EV, surau dan tandas sangat perlahan. Hanya R&R/minyak dipra-muat, kategori lain
  bermula sejuk, dan semuanya berebut cermin Overpass awam dengan carian plaza tol.

Ukuran 2026-11-01, laluan KL→Ipoh (203 km):
- overpass-api.de: 35–46 s untuk SETIAP kategori lama.
- overpass.openstreetmap.fr: polyline gabungan 9.5 s; kotak gabungan 5.8 s.

## Keputusan

1. **Indeks carian offline dalam pek peta.** SQLite + FTS4 (tokenizer `simple`) dibina daripada ekstrak
   Geofabrik yang sama dengan pek laluan:
   - penempatan;
   - jalan bernama (satu baris setiap nama setiap ~2 km);
   - POI: minyak, EV, masjid/surau, tandas, R&R, hospital, makan, kedai besar, hotel, pelancongan,
     pengangkutan, pendidikan dan kerajaan;
   - termasuk tapak multipoligon (cth. Hospital Kuala Lumpur, Masjid Putra).

   Saiz (ukuran 2026-11-01): 322,201 tempat, **18.5 MB** muat turun, 47.8 MB pada telefon. Carian
   0.5–10 ms.
   - **Kenapa FTS4/`simple`, bukan FTS5:** hanya ini dijamin dalam SQLite sistem setiap versi Android.
     App membaca melalui `sqflite` (sudah ada secara transitif), jadi tiada pustaka natif baharu.
   - **Manifest:** medan `places` pilihan. Manifest lama tanpanya kekal sah, dan entri rosak diabaikan.
     Kegagalan memasang indeks **tidak** menggagalkan pek laluan. Pek laluan versi sama tidak dimuat
     turun semula bila hanya indeks yang baharu.
   - **Carian (`geocoderProvider`):** Photon → Nominatim seperti dahulu. Indeks offline berjalan serentak
     dan digunakan bila rangkaian gagal atau tamat masa (6 s). Bila dalam talian memberi kurang 8 hasil,
     padanan offline yang tiada pendua ditambah di hujung.
   - **Berdekatan:** Overpass → indeks offline → Nominatim.

2. **Tol daripada dataset, bukan Overpass.**
   - Koordinat plaza dalam `assets/tolls/my_tolls.json` dipadankan terus ke garisan laluan (≤ 60 m).
     Serta-merta, berfungsi tanpa internet, dan tidak lagi membebankan Overpass.
   - Overpass hanya sandaran bila dataset tiada plaza tetapi laluan melalui ≥ 2 km jalan bertol.
   - Anggaran dikira bagi setiap kelompok laluan secara serentak dan dikekalkan antara kelompok.
   - Kad memaparkan "RM x" (atau "RM x+") terus, termasuk lembaran "Tukar laluan" semasa navigasi.
   - Ujian: Jalan Duta → Ipoh (S) = RM 21.73 daripada dataset.

3. **Sepanjang laluan: satu permintaan untuk lima kategori.**
   - Indeks offline dahulu (jika ada): tiada rangkaian.
   - Jika tiada indeks: satu pertanyaan Overpass berkotak (12 km setiap kotak, tiga penyata berindeks).
     Kategori diasingkan pada telefon, dan setiap satu ditapis mengikut koridornya.
   - `building=mosque` dibuang: ia biasanya pendua poligon dan memperlahankan pelayan.
   - Cermin yang menang terakhir dicuba dahulu kali seterusnya.
   - Hasil disimpan pada cakera 24 jam (6 laluan terakhir), dan dipadam oleh "padam data".

## Akibat

- Data offline sama umur dengan pek (dibina setiap minggu). Pengecas EV baharu mungkin belum ada sehingga
  pek seterusnya; dalam talian, carian biasa tetap menggunakan Photon/Overpass yang lebih terkini.
- Tile **paparan** peta (OpenFreeMap) masih dalam talian sahaja (ADR 0001). Tanpa internet, latar peta
  bergantung pada cache MapLibre. Ini langkah berasingan (PMTiles), belum dibuat.
- Kunci cache sepanjang laluan mengandungi koordinat titik laluan yang dibundarkan; disimpan pada
  peranti sahaja dan dipadam oleh "padam data" (ADR 0010).
