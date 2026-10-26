import 'package:flutter/foundation.dart';

/// Had laju satu tepi jalan sepanjang laluan. [limitKmh] null = tidak diketahui (data OSM tidak lengkap:
/// ~65% tepi KLCC-KLIA mempunyai had), jadi UI mesti menunjukkan had hanya bila ada.
@immutable
class SpeedLimitSegment {
  const SpeedLimitSegment({
    required this.beginShapeIndex,
    required this.endShapeIndex,
    required this.lengthM,
    required this.limitKmh,
  });

  final int beginShapeIndex;
  final int endShapeIndex;
  final double lengthM;
  final int? limitKmh;
}

/// Had laju sepanjang satu laluan, boleh ditanya mengikut indeks titik atau jarak sepanjang laluan.
@immutable
class SpeedLimits {
  const SpeedLimits(this.segments);

  static const empty = SpeedLimits([]);

  final List<SpeedLimitSegment> segments;

  bool get isEmpty => segments.isEmpty;

  /// Had pada titik laluan [shapeIndex] (indeks dalam `RouteOption.points`), atau null.
  int? atShapeIndex(int shapeIndex) {
    if (segments.isEmpty || shapeIndex < 0) return null;
    // Segmen bersebelahan dan tersusun menaik: carian binari.
    var lo = 0;
    var hi = segments.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final s = segments[mid];
      if (shapeIndex < s.beginShapeIndex) {
        hi = mid - 1;
      } else if (shapeIndex >= s.endShapeIndex && mid != segments.length - 1) {
        lo = mid + 1;
      } else {
        return s.limitKmh;
      }
    }
    return null;
  }

  /// Had pada [meters] sepanjang laluan dari permulaan, atau null. Jarak melepasi hujung memulangkan
  /// had segmen terakhir (laluan yang hampir tamat tidak patut kehilangan had kerana pembundaran).
  int? atDistance(double meters) {
    if (segments.isEmpty || meters < 0) return null;
    var acc = 0.0;
    for (final s in segments) {
      acc += s.lengthM;
      if (meters < acc) return s.limitKmh;
    }
    return segments.last.limitKmh;
  }
}

enum OverspeedLevel { none, warning }

/// Menilai kelajuan terhadap had. Tiada had diketahui -> tiada amaran (jangan menuduh tanpa data).
///
/// [toleranceKmh] ialah ambang amaran di atas had (Bahagian 17.2: +0, +5, +10 km/j). Kelajuan dibundar ke km/j
/// terdekat supaya paparan dan amaran konsisten.
OverspeedLevel overspeedLevel({
  required double speedKmh,
  required int? limitKmh,
  int toleranceKmh = 0,
}) {
  if (limitKmh == null || limitKmh <= 0 || speedKmh.isNaN || speedKmh < 0) {
    return OverspeedLevel.none;
  }
  return speedKmh.round() > limitKmh + toleranceKmh
      ? OverspeedLevel.warning
      : OverspeedLevel.none;
}
