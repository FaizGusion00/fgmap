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
  // `building=mosque` sengaja tidak dicari: ia biasanya poligon bangunan masjid yang sama (pendua)
  // dan pengiraan pusat poligon memperlahankan pelayan.
  mosque(
    selectors: [
      '["amenity"="place_of_worship"]["religion"="muslim"]',
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

  /// Tag OSM elemen ini menepati kategori? (Padanan sebelah klien untuk pertanyaan gabungan.)
  bool matches(Map<String, dynamic> tags) {
    final amenity = tags['amenity'];
    final highway = tags['highway'];
    final services = highway == 'services' || highway == 'rest_area';
    return switch (this) {
      restArea => services,
      fuel => amenity == 'fuel',
      evCharging => amenity == 'charging_station',
      mosque =>
        (amenity == 'place_of_worship' && tags['religion'] == 'muslim') ||
            amenity == 'prayer_room',
      toilets => amenity == 'toilets' || (services && tags['toilets'] == 'yes'),
    };
  }

  /// Koridor terlebar antara semua kategori (pertanyaan gabungan menapis lebih ketat selepas itu).
  static double get maxCorridorM =>
      values.map((c) => c.corridorM).reduce((a, b) => a > b ? a : b);

  /// SATU pertanyaan untuk SEMUA kategori, dalam kotak sempadan kecil sepanjang laluan ([boxes]:
  /// selatan, barat, utara, timur). Penapis kotak menggunakan indeks ruang pelayan dan jauh lebih
  /// pantas daripada `around` pada polyline ratusan titik (diukur 2026-11-01, KL→Ipoh 203 km pada
  /// overpass.openstreetmap.fr: kotak 5.8 s, polyline 9.5 s; lima permintaan lama 35-46 s setiap satu
  /// pada pelayan yang sibuk). Kategori diasingkan pada telefon ([matches]) dan setiap satu ditapis
  /// mengikut koridornya sendiri.
  static String combinedOverpassQuery(
    Iterable<(double s, double w, double n, double e)> boxes,
  ) {
    String f(double v) => v.toStringAsFixed(4);
    final b = StringBuffer('[out:json][timeout:25];(');
    for (final (s, w, n, e) in boxes) {
      final box = '(${f(s)},${f(w)},${f(n)},${f(e)})';
      b
        ..write('nw["highway"~"^(services|rest_area)\$"]$box;')
        ..write(
          'nw["amenity"~"^(fuel|charging_station|toilets|prayer_room)\$"]$box;',
        )
        ..write('nw["amenity"="place_of_worship"]["religion"="muslim"]$box;');
    }
    b.write(');out tags center qt;');
    return b.toString();
  }

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
