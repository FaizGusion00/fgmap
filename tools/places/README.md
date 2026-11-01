# Indeks carian tempat offline (pek FGMaps)

App **tidak** memanggil Google Places API secara langsung. Tempat Malaysia yang kaya datang
daripada **pek berjadual** yang dimuat turun sekali, sama aliran dengan peta offline
(ADR 0014 / 0016).

## Saluran data

| Lapisan | Sumber | Lesen | Jadual |
| --- | --- | --- | --- |
| Asas | Ekstrak Geofabrik MY–SG–BN (`tiles.yml`) → `build_places.py` | OSM ODbL | Mingguan (cron tiles) + setiap push ke skrip / `extra/` |
| Tag OSM lebih luas | Kedai bernama, leisure, pejabat, `landuse=residential` bernama | ODbL | Sama dengan asas |
| Overture Maps Places | `import_overture.py` → `extra/overture_my.geojson` | [CDLA Permissive 2.0](https://cdla.dev/permissive-2-0/) | Bulanan (mengikut keluaran Overture) |
| Landmark alias MY | `extra/landmarks_my.geojson` (KLCC, Pavilion, UiTM, …) | Nama awam / OSM | Bila alias baharu diperlukan |
| Open data MY | data.gov.my / OpenData negeri (hospital, IPT, …) | CC BY / lesen portal — **semak setiap dataset** | Bulanan; lihat `SOURCES.md` |
| Tambahan berkurasi | GeoJSON/JSON/CSV dalam `tools/places/extra/` | Dikawal pemilik (mestilah boleh diedarkan semula) | Bila-bila; diserap pada publish tiles seterusnya |

## Ditolak: Google Places / Google Maps POI

**Jangan** muat turun, scrape, atau bulk-cache Google Places / Google Maps POI untuk Malaysia
(walaupun “sekali setiap 6 bulan ke dalam pek”). ToS Google Places/Maps **melarang** membina
pangkalan tempat saingan daripada data mereka.

- Tiada kekunci API Google Places untuk dump pukal.
- Tiada skrip scrape Maps / Places.
- Tiada laluan “cache Google → `extra/`”.

Liputan offline = OSM (ODbL) + Overture (CDLA) + CSV/GeoJSON berkurasi pemilik yang sah untuk diedarkan.

## Import bulanan Overture (Malaysia)

Keperluan: Python 3.10+, `pip install duckdb`, rangkaian (S3 awam Overture).

1. Pilih id release semasa dari [Overture release notes](https://docs.overturemaps.org/release-schedule/)
   (cth. `2025-10-22.0`).
2. Eksport bbox MY–SG–BN ke `extra/`:

```bash
python3 tools/places/import_overture.py \
  --release 2025-10-22.0 \
  --out tools/places/extra/overture_my.geojson
```

3. (Pilihan) Letak CSV/GeoJSON berkurasi sendiri dalam `tools/places/extra/` — lihat format di bawah.
4. Commit fail `extra/` (dan skrip jika berubah), push ke `main` **atau** jalankan
   Actions → **tiles** → *Run workflow*. `tiles.yml` sudah memantau `tools/places/extra/**`
   dan `build_places.py`; `build_places.py` memuatkan semua `.geojson` / `.json` / `.csv` dalam
   `extra/` secara automatik.
5. Selepas Release `tiles` dikemas kini, penguji muat turun/kemas kini pek dalam app
   (Settings → Peta offline).

Ujian kecil (had baris):

```bash
python3 tools/places/import_overture.py --release 2025-10-22.0 --limit 500 \
  --out /tmp/overture_smoke.geojson
```

### Lesen & atribusi Overture

- Lesen data Places: **CDLA Permissive 2.0** — pengedaran semula dalam pek offline FGMaps dibenarkan.
- Atribusi yang disyorkan: “Overture Maps Foundation” (dan OpenStreetMap di mana data OSM digabung).
  Lihat [Overture attribution](https://docs.overturemaps.org/attribution/).
- Simpan medan `attribution` / `release` dalam GeoJSON keluaran; jangan buang nota lesen.

## Open data kerajaan (hospital / minyak / IPT)

Lihat `SOURCES.md`. Hanya import dataset yang **jelas** boleh diedarkan semula (biasanya CC BY
pada data.gov.my). Langkau Petronas/Shell/KKM jika tiada lesen terbuka — kekalkan OSM + Overture.
Jangan guna Google Places untuk mengisi jurang.

## CSV berkurasi (pilihan pemilik)

Contoh lajur (header wajib): lihat `tools/places/curated.example.csv`.

```text
name,lat,lon,alt,kind,area,rank
Kedai Contoh,3.1390,101.6869,Example Shop,shop,Kuala Lumpur,40
```

Letak fail sebenar sebagai `tools/places/extra/*.csv` (bukan fail `.example`). `kind` mesti
salah satu kunci dalam `CAT` skrip (`shop`, `food`, `tourism`, …). Tanpa `kind` → `other`.

## Saluran pek

1. `.github/workflows/tiles.yml` memuat turun PBF Geofabrik, bina tile Valhalla + `build_places.py`.
2. Skrip memuatkan `tools/places/extra/*.{geojson,json,csv}` secara automatik (jika folder wujud).
3. Manifest `places` (fail `.sqlite.gz`, saiz, sha256, `count`, `extraCount`) diterbitkan pada release `tiles`.
4. App: Settings → **Peta offline** (`showOfflineMapsSheet`). Indeks datang bersama pek; tiada suis carian berasingan.
5. Carian: Photon → Nominatim; indeks offline selari, mengisi bila rangkaian gagal/tamat masa atau hasil dalam talian &lt; 12.

Selepas merge yang mengubah liputan/FTS/skrip/extra: **jalankan semula workflow tiles** supaya pek baharu sampai ke penguji.

## Anggaran saiz

Ukuran asas 2026-11-01: ~322k baris, ~18.5 MB gz / ~48 MB pada telefon.
Peluasan tag (kedai/leisure/pejabat/taman bernama) dijangka **+10–25%** baris (~+2–5 MB gz) bergantung pada PBF;
lapisan `extra/` (Overture MY + CSV) biasanya beberapa MB gz — jangan commit fail beratus MB dalam PR app
tanpa semakan; biar workflow tiles menerbitkannya dalam Release.

## Format `extra/` GeoJSON

GeoJSON FeatureCollection atau senarai ciri. Setiap ciri:

```json
{
  "type": "Feature",
  "geometry": { "type": "Point", "coordinates": [101.6869, 3.1390] },
  "properties": {
    "name": "Contoh Destinasi",
    "alt": "Example Dest",
    "kind": "shop",
    "area": "Kuala Lumpur",
    "rank": 40
  }
}
```

`kind` mesti salah satu kunci dalam `CAT` skrip. Tanpa `kind` → `other`.
