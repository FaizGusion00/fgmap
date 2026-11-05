import 'dart:convert';

/// Sumber dan lapisan imej satelit dalam gaya hibrid.
const satelliteSourceId = 'fg-satellite-src';
const satelliteLayerId = 'fg-satellite';

/// Lapisan imej asli tahap 19 (~0.3 m/piksel) di atas lapisan asas. Tersembunyi lalai: ia hanya
/// dinyalakan oleh peta apabila ketersediaan z19 di kawasan itu telah disahkan (lihat
/// `SatelliteCoverage`), kerana di tempat tiada imej Esri menghantar jubin "Map data not yet
/// available" yang lebih buruk daripada membesarkan jubin z18.
const satelliteHiSourceId = 'fg-satellite-hi-src';
const satelliteHiLayerId = 'fg-satellite-hi';

/// Awalan kunci gaya satelit (lihat `MapStyleLoader.satellite`), supaya peta tahu gaya mana yang
/// menggunakan lapisan z19.
const satelliteStyleKeyPrefix = 'satellite:';

/// Atribusi wajib Esri World Imagery ("Powered by Esri" + sumber data), dipaparkan oleh butang
/// atribusi peta.
const satelliteAttribution =
    'Powered by <a href="https://www.esri.com">Esri</a> | Esri, Maxar, Earthstar '
    'Geographics, and the GIS User Community';

/// Gaya hibrid (seperti "Satelit" Google): imej satelit di bawah, kemudian jalan separa lut sinar,
/// sempadan dan label putih berhalo gelap daripada gaya vektor OpenMapTiles yang sama. Lapisan
/// laluan, anak panah dan kenderaan FGMaps ditambah kemudian oleh peta seperti biasa.
///
/// Fungsi tulen: JSON masuk, JSON keluar; null jika gaya tidak dikenali (pemanggil kekal pada peta
/// biasa).
abstract final class SatelliteStyle {
  /// Kelegapan jalan di atas imej: cukup untuk diikut tanpa menutup gambar.
  static const roadOpacity = 0.55;
  static const labelColor = '#FFFFFF';
  static const haloColor = 'rgba(0,0,0,0.78)';

  /// Imej asli Esri hampir di mana-mana di Malaysia sehingga zum 18; di atas itu MapLibre
  /// membesarkan jubin terakhir (lebih baik daripada jubin "Map data not yet available").
  static const maxZoom = 18;

  /// Di bandar dan pinggir bandar Esri ada imej asli zum 19 (dua kali lebih terperinci). Lihat
  /// [satelliteHiLayerId].
  static const hiMaxZoom = 19;

  /// Saiz jubin yang diisytiharkan bagi sumber z19 (lihat komen dalam [apply]).
  static const hiTileSize = 128;

  /// Penambahbaikan kejelasan imej Esri yang agak berkabus: sedikit kontras dan ketepuan. Nilai
  /// kecil sengaja; terlalu banyak memecahkan warna kawasan hijau dan bumbung.
  static const rasterContrast = 0.14;
  static const rasterSaturation = 0.1;

  static String? apply(String source, {required String tilesUrl}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final layers = decoded['layers'];
    final sources = decoded['sources'];
    if (layers is! List || layers.isEmpty || sources is! Map) return null;

    final kept = <Object?>[];
    // Air, litupan tanah dan guna tanah disimpan DI BAWAH imej: tanpa internet (jubin satelit tidak
    // dimuat) peta masih menunjukkan air dan kawasan, bukan latar gelap kosong.
    final under = <Object?>[];
    var roads = 0;
    for (final raw in layers) {
      if (raw is! Map<String, dynamic>) continue;
      final type = raw['type'];
      final id = '${raw['id']}';
      final sl = raw['source-layer'];
      switch (type) {
        // Imej satelit menggantikan latar, tanah, air, bangunan dan relief.
        case 'fill'
            when const {'water', 'landcover', 'landuse', 'park'}.contains(sl):
          under.add(raw);
        case 'background' ||
            'fill' ||
            'fill-extrusion' ||
            'raster' ||
            'hillshade':
          continue;
        case 'line':
          // Tepi jalan, terowong, sungai dan landasan terbang menyerabutkan gambar.
          if (sl != 'transportation' && sl != 'boundary') continue;
          if (id.contains('casing') ||
              id.startsWith('tunnel') ||
              id.contains('hatching')) {
            continue;
          }
          final paint =
              (raw['paint'] ??= <String, dynamic>{}) as Map<String, dynamic>;
          if (sl == 'transportation') {
            paint['line-opacity'] = roadOpacity;
            roads++;
          }
          kept.add(raw);
        case 'symbol':
          final paint =
              (raw['paint'] ??= <String, dynamic>{}) as Map<String, dynamic>;
          final layout = raw['layout'];
          final hasText = layout is Map && layout['text-field'] != null;
          // Perisai nombor jalan: teks gelap di atas ikon terang, jangan diputihkan.
          final shield =
              id.contains('shield') ||
              (layout is Map &&
                  layout['icon-image'] != null &&
                  layout['symbol-placement'] == 'line');
          if (hasText && !shield) {
            paint['text-color'] = labelColor;
            paint['text-halo-color'] = haloColor;
            paint['text-halo-width'] = 1.4;
            paint.remove('text-halo-blur');
          }
          kept.add(raw);
        default:
          kept.add(raw);
      }
    }
    // Bukan gaya OpenMapTiles yang dikenali: jangan hantar gaya separuh siap.
    if (roads < 5) return null;

    // Sumber raster yang tidak lagi digunakan (relief Natural Earth) dibuang supaya tidak dimuat.
    final used = {
      for (final l in [...under, ...kept])
        if (l is Map && l['source'] is String) l['source'] as String,
    };
    sources.removeWhere((key, _) => !used.contains(key));
    sources[satelliteSourceId] = {
      'type': 'raster',
      'tiles': [tilesUrl],
      'tileSize': 256,
      'maxzoom': maxZoom,
      'attribution': satelliteAttribution,
    };
    // Sumber z19: jubin yang sama, hanya tahap 19 (tiada jubin lebih rendah diminta). Atribusi
    // sudah ada pada sumber asas. `tileSize: 128` (bukan 256) menjadikan MapLibre meminta tahap
    // 19 mulai zum peta 17 dan bukan 18: pemanduan biasa berlaku pada zum 16.2-18.2, jadi dengan 256
    // lapisan ini hampir tidak pernah kelihatan. Imej z19 dipaparkan 2x lebih padat pada zum 17-18.
    // Sumber asas tidak diubah: ia tidak disemak ketersediaannya dan tidak patut meminta tahap
    // lebih tinggi lebih awal.
    sources[satelliteHiSourceId] = {
      'type': 'raster',
      'tiles': [tilesUrl],
      'tileSize': hiTileSize,
      'minzoom': hiMaxZoom,
      'maxzoom': hiMaxZoom,
    };
    decoded['layers'] = [
      // Warna di bawah imej semasa jubin dimuat (gelap, seperti gambar satelit).
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': '#0B1220'},
      },
      ...under,
      {
        'id': satelliteLayerId,
        'type': 'raster',
        'source': satelliteSourceId,
        'paint': {
          'raster-fade-duration': 150,
          'raster-contrast': rasterContrast,
          'raster-saturation': rasterSaturation,
        },
      },
      {
        'id': satelliteHiLayerId,
        'type': 'raster',
        'source': satelliteHiSourceId,
        'layout': {'visibility': 'none'},
        'paint': {
          'raster-fade-duration': 150,
          'raster-contrast': rasterContrast,
          'raster-saturation': rasterSaturation,
        },
      },
      ...kept,
    ];
    return jsonEncode(decoded);
  }
}
