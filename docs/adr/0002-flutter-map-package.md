# ADR 0002: Pakej peta Flutter

- Status: diterima (Fasa 0)
- Tarikh: 2026-10-26
- Rujukan pelan: Bahagian 4.1 ("semak pakej paling terkini semasa implementasi")

## Keputusan

Gunakan **`maplibre_gl` 0.27.1** (`github.com/maplibre/flutter-maplibre-gl`).

## Perbandingan (disemak pada pub.dev, 2026-10-26)

| | `maplibre_gl` | `maplibre` (josxha) |
|---|---|---|
| Versi terkini | 0.27.1 (2026-09-10) | 0.3.7 (2026-10-22) |
| Syarat SDK | Flutter >= 3.29, Dart >= 3.7 | **Flutter >= 3.47, Dart ^3.13** |
| Platform | Android, iOS, web | + macOS, Windows, Linux |
| Sumber PMTiles, kawasan offline | disenaraikan dalam penerangan pakej | tidak disemak |

Mesin pembangunan menggunakan Flutter 3.41.7 / Dart 3.11.5, jadi `maplibre` terkini **tidak boleh dipasang**.
Itu penentu utama. `maplibre_gl` juga diselenggara di bawah organisasi MapLibre dan menyokong GeoJSON layer,
yang digunakan untuk melukis laluan, serta kawasan offline yang diperlukan untuk peta offline (Bahagian 17.5).

## Akibat

- Semua kod `maplibre_gl` tertumpu dalam `features/map/presentation/maplibre_view.dart`. Selebihnya app bercakap
  dengan `MapViewConfig` dan `MapCameraController`, jadi menukar pakej (atau menaik taraf Flutter kemudian) hanya
  menyentuh satu fail.
- Penambahan sumber/lapisan dijalankan bersiri dan dibina semula pada setiap `onStyleLoaded`, kerana menukar
  gaya (cerah/gelap) membuang semua lapisan tersuai.
