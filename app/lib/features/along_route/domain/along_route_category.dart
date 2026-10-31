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

  /// Satu pertanyaan Overpass untuk seluruh laluan: SATU penapis `around` pada polyline (bukan satu
  /// penapis bulat setiap sampel). Pada laluan jauh, versi lama menghasilkan ratusan penyata berasingan
  /// yang mengambil masa puluhan saat pada pelayan awam; polyline dijawab dalam beberapa saat.
  ///
  /// [line] ialah laluan yang dipermudah (lihat `AlongRouteSearch`). Jejari ditambah sedikit
  /// ([lineMarginM]) kerana garis dipermudah memotong selekoh; penapis silang-trek sebenar pada laluan
  /// penuh dibuat selepas itu. Koordinat dibulatkan kepada ~1 m untuk memendekkan permintaan.
  String overpassQuery(
    Iterable<(double lat, double lng)> line, {
    double lineMarginM = 120,
  }) {
    final pts = line
        .map((p) => '${p.$1.toStringAsFixed(5)},${p.$2.toStringAsFixed(5)}')
        .join(',');
    final around = '(around:${(corridorM + lineMarginM).round()},$pts)';
    final parts = selectors.map((s) => 'nw$s$around;').join();
    // `qt`: tanpa isihan di pelayan (lebih pantas); kita isih ikut jarak sepanjang laluan sendiri.
    return '[out:json][timeout:20];($parts);out tags center qt;';
  }
}
