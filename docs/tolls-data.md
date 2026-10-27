# Data kadar tol (`app/assets/tolls/my_tolls.json`)

## Keadaan semasa

Fail **sengaja kosong** (`"plazas": []`). Tiada angka harga direka.

Sebabnya (disemak 2026-10): tiada API percuma rasmi untuk kadar tol Malaysia. PLUS dan LLM tidak
menerbitkan data boleh-baca-mesin; jadual dalam laman web ialah HTML/PDF. Tapak pihak ketiga yang
menyenaraikan kadar saling **bercanggah** (cth. Jalan Duta ke Ipoh Kelas 1: RM21.73 pada satu tapak,
RM17.50 pada yang lain), jadi tiada satu pun layak dijadikan sumber kebenaran.

## Apa yang app buat tanpa data harga

- **Jalan bertol sebenar** laluan: daripada bendera `toll` setiap manuver Valhalla (data OSM). Contoh
  KLCC ke KLIA: "Lebuhraya Maju (E20)", "E6".
- **Plaza tol**: dikesan daripada OSM (Overpass, `barrier=toll_booth` / `highway=toll_gantry`) dalam
  kotak sempadan laluan, dipadankan ke garisan laluan (<= 40 m) dan dikelompokkan (<= 150 m).
- **Harga**: "harga tidak diketahui". Kad menunjukkan "N plaza"; tiada "RM 0" dipaparkan.

## Cara mengisi dataset (apabila sumber rasmi disahkan)

Skema versi 1:

```json
{
  "version": 1,
  "currency": "MYR",
  "lastVerified": "2026-10-01",
  "plazas": [
    {
      "id": "nama-unik",
      "name": "Nama plaza",
      "lat": 3.0000,
      "lng": 101.0000,
      "type": "open",
      "ratesRm": { "1": 2.50, "4": 1.00 },
      "source": "https://sumber-rasmi.example/kadar",
      "verifiedOn": "2026-10-01"
    }
  ]
}
```

Peraturan (dikuatkuasakan oleh `TollRates.parse`, entri yang melanggar dilangkau):

1. `source` (URL) dan `verifiedOn` wajib. Entri tanpa jejak tidak dipercayai.
2. Hanya `"type": "open"` (harga tetap setiap plaza). Sistem tertutup (masuk-keluar, cth. lebuh raya
   Utara-Selatan) memerlukan jadual pasangan; belum disokong, kekal "tidak diketahui".
3. Kelas: `"1"` = kereta, `"4"` = motosikal. Kelas tanpa kadar kekal "tidak diketahui"; motosikal
   **tidak** dianggap percuma.
4. Koordinat ialah nod OSM plaza (`lat`/`lng`); dipadankan dalam 250 m.
5. Sahkan angka dengan sumber rasmi (pekeliling LLM / laman pengendali) sebelum menambah, dan catat
   URL tepat. Jangan salin daripada tapak pihak ketiga.

Anggaran dipaparkan sebagai "Tol RM x" hanya jika SEMUA plaza pada laluan ada harga; jika sebahagian,
"RM x+ (sebahagian)"; jika tiada, bilangan plaza sahaja. Sentiasa disertai penafian "anggaran sahaja".

## Had yang diketahui

- Pencarian plaza memerlukan internet (Overpass); luar talian = tiada maklumat plaza (jalan bertol
  Valhalla masih ada).
- Pencarian plaza belum diuji terhadap Overpass sebenar daripada persekitaran pembangunan (rangkaian
  disekat); logiknya diuji dengan fixture sintetik. Sahkan pada peranti.
- Tol tanpa palang (MLFF) mungkin tiada dalam OSM; tidak dikesan.
