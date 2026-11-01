# Indeks carian tempat offline (pek FGMaps)

App **tidak** memanggil Google Places API secara langsung (kos selepas ~10k permintaan).
Tempat Malaysia yang kaya datang daripada **pek berjadual** yang dimuat turun sekali, sama
aliran dengan peta offline (ADR 0014 / 0016).

## Saluran data

| Lapisan | Sumber | Lesen | Jadual |
| --- | --- | --- | --- |
| Asas | Ekstrak Geofabrik MY–SG–BN (`tiles.yml`) → `build_places.py` | OSM ODbL | Mingguan (cron tiles) + setiap push ke skrip |
| Tag OSM lebih luas | Kedai bernama, leisure, pejabat, `landuse=residential` bernama | ODbL | Sama dengan asas |
| Tambahan berkurasi | Fail GeoJSON/JSON dalam `tools/places/extra/` | Dikawal pemilik (mestilah boleh diedarkan semula) | Bulanan digalakkan (atau ikut rebuild tiles) |
| Overture Maps Places (pilihan) | Eksport wilayah MY → tukar ke GeoJSON `extra/` | [CDLA Permissive 2.0](https://cdla.dev/permissive-2-0/) — OK untuk diedarkan; **bukan** Google | Bulanan / mengikut keluaran Overture |

**Ditolak:** kekunci Google Places / bil per-permintaan dalam app. “Salin/kemas kini lokasi mengikut jadual,” bukan pertanyaan langsung.

## Saluran pek

1. `.github/workflows/tiles.yml` memuat turun PBF Geofabrik, bina tile Valhalla + `build_places.py`.
2. Skrip memuatkan `tools/places/extra/*.{geojson,json}` secara automatik (jika folder wujud).
3. Manifest `places` (fail `.sqlite.gz`, saiz, sha256, `count`, `extraCount`) diterbitkan pada release `tiles`.
4. App: Settings → **Peta offline** (`showOfflineMapsSheet`). Indeks datang bersama pek; tiada suis carian berasingan.
5. Carian: Photon → Nominatim; indeks offline selari, mengisi bila rangkaian gagal/tamat masa atau hasil dalam talian &lt; 12.

Selepas merge yang mengubah liputan/FTS/skrip: **jalankan semula workflow tiles** supaya pek baharu sampai ke penguji (muat turun/kemas kini dalam app).

## Anggaran saiz

Ukuran asas 2026-11-01: ~322k baris, ~18.5 MB gz / ~48 MB pada telefon.
Peluasan tag (kedai/leisure/pejabat/taman bernama) dijangka **+10–25%** baris (~+2–5 MB gz) bergantung pada PBF;
lapisan `extra/` kecil (ratusan–beberapa ribu POI) menambah &lt;1 MB. Jangan commit fail pek beratus MB dalam PR app — biar workflow tiles menerbitkannya.

## Format `extra/`

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

`kind` mesti salah satu kunci dalam `CAT` skrip (`shop`, `food`, `tourism`, …). Tanpa `kind` → `other`.
