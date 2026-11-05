# Direktori Masjid & Surau (JAKIM)

`build_jakim.py` menghasilkan `app/assets/jakim/masjid_surau.json.gz` dan `meta.json` daripada senarai rasmi
JAKIM di data.gov.my (CC BY, data 2019):

- https://archive.data.gov.my/data/ms_MY/dataset/senarai-masjid-di-seluruh-malaysia
- https://archive.data.gov.my/data/ms_MY/dataset/senarai-surau-di-malaysia

Data JAKIM **tiada koordinat**. Koordinat tepat hanya diambil daripada OpenStreetMap (ODbL) apabila nama
masjid/surau sepadan dengan tempat OSM berhampiran pusat daerah yang sama (padanan unik sahaja). Selebihnya
dicari melalui alamat dalam app apabila pengguna menekan "Arah"/"Pergi", dan ditanda "lokasi anggaran".

Tiada geokod pukal: hanya ~190 pusat daerah, dicache dalam `district_centroids.json` (Nominatim, 1 permintaan
sesaat). Jangan tambah geokod alamat satu-satu untuk semua baris (melanggar dasar Photon/Nominatim).

```sh
python3 tools/jakim/build_jakim.py          # muat turun CSV + OSM, tulis aset app
```

Laporan padanan per negeri dicetak di hujung. Format aset: senarai `[jenis(m/s), nama, alamat, poskod,
daerah, negeri, telefon, lat?, lng?]`.
