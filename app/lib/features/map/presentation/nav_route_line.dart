import 'dart:math' as math;

import '../../../core/utils/geo.dart';

/// Laluan navigasi aktif yang dilukis SEKALI pada peta dan dipangkas di permulaan (bahagian yang sudah
/// dilalui menjadi lutsinar) melalui `line-gradient`, bukannya dijana semula setiap beberapa meter.
///
/// Menjana semula GeoJSON laluan penuh membuat peta memasang jubin semula pada setiap kemas kini; pada
/// zum rendah (seluruh laluan kelihatan) ini menghentikan rendering sehingga beberapa saat, dan garisan
/// mengekor di belakang kereta kerana hanya dikemas kini setiap 15 m.
class NavRouteLine {
  NavRouteLine({
    required this.points,
    required List<double> cumulativeM,
    required this.version,
  }) : assert(points.length == cumulativeM.length),
       _cum = cumulativeM {
    _merc = _mercatorCumulative(points);
  }

  final List<GeoPoint> points;

  /// Bertambah setiap kali laluan diganti (re-route); menandakan geometri perlu dihantar semula.
  final int version;

  /// Jarak kumulatif geodesik (meter) pada setiap titik.
  final List<double> _cum;

  /// Jarak kumulatif dalam ruang Mercator, iaitu ruang yang digunakan peta untuk `line-progress`.
  late final List<double> _merc;

  double get totalM => _cum.isEmpty ? 0 : _cum.last;

  /// Panjang setiap keping laluan (m). `line-gradient` dirender ke tekstur 256 piksel merentas SELURUH
  /// panjang garisan, jadi pada laluan 55 km satu piksel ~215 m dan permulaan garisan boleh tersasar
  /// ratusan meter daripada kereta. Laluan dipecah kepada keping ~1 km (resolusi ~4 m); hanya keping
  /// semasa dipangkas dengan gradient, keping selepasnya dilukis penuh dan keping sebelumnya disembunyikan
  /// melalui penapis lapisan (murah, tanpa menghantar semula geometri).
  static const chunkM = 1000.0;

  /// Bilangan keping.
  int get chunkCount => chunks.length;

  late final List<NavRouteChunk> chunks = _buildChunks();

  /// Indeks keping yang mengandungi [alongM].
  int chunkIndexAt(double alongM) {
    if (chunks.isEmpty) return 0;
    final i = (alongM.clamp(0.0, totalM) / chunkM).floor();
    return i.clamp(0, chunks.length - 1);
  }

  /// Pecahan (0..1) keping semasa yang telah dilalui, dalam ruang `line-progress` keping itu.
  double chunkFractionAt(double alongM) {
    if (chunks.isEmpty) return 0;
    final i = chunkIndexAt(alongM);
    return chunks[i].fractionAt(alongM.clamp(0.0, totalM) - i * chunkM);
  }

  List<NavRouteChunk> _buildChunks() {
    if (points.length < 2 || totalM <= 0) return const [];
    // Sisa < 50 m dicantumkan dengan keping terakhir (tiada keping kerdil).
    final count = math.max(1, (totalM / chunkM - 0.05).ceil());
    return [
      for (var c = 0; c < count; c++)
        _chunk(c * chunkM, c == count - 1 ? totalM : (c + 1) * chunkM),
    ];
  }

  GeoPoint _pointAt(double d) {
    final i = _segmentAt(d);
    final segLen = _cum[i + 1] - _cum[i];
    final t = segLen <= 0 ? 0.0 : ((d - _cum[i]) / segLen).clamp(0.0, 1.0);
    final a = points[i], b = points[i + 1];
    return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
  }

  NavRouteChunk _chunk(double from, double to) {
    final pts = <GeoPoint>[_pointAt(from)];
    final rel = <double>[0];
    for (var i = 0; i < points.length; i++) {
      if (_cum[i] <= from || _cum[i] >= to) continue;
      pts.add(points[i]);
      rel.add(_cum[i] - from);
    }
    pts.add(_pointAt(to));
    rel.add(to - from);
    return NavRouteChunk(points: pts, cumulativeM: rel);
  }

  /// Pecahan (0..1) panjang garisan yang telah dilalui apabila kenderaan berada [alongM] meter dari
  /// permulaan, dalam ruang yang sama dengan `line-progress`. Jarak Mercator tidak berskala seragam
  /// dengan jarak sebenar (berubah mengikut latitud), jadi pecahan geodesik biasa akan tersasar
  /// puluhan meter pada laluan panjang.
  double fractionAt(double alongM) {
    final total = _merc.isEmpty ? 0.0 : _merc.last;
    if (total <= 0 || points.length < 2) return 0;
    final d = alongM.clamp(0.0, totalM);
    final i = _segmentAt(d);
    final segLen = _cum[i + 1] - _cum[i];
    final t = segLen <= 0 ? 0.0 : (d - _cum[i]) / segLen;
    final m = _merc[i] + (_merc[i + 1] - _merc[i]) * t;
    return (m / total).clamp(0.0, 1.0);
  }

  /// Bahagian laluan dari [alongM] hingga akhir (untuk laluan sandaran tanpa `line-gradient`).
  List<GeoPoint> remainingFrom(double alongM) {
    if (points.length < 2) return points;
    final d = alongM.clamp(0.0, totalM);
    final i = _segmentAt(d);
    final segLen = _cum[i + 1] - _cum[i];
    final t = segLen <= 0 ? 0.0 : (d - _cum[i]) / segLen;
    final a = points[i], b = points[i + 1];
    return [
      GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t),
      ...points.sublist(i + 1),
    ];
  }

  int _segmentAt(double d) {
    var lo = 0;
    var hi = points.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cum[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  static List<double> _mercatorCumulative(List<GeoPoint> pts) {
    final out = List<double>.filled(pts.length, 0);
    double? px, py;
    for (var i = 0; i < pts.length; i++) {
      final x = pts[i].lng * math.pi / 180;
      final y = math.log(math.tan(math.pi / 4 + pts[i].lat * math.pi / 360));
      if (px != null && py != null) {
        out[i] =
            out[i - 1] + math.sqrt(math.pow(x - px, 2) + math.pow(y - py, 2));
      }
      px = x;
      py = y;
    }
    return out;
  }
}

/// Satu keping laluan navigasi (~[NavRouteLine.chunkM]) dengan jarak geodesik dan Mercator sendiri.
class NavRouteChunk {
  NavRouteChunk({required this.points, required List<double> cumulativeM})
    : _cum = cumulativeM,
      _merc = NavRouteLine._mercatorCumulative(points);

  final List<GeoPoint> points;

  /// Jarak geodesik (m) dari permulaan keping.
  final List<double> _cum;
  final List<double> _merc;

  /// Pecahan (0..1) keping yang telah dilalui pada [localM] meter dari permulaan keping.
  double fractionAt(double localM) {
    final total = _merc.last;
    if (total <= 0) return 0;
    final d = localM.clamp(0.0, _cum.last);
    var lo = 0, hi = points.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cum[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final segLen = _cum[lo + 1] - _cum[lo];
    final t = segLen <= 0 ? 0.0 : (d - _cum[lo]) / segLen;
    return ((_merc[lo] + (_merc[lo + 1] - _merc[lo]) * t) / total).clamp(
      0.0,
      1.0,
    );
  }
}

/// Ungkapan `line-gradient` yang memangkas garisan sehingga [fraction] (bahagian sebelum itu lutsinar)
/// dan mewarnakan selebihnya dengan [colorHex]. Pecahan dihad supaya hentian sentiasa menaik secara tegas.
List<Object> trimGradient(double fraction, String colorHex) {
  final f = fraction.clamp(0.000001, 0.999999);
  return [
    'step',
    ['line-progress'],
    'rgba(0, 0, 0, 0)',
    f,
    colorHex,
  ];
}

/// Gradient malar warna [colorHex] (laluan tidak dipangkas), sah untuk `line-gradient`.
List<Object> solidGradient(String colorHex) => [
  'interpolate',
  ['linear'],
  ['line-progress'],
  0,
  colorHex,
  1,
  colorHex,
];
