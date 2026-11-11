# Dataset kamera kelajuan

Aset app: `app/assets/cameras/cameras_my.json` (dimuat oleh `AwasCameraStore`, tanpa rangkaian).

Sumber:

- `awas_curated.json` — pin AwAS JPJ yang dikurasi dengan tangan daripada senarai rasmi JPJ (PDF), cth.
  https://www.jpj.gov.my/wp-content/uploads/2025/04/LOKASI-PENGUATKUASAAN-KAMERA-AwAS-TERKINI-15.07.2024-1-1.pdf
- OpenStreetMap `highway=speed_camera` dalam Malaysia (Overpass, ODbL).

## Menjana semula

```sh
python3 -I tools/cameras/build_cameras.py            # muat turun OSM + jalan, tulis aset
python3 -I tools/cameras/build_cameras.py --osm-file osm.json   # guna respons Overpass sedia ada
cd app && flutter test test/features/cameras/
```

Peraturan (lihat docstring skrip):

1. Pin AwAS disimpan hanya jika ≤150 m dari jalan motorway/trunk/primary OSM (`high` ≤60 m, selain itu
   `approx`); yang lain dibuang dan disenaraikan dalam output skrip serta `note` aset.
2. Semua kamera OSM disertakan (`high`); `direction` yang bercanggah dengan bound dalam nama, atau tidak
   selari dengan jalan dalam 60 m, dibuang (arah tidak diketahui = amaran semua arah).
3. Kamera OSM dalam 300 m daripada pin AwAS yang serasi (jenis + arah) digabung: koordinat OSM, nama/bound
   AwAS.

Menambah pin AwAS: kemas kini `awas_curated.json`. **Jangan** cipta pin jika keyakinan rendah.

Ini **bukan** daftar lengkap semua kamera Malaysia (polis bergerak, AES lain, dll.).
