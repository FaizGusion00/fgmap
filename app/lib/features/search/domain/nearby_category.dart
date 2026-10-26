import 'dart:math' as math;

/// Kategori "Cari berhampiran" pada perancang perjalanan.
///
/// Setiap kategori ialah tag OSM, bukan perkataan untuk dicari mengikut nama: carian nama "Fuel"
/// tidak menjumpai "Petronas", tetapi `amenity=fuel` menjumpai semuanya.
enum NearbyCategory {
  fuel(
    selectors: ['["amenity"="fuel"]'],
    radiusM: 3000,
    nominatimPhrase: 'petrol station',
  ),
  food(
    selectors: ['["amenity"~"^(restaurant|fast_food|cafe|food_court)\$"]'],
    radiusM: 1500,
    nominatimPhrase: 'restaurant',
  ),
  mosque(
    selectors: [
      '["amenity"="place_of_worship"]["religion"="muslim"]',
      '["building"="mosque"]',
    ],
    radiusM: 3000,
    nominatimPhrase: 'mosque',
  ),
  toilets(
    selectors: ['["amenity"="toilets"]'],
    radiusM: 3000,
    nominatimPhrase: 'toilets',
  ),
  parking(
    selectors: ['["amenity"="parking"]["access"!~"^(private|no|customers)\$"]'],
    radiusM: 1000,
    nominatimPhrase: 'parking',
  ),
  hospital(
    selectors: ['["amenity"="hospital"]'],
    radiusM: 8000,
    nominatimPhrase: 'hospital',
  );

  const NearbyCategory({
    required this.selectors,
    required this.radiusM,
    required this.nominatimPhrase,
  });

  /// Penapis tag Overpass; hasil ialah gabungan semuanya.
  final List<String> selectors;

  /// Radius carian pertama (meter). Jika terlalu sedikit hasil, diperluas ([widenedRadiusM]).
  final int radiusM;

  /// Frasa khas Nominatim untuk fallback.
  final String nominatimPhrase;

  int get widenedRadiusM => math.min(radiusM * 3, 15000);

  /// Pertanyaan Overpass QL. `out tags center` memberi satu koordinat bagi bangunan dan kawasan.
  String overpassQuery(double lat, double lng, int radius) {
    final around = '(around:$radius,$lat,$lng)';
    return '[out:json][timeout:10];('
        '${selectors.map((s) => 'nwr$s$around;').join()}'
        ');out tags center 400;';
  }
}
