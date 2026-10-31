import 'dart:convert';

/// Warna gaya peta malam (kontras tinggi, kurang silau). Terdedah supaya diuji nisbah kontras.
abstract final class NightPalette {
  // Biru laut tua (gaya Waze), bukan hitam: lebih tenang pada waktu malam dan jalan terang menonjol.
  static const background = 0xFF13213A;
  static const water = 0xFF0A3961;
  static const waterway = 0xFF134C7A;
  static const green = 0xFF173A42;
  static const wood = 0xFF15343B;
  static const residential = 0xFF172843;
  static const commercial = 0xFF1A2D4A;
  static const institution = 0xFF1C3050;
  static const landDefault = 0xFF15253F;
  static const building = 0xFF233857;
  static const buildingOutline = 0xFF344E78;
  static const boundary = 0xFF5A7398;

  static const roadCasing = 0xFF0C172B;
  static const motorway = 0xFFF6B445;
  static const trunk = 0xFFECC46E;
  static const primary = 0xFFE4EDFA;
  static const secondary = 0xFFC3D3EB;
  static const tertiary = 0xFFA4B9D8;
  static const minor = 0xFF8CA2C4;
  static const service = 0xFF7790B4;
  static const path = 0xFF7088A8;
  static const rail = 0xFF6A82A5;

  static const placeLabel = 0xFFF6F9FF;
  static const label = 0xFFEAF1FB;
  static const roadLabel = 0xFFD2DFF2;
  static const waterLabel = 0xFF8FC2F2;
  static const poiLabel = 0xFFB6C8E2;
  static const halo = 0xFF0C172B;
}

/// Mewarnakan semula gaya peta vektor OpenMapTiles (OpenFreeMap) menjadi gaya malam.
///
/// Sengaja menulis ganti warna mengikut `source-layer` dan kelas jalan, bukan mengubah lapisan satu
/// demi satu pada masa jalan: `setLayerProperties` plugin menetapkan sifat yang tidak dinyatakan kepada
/// null, jadi mengubah warna lapisan hidup boleh merosakkan lebar atau sifat lain. Fungsi tulen:
/// JSON masuk, JSON keluar; pulangkan null jika gaya tidak dikenali supaya pemanggil jatuh ke URL asal.
abstract final class NightStyle {
  /// Penambah saiz/lebar yang menjadikan jalan dan label lebih mudah dibaca ketika memandu.
  static const roadWidthScale = 1.2;
  static const textSizeScale = 1.1;

  static String? apply(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final layers = decoded['layers'];
    if (layers is! List || layers.isEmpty) return null;

    // Gaya mesti boleh dimuat tanpa URL asal: sprite/glyph/sumber mestilah URL mutlak.
    final glyphs = decoded['glyphs'];
    if (glyphs is String && !glyphs.startsWith('http')) return null;
    final sprite = decoded['sprite'];
    if (sprite is String && !sprite.startsWith('http')) return null;
    final sources = decoded['sources'];
    if (sources is Map) {
      for (final s in sources.values) {
        if (s is Map &&
            s['url'] is String &&
            !(s['url'] as String).startsWith('http')) {
          return null;
        }
      }
    }

    var recognised = 0;
    for (final raw in layers) {
      if (raw is! Map<String, dynamic>) continue;
      if (_restyle(raw)) recognised++;
    }
    // Tiada lapisan OpenMapTiles dikenali: jangan hantar gaya separuh siap.
    if (recognised < 5) return null;
    return jsonEncode(decoded);
  }

  /// Mengembalikan benar jika lapisan ini dikenali dan diwarnakan semula.
  static bool _restyle(Map<String, dynamic> layer) {
    final type = layer['type'];
    final sl = layer['source-layer'];
    final id = '${layer['id']}'.toLowerCase();
    final paint =
        (layer['paint'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    final layout =
        (layer['layout'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    final hint = '$id ${jsonEncode(layer['filter'] ?? '')}'.toLowerCase();

    switch (type) {
      case 'background':
        paint['background-color'] = _hex(NightPalette.background);
        paint.remove('background-pattern');
        return true;
      case 'fill':
        return _fill(paint, sl, hint);
      case 'fill-extrusion':
        paint['fill-extrusion-color'] = _hex(NightPalette.building);
        return sl == 'building';
      case 'line':
        return _line(layer, paint, sl, hint);
      case 'symbol':
        return _symbol(paint, layout, sl, hint);
    }
    return false;
  }

  static bool _fill(Map<String, dynamic> paint, Object? sl, String hint) {
    paint.remove('fill-pattern');
    switch (sl) {
      case 'water':
        paint['fill-color'] = _hex(NightPalette.water);
        return true;
      case 'building':
        paint['fill-color'] = _hex(NightPalette.building);
        paint['fill-outline-color'] = _hex(NightPalette.buildingOutline);
        return true;
      case 'landcover' || 'landuse' || 'park':
        paint['fill-color'] = _hex(_landColor(hint));
        return true;
      case 'aeroway':
        paint['fill-color'] = _hex(NightPalette.commercial);
        return true;
      case 'transportation':
        paint['fill-color'] = _hex(NightPalette.service);
        return true;
    }
    return false;
  }

  static int _landColor(String hint) {
    if (RegExp(r'wood|forest').hasMatch(hint)) return NightPalette.wood;
    if (RegExp(
      r'grass|park|garden|pitch|golf|farm|scrub|orchard|vineyard|meadow|nature|recreation|cemetery',
    ).hasMatch(hint)) {
      return NightPalette.green;
    }
    if (RegExp(
      r'residential|suburb|neighbourhood|neighborhood',
    ).hasMatch(hint)) {
      return NightPalette.residential;
    }
    if (RegExp(r'commercial|industrial|retail').hasMatch(hint)) {
      return NightPalette.commercial;
    }
    if (RegExp(
      r'hospital|school|university|college|kindergarten',
    ).hasMatch(hint)) {
      return NightPalette.institution;
    }
    return NightPalette.landDefault;
  }

  static bool _line(
    Map<String, dynamic> layer,
    Map<String, dynamic> paint,
    Object? sl,
    String hint,
  ) {
    switch (sl) {
      case 'water' || 'waterway':
        paint['line-color'] = _hex(NightPalette.waterway);
        return true;
      case 'boundary':
        paint['line-color'] = _hex(NightPalette.boundary);
        return true;
      case 'aeroway':
        paint['line-color'] = _hex(NightPalette.buildingOutline);
        return true;
      case 'transportation':
        final casing = hint.contains('casing');
        paint['line-color'] = _hex(
          casing ? NightPalette.roadCasing : _roadColor(hint),
        );
        // Jalan sedikit lebih tebal (lebih mudah dilihat dalam gelap); casing diskala sama supaya
        // tepi gelapnya kekal.
        for (final key in const ['line-width', 'line-gap-width']) {
          if (paint.containsKey(key)) {
            paint[key] = scaleNumeric(paint[key], roadWidthScale);
          }
        }
        return true;
      case 'building':
        paint['line-color'] = _hex(NightPalette.buildingOutline);
        return true;
    }
    return false;
  }

  /// Kelas jalan daripada id lapisan dan penapis; susunan menentukan keutamaan.
  static int _roadColor(String hint) {
    if (hint.contains('motorway')) return NightPalette.motorway;
    if (hint.contains('trunk')) return NightPalette.trunk;
    if (hint.contains('primary')) return NightPalette.primary;
    if (hint.contains('secondary')) return NightPalette.secondary;
    if (hint.contains('tertiary')) return NightPalette.tertiary;
    if (RegExp(r'rail|transit|ferry|subway').hasMatch(hint)) {
      return NightPalette.rail;
    }
    if (RegExp(
      r'track|path|pedestrian|footway|cycleway|steps|bridleway',
    ).hasMatch(hint)) {
      return NightPalette.path;
    }
    // Lapisan gabungan (minor + service) dianggap jalan kecil biasa; hanya service tulen yang malap.
    if (RegExp(
      r'minor|residential|street|unclassified|living',
    ).hasMatch(hint)) {
      return NightPalette.minor;
    }
    if (hint.contains('service')) return NightPalette.service;
    return NightPalette.minor;
  }

  static bool _symbol(
    Map<String, dynamic> paint,
    Map<String, dynamic> layout,
    Object? sl,
    String hint,
  ) {
    if (!layout.containsKey('text-field')) return false;
    final int color = switch (sl) {
      'water_name' || 'waterway' => NightPalette.waterLabel,
      'transportation_name' => NightPalette.roadLabel,
      'place' => NightPalette.placeLabel,
      'poi' ||
      'aerodrome_label' ||
      'mountain_peak' ||
      'housenumber' => NightPalette.poiLabel,
      _ => NightPalette.label,
    };
    paint['text-color'] = _hex(color);
    paint['text-halo-color'] = _hex(NightPalette.halo);
    paint['text-halo-width'] = 1.6;
    paint['text-halo-blur'] = 0.4;
    if (layout.containsKey('text-size')) {
      layout['text-size'] = scaleNumeric(layout['text-size'], textSizeScale);
    }
    return true;
  }

  /// Menskala nilai berangka: nombor, `{stops: [[z, v], ...]}` (fungsi lama), dan ungkapan
  /// `interpolate`/`step`. Ungkapan lain dipulangkan tanpa diubah.
  static Object? scaleNumeric(Object? value, double k) {
    if (value is num) return value * k;
    if (value is Map<String, dynamic> && value['stops'] is List) {
      return {
        ...value,
        'stops': [
          for (final stop in value['stops'] as List)
            if (stop is List && stop.length == 2)
              [stop[0], scaleNumeric(stop[1], k)]
            else
              stop,
        ],
      };
    }
    if (value is List && value.isNotEmpty) {
      final head = value.first;
      if (head == 'interpolate' && value.length >= 5) {
        // ['interpolate', kaedah, input, z1, o1, z2, o2, ...]: output pada indeks 4, 6, ...
        return [
          for (var i = 0; i < value.length; i++)
            if (i >= 4 && i.isEven) scaleNumeric(value[i], k) else value[i],
        ];
      }
      if (head == 'step' && value.length >= 3) {
        // ['step', input, o0, z1, o1, ...]: output pada indeks 2, 4, ...
        return [
          for (var i = 0; i < value.length; i++)
            if (i >= 2 && i.isEven) scaleNumeric(value[i], k) else value[i],
        ];
      }
    }
    return value;
  }

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
