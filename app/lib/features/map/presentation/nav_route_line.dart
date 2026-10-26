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
