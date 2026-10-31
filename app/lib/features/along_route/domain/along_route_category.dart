/// Kategori POI sepanjang laluan (koridor polyline), bukan carian radius sekitar GPS.
enum AlongRouteCategory {
  // sampleEveryM mesti ≤ ~1.5× corridor supaya POI antara sampel tidak terlepas.
  restArea(
    selectors: ['["highway"="services"]', '["highway"="rest_area"]'],
    corridorM: 800,
    sampleEveryM: 1000,
  ),
  fuel(selectors: ['["amenity"="fuel"]'], corridorM: 500, sampleEveryM: 700),
  evCharging(
    selectors: ['["amenity"="charging_station"]'],
    corridorM: 600,
    sampleEveryM: 800,
  ),
  mosque(
    selectors: [
      '["amenity"="place_of_worship"]["religion"="muslim"]',
      '["building"="mosque"]',
      '["amenity"="prayer_room"]',
    ],
    corridorM: 600,
    sampleEveryM: 800,
  ),
  toilets(
    selectors: [
      '["amenity"="toilets"]',
      '["highway"="services"]["toilets"="yes"]',
      '["highway"="rest_area"]["toilets"="yes"]',
    ],
    corridorM: 500,
    sampleEveryM: 700,
  );

  const AlongRouteCategory({
    required this.selectors,
    required this.corridorM,
    required this.sampleEveryM,
  });

  final List<String> selectors;
  final double corridorM;
  final double sampleEveryM;

  String overpassQuery(Iterable<(double lat, double lng)> samples) {
    final parts = <String>[];
    for (final (lat, lng) in samples) {
      final around = '(around:${corridorM.round()},$lat,$lng)';
      for (final s in selectors) {
        parts.add('nwr$s$around;');
      }
    }
    return '[out:json][timeout:25];(${parts.join()});out tags center;';
  }
}
