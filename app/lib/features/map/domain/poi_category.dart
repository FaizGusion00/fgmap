/// Kategori tempat (POI) yang dilukis sebagai pin berwarna semasa navigasi. Pemandu mengenali tempat
/// ikut jenama dan jenis (stesen minyak, makan, kedai), jadi pin membawa warna dan ikon jenis itu
/// bersama nama; tempat jenis lain kekal tidak dipaparkan (gaya peta asal disembunyikan semasa
/// navigasi supaya tidak bertindih, dan jenis yang tiada dalam senarai ini tidak dipaparkan).
enum PoiCategory {
  fuel,
  food,
  shop,
  school,
  health,
  bank,
  worship,
  lodging,
  parking,
}

/// Kelas OpenMapTiles (`poi.class`) bagi setiap kategori.
const poiClassesByCategory = <PoiCategory, List<String>>{
  PoiCategory.fuel: ['fuel', 'charging_station'],
  PoiCategory.food: [
    'restaurant',
    'fast_food',
    'cafe',
    'bar',
    'ice_cream',
    'bakery',
    'food_court',
  ],
  PoiCategory.shop: [
    'shop',
    'grocery',
    'clothing_store',
    'convenience',
    'supermarket',
    'department_store',
    'mall',
    'bicycle',
    'butcher',
    'florist',
    'furniture',
    'jewelry',
    'books',
    'hairdresser',
    'beauty',
    'electronics',
    'mobile_phone',
    'laundry',
    'alcohol_shop',
  ],
  PoiCategory.school: ['school', 'college', 'kindergarten', 'library'],
  PoiCategory.health: [
    'hospital',
    'doctors',
    'pharmacy',
    'dentist',
    'clinic',
    'veterinary',
  ],
  PoiCategory.bank: ['bank', 'atm'],
  PoiCategory.worship: ['place_of_worship'],
  PoiCategory.lodging: ['lodging'],
  PoiCategory.parking: ['parking'],
};

/// Kategori bagi kelas OpenMapTiles [poiClass], atau null jika tidak dilukis sebagai pin.
PoiCategory? poiCategoryOf(String? poiClass) {
  if (poiClass == null) return null;
  for (final e in poiClassesByCategory.entries) {
    if (e.value.contains(poiClass)) return e.key;
  }
  return null;
}

/// Nama imej pin dalam gaya peta.
String poiImageName(PoiCategory c) => 'fg-poi-${c.name}';
