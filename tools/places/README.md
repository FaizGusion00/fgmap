# Indeks carian tempat offline (pek FGMaps)

App **tidak** memanggil Google Places API secara langsung. Tempat Malaysia yang kaya datang
daripada **pek berjadual** yang dimuat turun sekali, sama aliran dengan peta offline
(ADR 0014 / 0016).

## Saluran data

| Lapisan | Sumber | Lesen | Jadual |
| --- | --- | --- | --- |
| Asas | Ekstrak Geofabrik MY–SG–BN (`tiles.yml`) → `build_places.py` | OSM ODbL | Mingguan (cron tiles) + setiap push ke skrip / `extra/` |
| Tag OSM lebih luas | Kedai bernama, leisure, pejabat, `landuse=residential` bernama | ODbL | Sama dengan asas |
| Overture Maps Places | `import_overture.py` → `extra/overture_my.geojson.gz` | [CDLA Permissive 2.0](https://cdla.dev/permissive-2-0/) | **Automatik** bulanan (`.github/workflows/places-overture.yml`) |
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

## Import bulanan Overture (automatik — tiada langkah tempatan untuk APK)

**Binaan APK / release app tidak memerlukan** menjalankan `import_overture.py` di laptop.
Workflow GitHub menguruskannya; pek offline datang daripada Release `tiles` selepas merge.

| Cara | Bila |
| --- | --- |
| Cron | `.github/workflows/places-overture.yml` — **1hb setiap bulan 04:17 UTC** (selepas workflow digabung ke `main`) |
| Manual | GitHub → **Actions** → **places-overture** → **Run workflow** (pilihan: `release`, `limit` ujian) |

Aliran automatik:

1. `import_overture.py --release latest` (STAC) → `tools/places/extra/overture_my.geojson.gz` + `.meta.json`.
2. Jika hash berbeza daripada `main`: bot membuka PR `cursor/overture-places-YYYYMM` (tiada PR kosong).
3. Selepas PR digabung ke `main`, `tiles.yml` (path `tools/places/extra/**`) membina semula indeks places ke Release `tiles`.
4. Dalam app: Settings → **Peta offline** → kemas kini pek.

Larian tempatan (pilihan / debug sahaja):

```bash
pip install duckdb
python3 tools/places/import_overture.py --release latest \
  --out tools/places/extra/overture_my.geojson.gz
# ujian kecil:
python3 tools/places/import_overture.py --release latest --limit 500 \
  --out /tmp/overture_smoke.geojson.gz
```

`build_places.py` memuatkan `extra/*.{geojson,geojson.gz,json,csv}` (abaikan `*.meta.json`).

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
