import 'dart:convert';
import 'dart:typed_data';

/// Menukar gaya Liberty (skema OpenMapTiles, dibundel dalam `assets/map/liberty.json`) menjadi gaya yang
/// membaca SEMUANYA daripada fail pada peranti: tile (PMTiles), fon (glyph) dan sprite. Tiada permintaan
/// rangkaian untuk paparan peta. Fungsi tulen: teks masuk, teks keluar.
abstract final class LocalBasemapStyle {
  /// Sumber vektor dalam gaya Liberty yang diganti dengan fail PMTiles.
  static const vectorSourceId = 'openmaptiles';

  /// Julat glyph (setiap susun fon) yang dibundel dalam app: Latin, Latin Extended dan tanda baca am.
  /// Julat lain (CJK, Tamil, Arab) dijana kosong ([emptyGlyphRange]); lihat ADR 0016.
  static const bundledGlyphRanges = ['0-255', '256-511', '8192-8447'];

  /// Susun fon yang digunakan gaya Liberty. Nama folder fon dalam aset menggantikan ruang dengan `_`.
  static const fontStacks = [
    'Noto Sans Regular',
    'Noto Sans Bold',
    'Noto Sans Italic',
  ];

  /// Gaya tempatan, atau null jika [template] bukan gaya OpenMapTiles yang dikenali.
  ///
  /// [pmtilesPath] dan [assetsDir] ialah laluan mutlak pada peranti. Dikodkan sebagai URL `file://`
  /// (ruang dalam "Application Support" iOS menjadi `%20`; MapLibre menyahkodnya semula).
  static String? build(
    String template, {
    required String pmtilesPath,
    required String assetsDir,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(template);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final layers = decoded['layers'];
    final sources = decoded['sources'];
    if (layers is! List || sources is! Map || sources[vectorSourceId] is! Map) {
      return null;
    }

    // Hanya sumber vektor OpenMapTiles kekal; sumber lain (raster Natural Earth) berada di pelayan
    // jauh dan akan gagal tanpa internet. Lapisan yang menggunakannya dibuang bersama.
    decoded['sources'] = {
      vectorSourceId: {
        'type': 'vector',
        'url': 'pmtiles://${Uri.file(pmtilesPath)}',
        'attribution': '© OpenStreetMap contributors · © OpenMapTiles',
      },
    };
    decoded['layers'] = [
      for (final l in layers)
        if (l is Map && (l['source'] == null || l['source'] == vectorSourceId))
          l,
    ];

    final root = Uri.file(assetsDir).toString();
    decoded['glyphs'] = '$root/fonts/{fontstack}/{range}.pbf';
    decoded['sprite'] = '$root/sprite/ofm';
    return jsonEncode(decoded);
  }

  /// Julat glyph Unicode seluas 256 titik kod, `0-255`, `256-511`, ... `65280-65535`.
  static Iterable<String> get allGlyphRanges sync* {
    for (var lo = 0; lo < 65536; lo += 256) {
      yield '$lo-${lo + 255}';
    }
  }

  /// Fail glyph PBF sah tanpa glyph untuk [range]. MapLibre menganggap julat yang tiada sebagai ralat
  /// dan meminta semula pada setiap susun atur tile; julat kosong yang sah menamatkan permintaan itu
  /// (aksara dalam julat itu tidak dilukis).
  static Uint8List emptyGlyphRange(String fontStack, String range) {
    final name = utf8.encode(fontStack);
    final r = utf8.encode(range);
    final inner = [0x0a, name.length, ...name, 0x12, r.length, ...r];
    // Panjang < 128 bait: setiap panjang ialah satu bait varint.
    assert(name.length < 128 && inner.length < 128);
    return Uint8List.fromList([0x0a, inner.length, ...inner]);
  }
}
