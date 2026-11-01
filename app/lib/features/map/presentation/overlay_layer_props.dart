import 'package:maplibre_gl/maplibre_gl.dart';

import '../domain/poi_category.dart';

/// Sifat lapisan overlay navigasi (anak panah arah, pin tempat, label belokan). Fungsi tulen supaya
/// ungkapan gaya boleh disahkan terhadap spesifikasi gaya MapLibre tanpa peranti.

/// Id sumber vektor OpenMapTiles dalam gaya Liberty/malam dan gaya pek luar talian.
const vectorSourceId = 'openmaptiles';

/// Lapisan `poi` jubin vektor.
const poiSourceLayer = 'poi';

/// Zum terendah pin tempat dipaparkan (sama dengan POI gaya asal yang paling awal, 15).
const poiPinMinZoom = 15.2;

SymbolLayerProperties chevronLayerProps({
  required String image,
  required double iconScale,
  required bool stale,
}) => SymbolLayerProperties(
  iconImage: image,
  iconSize: 0.34 * iconScale,
  iconAllowOverlap: true,
  iconIgnorePlacement: true,
  iconRotationAlignment: 'map',
  iconPitchAlignment: 'map',
  iconRotate: ['get', 'bearing'],
  iconOpacity: stale ? 0.0 : 0.95,
);

/// Penapis lapisan pin: bernama dan salah satu kelas yang dilukis sebagai pin.
List<Object> poiPinFilter() => [
  'all',
  ['has', 'name'],
  [
    'match',
    ['get', 'class'],
    [for (final e in poiClassesByCategory.entries) ...e.value],
    true,
    false,
  ],
];

SymbolLayerProperties poiPinLayerProps({
  required bool dark,
  required double iconScale,
}) => SymbolLayerProperties(
  iconImage: [
    'match',
    ['get', 'class'],
    for (final e in poiClassesByCategory.entries) ...[
      e.value,
      poiImageName(e.key),
    ],
    // Penapis memastikan hanya kelas di atas sampai ke sini; nilai lalai sekadar diperlukan oleh
    // sintaks `match`.
    poiImageName(PoiCategory.shop),
  ],
  iconAnchor: 'bottom',
  iconSize: 0.4 * iconScale,
  iconAllowOverlap: false,
  symbolSortKey: ['get', 'rank'],
  textField: [
    'coalesce',
    ['get', 'name_en'],
    ['get', 'name'],
  ],
  textFont: const ['Noto Sans Bold'],
  textSize: 13,
  textAnchor: 'left',
  textOffset: const [1.15, -1.9],
  textMaxWidth: 8,
  textOptional: true,
  textColor: dark ? '#FFFFFF' : '#1B2330',
  textHaloColor: dark ? '#0B1220' : '#FFFFFF',
  textHaloWidth: 1.8,
  visibility: 'none',
);

/// Nama jalan pada titik belok: teks putih tebal dengan halo warna laluan ([routeHex]) supaya
/// kelihatan sebagai label berwarna laluan yang bersambung dengan garisan.
SymbolLayerProperties turnLabelLayerProps({required String routeHex}) =>
    SymbolLayerProperties(
      textField: ['get', 'text'],
      textFont: const ['Noto Sans Bold'],
      textSize: 14,
      textAnchor: 'bottom',
      textOffset: const [0, -0.9],
      textMaxWidth: 16,
      textColor: '#FFFFFF',
      textHaloColor: routeHex,
      textHaloWidth: 4.2,
      textAllowOverlap: true,
      textIgnorePlacement: true,
    );
