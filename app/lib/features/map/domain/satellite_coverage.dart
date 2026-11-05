import 'dart:convert';
import 'dart:math' as math;

import '../../../core/utils/geo.dart';

/// Ketersediaan imej satelit tahap 19 (z19) di sekitar satu titik.
///
/// Esri World Imagery hanya ada imej asli z19 (~0.3 m/piksel) di bandar dan pinggir bandar; di tempat
/// lain tahap itu mengembalikan jubin "Map data not yet available" yang kelabu. Perkhidmatan Esri
/// menyediakan `tilemap`: satu permintaan JSON kecil yang memberitahu jubin mana wujud pada tahap
/// tertentu. Ini logik tulennya (matematik jubin, URL, penghuraian dan keputusan).
abstract final class SatelliteCoverage {
  /// Tahap yang diperiksa.
  static const hiZoom = 19;

  /// Bilangan jubin sisi blok yang diperiksa. 8 jubin z19 ~ 600 m di khatulistiwa: lebih luas
  /// daripada skrin navigasi (kira-kira 120 m lebar, beberapa ratus meter ke hadapan pada condong).
  static const block = 8;

  /// Pecahan jubin yang mesti ada untuk menyalakan z19. Sedikit ruang kosong (sempadan imbasan
  /// satelit) dibenarkan; lebih daripada itu bermakna tepi liputan dan kekal pada z18.
  static const minFraction = 0.9;

  /// Jubin (lajur x, baris y) yang mengandungi [p] pada tahap [z] (skema web-mercator XYZ).
  static ({int x, int y}) tileOf(GeoPoint p, int z) {
    final n = math.pow(2, z).toDouble();
    final lat = p.lat.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final x = ((p.lng + 180) / 360 * n).floor();
    final y = ((1 - _asinh(math.tan(lat)) / math.pi) / 2 * n).floor();
    return (x: x.clamp(0, n.toInt() - 1), y: y.clamp(0, n.toInt() - 1));
  }

  static double _asinh(double v) => math.log(v + math.sqrt(v * v + 1));

  /// Kunci cache: sel 4x4 jubin z19 (~300 m). Titik berdekatan berkongsi satu keputusan.
  static String cellKey(GeoPoint p) {
    final t = tileOf(p, hiZoom);
    return '${t.x >> 2}:${t.y >> 2}';
  }

  /// URL `tilemap` bagi blok [block]x[block] jubin berpusat pada [p], diterbitkan daripada URL jubin
  /// Esri (`.../MapServer/tile/{z}/{y}/{x}`). Null jika [tilesUrl] bukan bentuk itu (penyedia lain,
  /// cth. URL berkunci): tanpa jaminan ketersediaan z19 kita kekal pada z18.
  static Uri? tilemapUri(String tilesUrl, GeoPoint p) {
    const marker = '/tile/{z}/{y}/{x}';
    final at = tilesUrl.indexOf(marker);
    if (at < 0) return null;
    final base = tilesUrl.substring(0, at);
    final query = tilesUrl.substring(at + marker.length);
    if (query.isNotEmpty && !query.startsWith('?')) return null;
    final t = tileOf(p, hiZoom);
    final left = math.max(0, t.x - block ~/ 2);
    final top = math.max(0, t.y - block ~/ 2);
    final uri = Uri.tryParse('$base/tilemap/$hiZoom/$top/$left/$block/$block');
    if (uri == null || !uri.hasScheme) return null;
    // `f=json` mesti disertakan; kunci/token dalam [query] dikekalkan.
    final params = <String, String>{
      ...Uri.splitQueryString(query.startsWith('?') ? query.substring(1) : ''),
      'f': 'json',
    };
    return uri.replace(queryParameters: params);
  }

  /// Pecahan jubin yang ada (0..1) daripada jawapan `tilemap`; null jika jawapan tidak sah.
  static double? availableFraction(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['valid'] == false) return null;
    final data = json['data'];
    if (data is! List || data.isEmpty) return null;
    var ok = 0;
    for (final v in data) {
      if (v is! num) return null;
      if (v != 0) ok++;
    }
    return ok / data.length;
  }

  /// Boleh z19 digunakan di kawasan dengan [fraction] jubin yang ada?
  static bool hiAvailable(double? fraction) =>
      fraction != null && fraction >= minFraction;
}
