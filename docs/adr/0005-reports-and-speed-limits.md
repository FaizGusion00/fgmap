# ADR 0005: Laporan komuniti (tempatan), had laju dan pilihan kenderaan

- Status: diterima (data/logik siap; sambungan UI pada skrin peta/navigasi dipegang oleh sesi navigasi)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 9, 16.1, 16.3, 17.2

## Konteks

Pemilik mahu ciri seperti Waze dan Google Maps, tetapi memilih "tiada backend". Kedua-duanya bercanggah untuk
laporan komuniti dan trafik langsung, kerana kedua-duanya memerlukan tempat simpan yang dikongsi antara pengguna.

## Keputusan

1. **Laporan: simpanan tempatan sahaja** (`LocalReportsRepository`, fail JSON atomik pada peranti). Hanya pelapor
   melihat laporannya, jadi ia belum "komuniti". `ReportsRepository` ialah antara muka; peraturan (hayat per jenis,
   pengesahan melanjutkan hayat sehingga 3x, ambang penafian, gabungan pendua dalam 150 m) berada dalam
   `ReportRules`/repositori supaya backend kongsi (Firebase/Supabase) boleh menggantikannya tanpa mengubah UI.
   Laporan sentiasa dari GPS semasa (tiada lokasi yang ditaip) dan jenis tetap sahaja (tiada teks bebas).
2. **Trafik langsung: tidak dibuat.** Memerlukan probe daripada ramai pengguna dan backend. Tiada sumber trafik langsung
   percuma tanpa kunci yang dapat disahkan.
3. **Had laju:** `trace_attributes` Valhalla pada laluan terpilih (server awam, atau enjin offline melalui plugin),
   dipadankan mengikut indeks titik atau jarak sepanjang laluan. Data OSM tidak lengkap (diukur KLCC→KLIA: 134 daripada
   205 segmen mempunyai had), jadi UI mesti menunjukkan had hanya bila ada dan tidak pernah memberi amaran tanpa data.
4. **Kenderaan:** kereta atau motosikal (`RouteVehicle`), disimpan; costing Valhalla `auto`/`motorcycle` disahkan pada
   server sebenar. Pilihan elak tol/lebuh raya kini dinyatakan sebagai laluan berlabel oleh sesi UI (`RouteLabel`).

## Tidak dibuat dan sebabnya

- **Carian kategori berdekatan (petrol, makan, surau):** Photon berasaskan nama dan tidak sesuai; Overpass ialah
  kaedah piawai tetapi semua cermin awam tamat masa dari mesin pembangunan, jadi ia tidak dapat disahkan.
- **Amaran kamera kelajuan:** perlu semakan undang-undang dan polisi store (Bahagian 16.3).

## Akibat

- Laporan tidak membantu pemandu lain sehingga backend kongsi dipilih. Memilih satu memerlukan akaun projek oleh pemilik.
- `traceAttributes` pada enjin offline Android dikompil tetapi belum dijalankan pada emulator; iOS belum dibina.
