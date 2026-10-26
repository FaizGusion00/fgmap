/// Kategori "Cari berhampiran" pada perancang perjalanan.
///
/// Setiap kategori ialah tag OSM, bukan perkataan untuk dicari mengikut nama: carian nama "Fuel"
/// tidak menjumpai "Petronas", tetapi `amenity=fuel` menjumpai semuanya.
enum NearbyCategory {
  fuel(
    selectors: ['["amenity"="fuel"]'],
    radiiM: [2500, 6000, 15000],
    enoughResults: 5,
    nominatimPhrase: 'petrol station',
  ),
  food(
    selectors: [
      '["amenity"~"^(restaurant|fast_food|cafe|food_court|canteen|ice_cream)\$"]',
    ],
    radiiM: [800, 2000, 5000],
    enoughResults: 8,
    nominatimPhrase: 'restaurant',
  ),
  mosque(
    selectors: [
      '["amenity"="place_of_worship"]["religion"="muslim"]',
      '["building"="mosque"]',
      '["amenity"="prayer_room"]',
      // Surau/masjid yang tiada tag agama dalam OSM.
      '["amenity"="place_of_worship"]["name"~"surau|masjid|mosque|musolla|musalla",i]',
    ],
    radiiM: [2000, 5000, 15000],
    enoughResults: 5,
    nominatimPhrase: 'mosque',
  ),
  toilets(
    selectors: ['["amenity"="toilets"]'],
    radiiM: [1500, 5000, 15000],
    enoughResults: 5,
    nominatimPhrase: 'toilets',
  ),
  parking(
    selectors: [
      '["amenity"="parking"]["access"!~"^(private|no|customers|permit)\$"]',
    ],
    radiiM: [600, 1500, 4000],
    enoughResults: 8,
    nominatimPhrase: 'parking',
  ),
  hospital(
    selectors: ['["amenity"="hospital"]', '["healthcare"="hospital"]'],
    radiiM: [5000, 15000, 30000],
    enoughResults: 3,
    nominatimPhrase: 'hospital',
  );

  const NearbyCategory({
    required this.selectors,
    required this.radiiM,
    required this.enoughResults,
    required this.nominatimPhrase,
  });

  /// Penapis tag Overpass; hasil ialah gabungan semuanya.
  final List<String> selectors;

  /// Radius carian berperingkat (meter): radius seterusnya hanya dicuba jika hasil kurang daripada
  /// [enoughResults]. Radius kecil dahulu supaya kawasan padat tidak terpotong oleh had hasil Overpass.
  final List<int> radiiM;

  /// Bilangan hasil yang dianggap mencukupi untuk berhenti memperluas radius.
  final int enoughResults;

  /// Frasa khas Nominatim untuk fallback.
  final String nominatimPhrase;

  /// Pertanyaan Overpass QL. `out tags center` memberi satu koordinat bagi bangunan dan kawasan.
  String overpassQuery(double lat, double lng, int radius) {
    final around = '(around:$radius,$lat,$lng)';
    return '[out:json][timeout:10];('
        '${selectors.map((s) => 'nwr$s$around;').join()}'
        ');out tags center 1000;';
  }
}
