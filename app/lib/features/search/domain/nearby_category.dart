/// Kategori "Cari berhampiran" pada perancang perjalanan.
///
/// Setiap kategori ialah tag OSM, bukan perkataan untuk dicari mengikut nama: carian nama "Fuel"
/// tidak menjumpai "Petronas", tetapi `amenity=fuel` menjumpai semuanya.
enum NearbyCategory {
  fuel(
    selectors: ['["amenity"="fuel"]'],
    radiiM: [1200, 3500, 10000, 20000],
    enoughResults: 5,
    nominatimPhrases: ['petrol station'],
    nominatimTypes: {'amenity:fuel'},
  ),
  food(
    selectors: [
      '["amenity"~"^(restaurant|fast_food|cafe|food_court|canteen|ice_cream)\$"]',
    ],
    radiiM: [500, 1500, 4000],
    enoughResults: 8,
    nominatimPhrases: ['restaurant'],
    nominatimTypes: {
      'amenity:restaurant',
      'amenity:fast_food',
      'amenity:cafe',
      'amenity:food_court',
      'amenity:canteen',
      'amenity:ice_cream',
    },
  ),
  mosque(
    selectors: [
      '["amenity"="place_of_worship"]["religion"="muslim"]',
      '["building"="mosque"]',
      '["amenity"="prayer_room"]',
    ],
    // Surau/masjid yang tiada tag agama dalam OSM: padanan regex nama mahal pada pelayan, jadi hanya
    // dalam peringkat carian yang lebih luas (bukan hasil pertama yang pantas).
    slowSelectors: [
      '["amenity"="place_of_worship"]["name"~"surau|masjid|mosque|musolla|musalla",i]',
    ],
    radiiM: [1200, 3500, 10000, 20000],
    enoughResults: 5,
    nominatimPhrases: ['mosque', 'surau'],
    nominatimTypes: {
      'amenity:place_of_worship',
      'amenity:prayer_room',
      'building:mosque',
    },
  ),
  toilets(
    selectors: ['["amenity"="toilets"]'],
    radiiM: [1000, 3000, 10000],
    enoughResults: 5,
    nominatimPhrases: ['toilets'],
    nominatimTypes: {'amenity:toilets'},
  ),
  parking(
    selectors: [
      '["amenity"="parking"]["access"!~"^(private|no|customers|permit)\$"]',
    ],
    radiiM: [400, 1200, 3500],
    enoughResults: 8,
    nominatimPhrases: ['parking'],
    nominatimTypes: {'amenity:parking', 'amenity:parking_space'},
  ),
  hospital(
    selectors: ['["amenity"="hospital"]', '["healthcare"="hospital"]'],
    radiiM: [3000, 10000, 30000],
    enoughResults: 3,
    nominatimPhrases: ['hospital'],
    nominatimTypes: {'amenity:hospital', 'healthcare:hospital'},
  );

  const NearbyCategory({
    required this.selectors,
    this.slowSelectors = const [],
    required this.radiiM,
    required this.enoughResults,
    required this.nominatimPhrases,
    required this.nominatimTypes,
  });

  /// Penapis tag Overpass; hasil ialah gabungan semuanya.
  final List<String> selectors;

  /// Penapis yang mahal (regex nama); digugurkan daripada pertanyaan "pantas" peringkat pertama.
  final List<String> slowSelectors;

  /// Radius carian berperingkat (meter): radius seterusnya hanya dicuba jika hasil kurang daripada
  /// [enoughResults]. Radius kecil dahulu supaya kawasan padat tidak terpotong oleh had hasil Overpass.
  final List<int> radiiM;

  /// Bilangan hasil yang dianggap mencukupi untuk berhenti memperluas radius.
  final int enoughResults;

  /// Frasa khas Nominatim (Inggeris, tidak bergantung pada bahasa paparan app) untuk fallback.
  final List<String> nominatimPhrases;

  /// Pasangan `kelas:jenis` OSM yang diterima daripada Nominatim. Frasa bebas juga memadankan nama
  /// jalan (cth. "toilets" -> "Jalan ..."), jadi hasil yang bukan jenis ini dibuang.
  final Set<String> nominatimTypes;

  /// Sama ada hasil Nominatim berjenis [osmKey]:[type] tergolong dalam kategori ini.
  bool acceptsNominatim(String? osmKey, String? type) =>
      nominatimTypes.contains('$osmKey:$type');

  /// Pertanyaan Overpass QL. `out tags center` memberi satu koordinat bagi bangunan dan kawasan.
  ///
  /// [fast]: peringkat pertama (radius kecil): masa tamat 5 s, 60 hasil, tanpa penapis mahal. Peringkat
  /// lebih luas: masa tamat 10 s dan sehingga 1000 hasil.
  String overpassQuery(
    double lat,
    double lng,
    int radius, {
    bool fast = false,
  }) {
    final around = '(around:$radius,$lat,$lng)';
    final all = fast ? selectors : [...selectors, ...slowSelectors];
    return '[out:json][timeout:${fast ? 5 : 10}];('
        '${all.map((s) => 'nwr$s$around;').join()}'
        ');out tags center ${fast ? 60 : 1000};';
  }
}
