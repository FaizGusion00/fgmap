import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'nav_route.dart';

/// Hasil memadankan satu kedudukan dengan laluan.
@immutable
class RouteMatch {
  const RouteMatch({
    required this.alongM,
    required this.crossTrackM,
    required this.segmentIndex,
    required this.snapped,
    required this.routeBearing,
  });

  /// Jarak dari permulaan laluan ke titik terpadan.
  final double alongM;

  /// Jarak mendatar dari kedudukan ke laluan.
  final double crossTrackM;
  final int segmentIndex;
  final GeoPoint snapped;

  /// Arah laluan pada titik terpadan.
  final double routeBearing;
}

/// Memadankan kedudukan GPS dengan laluan (map-matching tempatan, tanpa rangkaian; Bahagian 8.3 dan
/// 8.5B pelan).
///
/// Mencari hanya dalam tetingkap sekitar kemajuan terakhir supaya (a) murah, dan (b) jalan selari
/// atau lingkaran yang menghampiri laluan tidak menarik padanan melompat. Arah gerakan digunakan
/// untuk memilih lorong yang betul pada jalan berpisah.
class RouteTracker {
  RouteTracker(this.route);

  final NavRoute route;

  double? _lastAlongM;

  /// Kemajuan terakhir yang diterima, atau null sebelum padanan pertama.
  double? get lastAlongM => _lastAlongM;

  /// Berapa jauh ke belakang kemajuan terakhir yang dibenarkan dicari (hingar GPS, bukan berundur).
  static const _backwardWindowM = 60.0;

  /// Padanan dalam tetingkap yang lebih jauh daripada ini dianggap meragukan, lalu seluruh laluan
  /// dicari semula (cth. selepas terowong panjang atau jurang isyarat).
  static const _globalSearchThresholdM = 120.0;

  RouteMatch match(
    GeoPoint position, {
    double? headingDegrees,
    double speedMps = 0,
    Duration gap = Duration.zero,
  }) {
    final last = _lastAlongM;
    RouteMatch best;
    if (last == null) {
      best = _search(
        position,
        0,
        route.points.length - 2,
        headingDegrees,
        null,
      );
    } else {
      // Tetingkap ke hadapan meliputi jarak yang mungkin dilalui semasa jurang isyarat.
      final ahead = math.max(1500.0, speedMps * gap.inSeconds * 1.5 + 500);
      final lo = route.segmentAt(last - _backwardWindowM);
      final hi = route.segmentAt(last + ahead);
      best = _search(position, lo, hi, headingDegrees, last);
      if (best.crossTrackM > _globalSearchThresholdM) {
        final global = _search(
          position,
          0,
          route.points.length - 2,
          headingDegrees,
          last,
        );
        if (global.crossTrackM + 40 < best.crossTrackM) best = global;
      }
    }
    _lastAlongM = best.alongM;
    return best;
  }

  void reset() => _lastAlongM = null;

  RouteMatch _search(
    GeoPoint p,
    int from,
    int to,
    double? heading,
    double? last,
  ) {
    final pts = route.points;
    final first = from.clamp(0, pts.length - 2);
    final lastSeg = to.clamp(first, pts.length - 2);

    var bestScore = double.infinity;
    var bestSeg = first;
    SegmentProjection? bestProj;

    for (var i = first; i <= lastSeg; i++) {
      final proj = projectToSegment(p, pts[i], pts[i + 1]);
      var score = proj.distanceM;
      // Awal-awal penolakan: skor sudah melebihi yang terbaik tanpa penalti.
      if (score >= bestScore) continue;

      final segLen = route.cum[i + 1] - route.cum[i];
      final along = route.cum[i] + proj.t * segLen;
      if (heading != null && segLen > 0.5) {
        final segBearing = bearingDegrees(pts[i], pts[i + 1]);
        final delta = angleDelta(segBearing, heading).abs();
        // Penalti arah, sengaja KECIL untuk beza sudut sederhana: heading GPS (kursus Doppler) lewat
        // ~1 s di selekoh, dan penalti besar menahan padanan pada kaki lama melepasi bucu (kereta
        // tersangkut lalu melompat). Berlawanan arah (lorong bertentangan, >120 deg): penalti besar.
        score += delta <= 60
            ? delta * 0.03
            : delta <= 120
            ? 1.8 + (delta - 60) * 0.1
            : 7.8 + (delta - 120) * 0.6;
      }
      if (last != null) {
        if (along < last - 20) score += (last - along) * 0.5;
        // Sedikit keutamaan kepada padanan hampir kemajuan terakhir (lingkaran, lorong bertindih).
        score += (along - last).abs() * 0.004;
      }
      if (score < bestScore) {
        bestScore = score;
        bestSeg = i;
        bestProj = proj;
      }
    }

    final proj = bestProj ?? projectToSegment(p, pts[first], pts[first + 1]);
    final segLen = route.cum[bestSeg + 1] - route.cum[bestSeg];
    final along = route.cum[bestSeg] + proj.t * segLen;
    return RouteMatch(
      alongM: along,
      crossTrackM: proj.distanceM,
      segmentIndex: bestSeg,
      snapped: proj.point,
      routeBearing: route.bearingAt(along, lookAheadM: 15),
    );
  }
}
