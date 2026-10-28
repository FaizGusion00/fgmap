import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import '../../route_preview/domain/route_option.dart';

/// Jenis manuver yang difahami navigasi, dipetakan daripada jenis manuver Valhalla.
enum ManeuverKind {
  depart,
  straight,
  slightRight,
  right,
  sharpRight,
  slightLeft,
  left,
  sharpLeft,
  uTurn,
  rampStraight,
  rampRight,
  rampLeft,
  exitRight,
  exitLeft,
  keepStraight,
  keepRight,
  keepLeft,
  merge,
  mergeRight,
  mergeLeft,
  roundabout,
  ferry,
  arrive,
  arriveRight,
  arriveLeft,

  /// Tiada tindakan pemandu (cth. jalan bertukar nama, keluar bulatan); tidak diumumkan.
  none,
}

/// Memetakan `type` manuver Valhalla (lihat dokumen Valhalla "DirectionsLeg.Maneuver.Type").
ManeuverKind maneuverKindFromValhalla(int type) => switch (type) {
  1 || 2 || 3 => ManeuverKind.depart,
  4 => ManeuverKind.arrive,
  5 => ManeuverKind.arriveRight,
  6 => ManeuverKind.arriveLeft,
  9 => ManeuverKind.slightRight,
  10 => ManeuverKind.right,
  11 => ManeuverKind.sharpRight,
  12 || 13 => ManeuverKind.uTurn,
  14 => ManeuverKind.sharpLeft,
  15 => ManeuverKind.left,
  16 => ManeuverKind.slightLeft,
  17 => ManeuverKind.rampStraight,
  18 => ManeuverKind.rampRight,
  19 => ManeuverKind.rampLeft,
  20 => ManeuverKind.exitRight,
  21 => ManeuverKind.exitLeft,
  22 => ManeuverKind.keepStraight,
  23 => ManeuverKind.keepRight,
  24 => ManeuverKind.keepLeft,
  25 => ManeuverKind.merge,
  37 => ManeuverKind.mergeRight,
  38 => ManeuverKind.mergeLeft,
  26 => ManeuverKind.roundabout,
  28 => ManeuverKind.ferry,
  // 0 tiada, 7 bertukar nama, 8 teruskan, 27 keluar bulatan, 29 keluar feri, 30+ pengangkutan awam.
  _ => ManeuverKind.none,
};

/// Satu manuver dalam laluan navigasi, dengan kedudukannya sepanjang laluan.
@immutable
class NavManeuver {
  const NavManeuver({
    required this.index,
    required this.kind,
    required this.startM,
    required this.lengthM,
    required this.timeS,
    required this.streetNames,
    this.roundaboutExit,
  });

  /// Indeks dalam [NavRoute.maneuvers].
  final int index;
  final ManeuverKind kind;

  /// Jarak dari permulaan laluan ke titik manuver (di mana pemandu patut bertindak).
  final double startM;

  /// Panjang segmen selepas manuver ini, hingga manuver seterusnya.
  final double lengthM;
  final double timeS;
  final List<String> streetNames;
  final int? roundaboutExit;

  bool get isArrival =>
      kind == ManeuverKind.arrive ||
      kind == ManeuverKind.arriveRight ||
      kind == ManeuverKind.arriveLeft;

  /// Manuver yang memerlukan tindakan pemandu dan wajar diumumkan.
  bool get isActionable => kind != ManeuverKind.none;

  /// Nama jalan yang paling berguna untuk disebut: nama biasa dahulu, kod jalan (E12, B48)
  /// hanya jika tiada nama lain.
  String? get street {
    for (final name in streetNames) {
      if (!_roadRef.hasMatch(name)) return name;
    }
    return streetNames.isEmpty ? null : streetNames.first;
  }

  static final _roadRef = RegExp(r'^[A-Z]{1,3}\s?\d+[A-Z]?$');
}

/// Laluan yang disediakan untuk navigasi: jarak kumulatif, lokasi manuver dan masa baki.
///
/// Semua kedudukan dalam navigasi ialah "jarak sepanjang laluan" (meter) pada geometri ini, bukan
/// indeks titik, supaya mudah dibandingkan dan diinterpolasi.
class NavRoute {
  factory NavRoute(RouteOption option) {
    final points = option.points;
    final cum = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cum[i] = cum[i - 1] + distanceMeters(points[i - 1], points[i]);
    }
    final total = points.isEmpty ? 0.0 : cum.last;

    final maneuvers = <NavManeuver>[];
    for (var i = 0; i < option.maneuvers.length; i++) {
      final m = option.maneuvers[i];
      final startIndex = m.beginShapeIndex.clamp(0, points.length - 1);
      final start = points.isEmpty ? 0.0 : cum[startIndex];
      final endIndex = i + 1 < option.maneuvers.length
          ? option.maneuvers[i + 1].beginShapeIndex.clamp(0, points.length - 1)
          : points.length - 1;
      final end = points.isEmpty ? 0.0 : cum[endIndex];
      maneuvers.add(
        NavManeuver(
          index: i,
          kind: maneuverKindFromValhalla(m.type),
          startM: start,
          lengthM: end - start,
          timeS: m.timeS.toDouble(),
          streetNames: m.streetNames,
          roundaboutExit: m.roundaboutExitCount,
        ),
      );
    }

    // Masa kumulatif pada permulaan setiap manuver (sempadan segmen masa).
    final startTimes = List<double>.filled(maneuvers.length, 0);
    for (var i = 1; i < maneuvers.length; i++) {
      startTimes[i] = startTimes[i - 1] + maneuvers[i - 1].timeS;
    }

    return NavRoute._(
      option: option,
      cum: cum,
      totalM: total,
      maneuvers: maneuvers,
      startTimes: startTimes,
    );
  }

  NavRoute._({
    required this.option,
    required this.cum,
    required this.totalM,
    required this.maneuvers,
    required List<double> startTimes,
  }) : _startTimes = startTimes;

  final RouteOption option;
  final List<double> cum;
  final double totalM;
  final List<NavManeuver> maneuvers;
  final List<double> _startTimes;

  List<GeoPoint> get points => option.points;

  /// Selekoh yang dilicinkan untuk PAPARAN sahaja (kedudukan dan arah kereta). Padanan GPS, kemajuan
  /// dan manuver kekal pada polyline asal.
  late final List<_Corner> _corners = _buildCorners();

  /// Jejari lengkung selekoh paparan (meter). Persimpangan bandar biasa 8-15 m.
  static const displayCornerRadiusM = 12.0;

  /// Belokan lebih kecil daripada ini tidak dilengkungkan (dikendalikan oleh kord look-ahead);
  /// lebih daripada [_maxCornerDeg] ialah pusingan-U / berpatah balik dan dibiarkan tajam.
  static const _minCornerDeg = 25.0;
  static const _maxCornerDeg = 150.0;

  List<_Corner> _buildCorners() {
    final out = <_Corner>[];
    for (var i = 1; i < points.length - 1; i++) {
      final lenIn = cum[i] - cum[i - 1];
      final lenOut = cum[i + 1] - cum[i];
      if (lenIn < 2 || lenOut < 2) continue;
      final b1 = bearingDegrees(points[i - 1], points[i]);
      final b2 = bearingDegrees(points[i], points[i + 1]);
      final turn = angleDelta(b1, b2);
      final mag = turn.abs();
      if (mag < _minCornerDeg || mag > _maxCornerDeg) continue;
      final half = mag * math.pi / 360;
      var radius = displayCornerRadiusM;
      var t = radius * math.tan(half);
      // Tidak melebihi 45% segmen bersebelahan supaya dua selekoh rapat tidak bertindih.
      final maxT = 0.45 * math.min(lenIn, lenOut);
      if (t > maxT) {
        t = maxT;
        radius = t / math.tan(half);
      }
      if (radius < 3) continue;
      out.add(
        _Corner(
          vertex: points[i],
          startD: cum[i] - t,
          endD: cum[i] + t,
          inBearing: b1,
          turnDeg: turn,
          radiusM: radius,
          tangentM: t,
        ),
      );
    }
    return out;
  }

  /// Selekoh yang mengandungi [distanceM], atau null.
  _Corner? _cornerAt(double distanceM) {
    var lo = 0;
    var hi = _corners.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final c = _corners[mid];
      if (distanceM < c.startD) {
        hi = mid - 1;
      } else if (distanceM > c.endD) {
        lo = mid + 1;
      } else {
        return c;
      }
    }
    return null;
  }

  /// Jarak ke permulaan selekoh paparan seterusnya selepas [distanceM], atau infiniti.
  double _distanceToNextCorner(double distanceM) {
    for (final c in _corners) {
      if (c.startD > distanceM) return c.startD - distanceM;
    }
    return double.infinity;
  }

  /// Kedudukan PAPARAN pada [distanceM]: sama dengan [pointAt] kecuali di dalam selekoh, di mana ia
  /// mengikut lengkung berjejari (kenderaan sebenar tidak berputar di bucu tajam).
  GeoPoint displayPointAt(double distanceM) {
    final c = _cornerAt(distanceM);
    if (c == null) return pointAt(distanceM);
    return c.pointAt(distanceM);
  }

  /// Arah PAPARAN pada [distanceM]: di dalam selekoh ialah tangen lengkung (tepat dan serentak dengan
  /// kedudukan); di tempat lain, kord pendek (<= [lookAheadM], dikurangkan sebelum selekoh) supaya
  /// tidak berputar lebih awal daripada kenderaan.
  double displayBearingAt(double distanceM, {double lookAheadM = 8}) {
    final c = _cornerAt(distanceM);
    if (c != null) return c.bearingAt(distanceM);
    final look = math.min(lookAheadM, _distanceToNextCorner(distanceM));
    if (look < 1) return bearingAt(distanceM, lookAheadM: 1);
    return bearingAt(distanceM, lookAheadM: look);
  }

  bool get isUsable => option.points.length >= 2 && totalM > 0;

  /// Indeks segmen (titik i -> i+1) yang mengandungi [distanceM].
  int segmentAt(double distanceM) {
    if (points.length < 2) return 0;
    var lo = 0;
    var hi = points.length - 2;
    final d = distanceM.clamp(0.0, totalM);
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (cum[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  GeoPoint pointAt(double distanceM) {
    if (points.isEmpty) return const GeoPoint(0, 0);
    if (points.length == 1) return points.first;
    final d = distanceM.clamp(0.0, totalM);
    final i = segmentAt(d);
    final len = cum[i + 1] - cum[i];
    final t = len <= 0 ? 0.0 : (d - cum[i]) / len;
    final a = points[i];
    final b = points[i + 1];
    return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
  }

  /// Arah laluan pada [distanceM], dilicinkan dengan mengukur arah ke titik [lookAheadM] di hadapan.
  /// Menggunakan kord (bukan segmen tunggal) supaya tidak bergegar pada geometri yang rapat.
  double bearingAt(double distanceM, {double lookAheadM = 20}) {
    if (points.length < 2) return 0;
    // Di hujung laluan tiada "hadapan": ukur dari titik sebelumnya.
    if (distanceM + lookAheadM > totalM) {
      return bearingDegrees(
        pointAt(math.max(0, totalM - lookAheadM)),
        pointAt(totalM),
      );
    }
    final from = pointAt(distanceM);
    var to = pointAt(distanceM + lookAheadM);
    if (distanceMeters(from, to) < 1) {
      to = points[math.min(segmentAt(distanceM) + 1, points.length - 1)];
    }
    return bearingDegrees(from, to);
  }

  /// Manuver yang sedang dilalui pada [distanceM] (yang terakhir bermula sebelum titik itu).
  NavManeuver? maneuverAt(double distanceM) {
    NavManeuver? current;
    for (final m in maneuvers) {
      if (m.startM <= distanceM) {
        current = m;
      } else {
        break;
      }
    }
    return current;
  }

  /// Manuver bertindakan pertama yang bermula SELEPAS [distanceM] (+ [marginM] supaya manuver yang
  /// sedang dilakukan tidak dikira "seterusnya").
  NavManeuver? nextActionable(double distanceM, {double marginM = 0}) {
    for (final m in maneuvers) {
      if (m.startM > distanceM + marginM && m.isActionable) return m;
    }
    return null;
  }

  /// Manuver bertindakan berikutnya selepas [after].
  NavManeuver? actionableAfter(NavManeuver after) {
    for (var i = after.index + 1; i < maneuvers.length; i++) {
      if (maneuvers[i].isActionable) return maneuvers[i];
    }
    return null;
  }

  /// Masa (saat) mengikut anggaran laluan dari permulaan hingga [distanceM].
  double plannedTimeAt(double distanceM) {
    if (maneuvers.isEmpty) {
      return totalM <= 0
          ? 0
          : option.durationS * (distanceM.clamp(0, totalM) / totalM);
    }
    final d = distanceM.clamp(0.0, totalM);
    var i = 0;
    while (i + 1 < maneuvers.length && maneuvers[i + 1].startM <= d) {
      i++;
    }
    final m = maneuvers[i];
    final within = m.lengthM <= 0
        ? 0.0
        : ((d - m.startM) / m.lengthM).clamp(0.0, 1.0);
    return _startTimes[i] + m.timeS * within;
  }

  /// Anggaran masa baki (saat) dari [distanceM] hingga destinasi.
  double plannedRemainingTime(double distanceM) {
    final total = maneuvers.isEmpty
        ? option.durationS.toDouble()
        : _startTimes.last + maneuvers.last.timeS;
    return math.max(0, total - plannedTimeAt(distanceM));
  }

  /// Bahagian laluan dari [fromM] ke hadapan sejauh [aheadM], untuk dilukis di peta. Titik jauh
  /// dijarangkan supaya data yang dihantar ke peta kekal kecil pada laluan beratus kilometer.
  List<GeoPoint> remainingShape(
    double fromM, {
    double aheadM = double.infinity,
    double farDetailM = 2000,
    double farStepM = 200,
  }) {
    if (points.length < 2) return points;
    final start = fromM.clamp(0.0, totalM);
    final first = segmentAt(start);
    final out = <GeoPoint>[pointAt(start)];
    final limit = start + aheadM;
    var lastKept = start;
    for (var i = first + 1; i < points.length; i++) {
      final d = cum[i];
      if (d > limit) {
        out.add(pointAt(limit));
        return out;
      }
      final isLast = i == points.length - 1;
      if (d - start <= farDetailM || d - lastKept >= farStepM || isLast) {
        out.add(points[i]);
        lastKept = d;
      }
    }
    return out;
  }
}

/// Selekoh yang dilengkungkan (arka bulat) di sekitar satu bucu polyline.
class _Corner {
  _Corner({
    required this.vertex,
    required this.startD,
    required this.endD,
    required this.inBearing,
    required this.turnDeg,
    required this.radiusM,
    required this.tangentM,
  });

  final GeoPoint vertex;

  /// Jarak laluan (polyline asal) di mana lengkung bermula dan berakhir ([vertex] +- tangen).
  final double startD;
  final double endD;
  final double inBearing;

  /// Belokan bertanda: positif = kanan.
  final double turnDeg;
  final double radiusM;
  final double tangentM;

  double _fraction(double d) =>
      ((d - startD) / (endD - startD)).clamp(0.0, 1.0);

  double bearingAt(double d) =>
      normalizeBearing(inBearing + _fraction(d) * turnDeg);

  GeoPoint pointAt(double d) {
    // Satah tempatan (timur x, utara y) berpusat pada bucu.
    final entry = _offset(vertex, inBearing + 180, tangentM);
    final h = bearingAt(d) * math.pi / 180;
    final h1 = inBearing * math.pi / 180;
    final right = turnDeg > 0;
    // Normal ke dalam lengkung: kanan jika belok kanan, kiri jika belok kiri.
    (double, double) normal(double bearingRad) {
      final dx = math.sin(bearingRad);
      final dy = math.cos(bearingRad);
      return right ? (dy, -dx) : (-dy, dx);
    }

    final (nx1, ny1) = normal(h1);
    final (nx, ny) = normal(h);
    // Pusat = masuk + R * normal(masuk); kedudukan = pusat - R * normal(arah semasa).
    final dx = radiusM * (nx1 - nx);
    final dy = radiusM * (ny1 - ny);
    return _shift(entry, dx, dy);
  }

  static GeoPoint _offset(GeoPoint from, double bearing, double distanceM) =>
      destinationPoint(from, bearing, distanceM);

  static GeoPoint _shift(GeoPoint from, double eastM, double northM) {
    final lat = from.lat + northM / 111320;
    final lng =
        from.lng + eastM / (111320 * math.cos(from.lat * math.pi / 180));
    return GeoPoint(lat, lng);
  }
}
