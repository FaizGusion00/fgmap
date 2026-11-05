import 'dart:math' as math;

import '../../../core/utils/geo.dart';

/// Laluan navigasi aktif untuk peta: keping ~1 km yang dihantar SEKALI, dan potongan pendek di bawah
/// kereta yang dihantar semula apabila kereta bergerak.
///
/// Menjana semula GeoJSON laluan penuh membuat peta memasang jubin semula pada setiap kemas kini; pada
/// zum rendah (seluruh laluan kelihatan) ini menghentikan rendering sehingga beberapa saat. Jadi hanya
/// potongan dari kereta hingga hujung keping SELEPAS keping semasa ([slice], <= ~2 km) dihantar semula;
/// keping lebih jauh kekal dan dipapar melalui penapis lapisan.
///
/// Dahulu keping semasa dipangkas dengan `line-gradient`. Pada sesetengah GPU/peranti ia tidak dilukis
/// langsung (tiada ralat), jadi garisan biru hilang dari kereta hingga ke keping seterusnya.
class NavRouteLine {
  NavRouteLine({
    required this.points,
    required List<double> cumulativeM,
    required this.version,
  }) : assert(points.length == cumulativeM.length),
       _cum = cumulativeM;

  final List<GeoPoint> points;

  /// Bertambah setiap kali laluan diganti (re-route); menandakan geometri perlu dihantar semula.
  final int version;

  /// Jarak kumulatif geodesik (meter) pada setiap titik.
  final List<double> _cum;

  double get totalM => _cum.isEmpty ? 0 : _cum.last;

  /// Panjang setiap keping laluan (m). Keping yang telah dilalui disembunyikan dan keping selepas
  /// potongan kereta dilukis penuh melalui penapis lapisan (murah, tanpa menghantar semula geometri).
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

  /// Jarak (m) di hujung keping [i]; hujung laluan bagi keping terakhir dan selepasnya.
  double chunkEndM(int i) {
    if (chunks.isEmpty || i >= chunks.length - 1) return totalM;
    return (i + 1) * chunkM;
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

  /// Titik pada laluan yang dilukis pada jarak [d] (m) dari permulaan.
  GeoPoint pointAt(double d) => _pointAt(d.clamp(0.0, totalM));

  GeoPoint _pointAt(double d) {
    final i = _segmentAt(d);
    final segLen = _cum[i + 1] - _cum[i];
    final t = segLen <= 0 ? 0.0 : ((d - _cum[i]) / segLen).clamp(0.0, 1.0);
    final a = points[i], b = points[i + 1];
    return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
  }

  NavRouteChunk _chunk(double from, double to) =>
      NavRouteChunk(points: slice(from, to));

  /// Titik laluan dari [fromM] hingga [toM] (dihad pada laluan): bermula dan berakhir tepat pada
  /// kedudukan itu, dengan semua titik asal di antaranya. Kosong jika julatnya kosong.
  List<GeoPoint> slice(double fromM, double toM) {
    if (points.length < 2) return const [];
    final from = fromM.clamp(0.0, totalM);
    final to = toM.clamp(0.0, totalM);
    if (to - from < 0.01) return const [];
    return [
      _pointAt(from),
      for (var i = 0; i < points.length; i++)
        if (_cum[i] > from && _cum[i] < to) points[i],
      _pointAt(to),
    ];
  }

  /// Arah (darjah, 0 = utara) laluan yang dilukis pada jarak [d], diukur merentasi [spanM] supaya
  /// tidak melompat pada titik selekoh yang rapat.
  double bearingAt(double d, {double spanM = 8}) {
    final a = pointAt(d - spanM);
    final b = pointAt(d + spanM);
    return bearingDegrees(a, b);
  }

  /// Anak panah arah sepanjang laluan dari [alongM] ke hadapan: tetap pada jalan (jarak berganda
  /// [spacingM]) dan bukan pada kenderaan, jadi ia tidak "berjalan" bersama kereta. Hanya [count]
  /// yang pertama di hadapan dihantar ke peta.
  List<({GeoPoint point, double bearing})> chevronsAhead(
    double alongM, {
    double spacingM = 50,
    int count = 14,
    double clearM = 12,
  }) {
    if (points.length < 2 || totalM <= 0) return const [];
    final first = ((alongM + clearM) / spacingM).ceil();
    final out = <({GeoPoint point, double bearing})>[];
    for (var k = first; out.length < count; k++) {
      final d = k * spacingM;
      // Tidak di hujung: anak panah yang menuding ke luar laluan mengelirukan.
      if (d > totalM - clearM) break;
      out.add((point: pointAt(d), bearing: bearingAt(d)));
    }
    return out;
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
}

/// Satu keping laluan navigasi (~[NavRouteLine.chunkM]).
class NavRouteChunk {
  const NavRouteChunk({required this.points});

  final List<GeoPoint> points;
}
