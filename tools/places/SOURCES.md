# Sumber data tambahan Malaysia (`tools/places/extra/`)

Lapisan ini diserap oleh `build_places.py` pada setiap publish tiles. **Bukan** API langsung
dalam app, dan **bukan** Google Places/Maps (ToS melarang dump/scrape untuk pangkalan saingan).

## Dibenarkan (redistributable)

| Sumber | Apa | Lesen (semak semula sebelum import) | Cara |
| --- | --- | --- | --- |
| [Overture Maps Places](https://docs.overturemaps.org/) | POI MY bbox | CDLA Permissive 2.0 | `import_overture.py` → `extra/overture_my.geojson` (bulanan) |
| Curated landmarks FGMaps | Alias KLCC / Pavilion / UiTM / … | Nama awam; koordinat kasar OSM | `extra/landmarks_my.geojson` (dikemas kini bila perlu) |
| CSV/GeoJSON pemilik | POI sah milik/izin | Mestilah boleh diedarkan semula | Letak `extra/*.csv` atau `*.geojson` |
| [data.gov.my](https://data.gov.my/) | Dataset kerajaan yang dilabel terbuka | Biasanya CC BY / Open Data MY — **baca lesen setiap dataset** | Eksport CSV → `extra/`; dokumentasikan URL + tarikh dalam commit |
| Portal OpenData negeri | Hospital / IPT / kemudahan jika CC BY | Semak lesen portal negeri | Sama seperti di atas |

### Calon kategori (hanya jika lesen jelas)

- **Hospital / KKM:** cari dataset fasiliti kesihatan pada data.gov.my atau portal KKM yang
  menyatakan lesen terbuka. Jangan scrape direktori tanpa lesen.
- **Stesen minyak:** senarai rasmi Petronas/Shell/dll. hanya jika terbit sebagai open data atau
  kebenaran bertulis; jika tidak, kekalkan OSM + Overture.
- **IPT / kampus:** koordinat kampus awam dari portal IPT atau data.gov.my jika CC BY.

Jika lesen kabur, **langkau** sumber itu. Jangan commit data berlesen terhad ke `extra/`.

## Ditolak

- Google Places API / Maps POI dump atau scrape (bulanan atau sekali sahaja)
- HERE / TomTom / bil per-permintaan untuk membina indeks saingan
- Sebarang CSV yang asalnya daripada Google tanpa kebenaran

## Segar bulanan

1. Jalankan Overture (lihat `README.md`).
2. Semak data.gov.my / OpenData negeri untuk dataset baharu yang CC BY; ganti CSV dalam `extra/`.
3. Kemas kini `landmarks_my.geojson` jika alias baharu diperlukan.
4. Commit `extra/` → push `main` **atau** Actions → **tiles** → Run workflow.
5. Dalam app: Settings → Peta offline → kemas kini pek.

## Atribusi

- OSM: ODbL (Geofabrik extract).
- Overture Places: CDLA Permissive 2.0 + atribusi Overture Maps Foundation.
- Dataset kerajaan: ikut syarat CC BY / portal (nama agensi + pautan dataset dalam mesej commit).
