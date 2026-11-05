import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'nav_route.dart';

/// Petunjuk aras jalan pada satu manuver: penting di persimpangan bertingkat Lembah Klang, di mana
/// jejambat dan jalan bawah bermula di titik yang hampir sama.
enum LevelHint {
  /// Laluan naik jejambat (jambatan OSM) sejurus selepas manuver.
  flyover,

  /// Ada jejambat selari di sini, tetapi laluan kekal di jalan bawah: jangan naik.
  underFlyover,

  /// Laluan masuk terowong / laluan bawah tanah sejurus selepas manuver.
  tunnel,
}

/// Satu rentang laluan (meter dari permulaan) yang jambatan atau terowong (Valhalla `edge.bridge` /
/// `edge.tunnel`).
@immutable
class StructureSpan {
  const StructureSpan(this.startM, this.endM, {this.tunnel = false});

  final double startM;
  final double endM;

  /// Terowong; jika tidak, jambatan (jejambat).
  final bool tunnel;

  double get lengthM => endM - startM;
}

/// Manuver yang biasanya berlaku di cabang jejambat/jalan bawah (bukan belok 90 darjah di lampu isyarat).
bool _forkLike(ManeuverKind k) => switch (k) {
  ManeuverKind.keepLeft ||
  ManeuverKind.keepRight ||
  ManeuverKind.keepStraight ||
  ManeuverKind.rampStraight ||
  ManeuverKind.rampLeft ||
  ManeuverKind.rampRight ||
  ManeuverKind.exitLeft ||
  ManeuverKind.exitRight ||
  ManeuverKind.slightLeft ||
  ManeuverKind.slightRight ||
  ManeuverKind.straight ||
  ManeuverKind.merge ||
  ManeuverKind.mergeLeft ||
  ManeuverKind.mergeRight => true,
  _ => false,
};

/// Petunjuk aras bagi manuver [route] (indeks manuver -> petunjuk).
///
/// - [spans]: jambatan/terowong pada laluan SENDIRI (daripada `trace_attributes`; juga offline).
/// - [osmBridges]: garis jambatan jalan OSM berhampiran simpang (hanya bila dalam talian); digunakan untuk
///   "jalan bawah": jejambat selari bermula di simpang tetapi laluan tidak menaikinya.
///
/// Jujur: tiada petunjuk jika data tidak cukup. Petunjuk hanya untuk struktur yang bermula dalam
/// [aheadM] selepas manuver dan sekurang-kurangnya [minSpanM] panjang (bukan jambatan sungai kecil).
Map<int, LevelHint> levelHintsFor(
  NavRoute route,
  List<StructureSpan> spans, {
  List<List<GeoPoint>> osmBridges = const [],
  double aheadM = 350,
  double minSpanM = 80,
}) {
  final out = <int, LevelHint>{};
  // Satu struktur hanya untuk manuver PERTAMA yang menuju kepadanya (susur keluar + belok sejurus selepas
  // itu tidak disebut "laluan bawah tanah" dua kali).
  final claimed = <StructureSpan>{};
  bool insideAt(double m, {required bool tunnel}) =>
      spans.any((s) => s.tunnel == tunnel && m >= s.startM && m <= s.endM);

  for (final m in route.maneuvers) {
    if (!m.isActionable || m.isArrival || m.kind == ManeuverKind.depart) {
      continue;
    }
    final at = m.startM;
    // Struktur sendiri yang BERMULA tidak lama selepas manuver (bukan yang sudah dinaiki sebelum ini).
    StructureSpan? own;
    for (final s in spans) {
      if (s.lengthM < minSpanM) continue;
      if (s.startM < at - 30 || s.startM > at + aheadM) continue;
      if (insideAt(at - 40, tunnel: s.tunnel)) continue;
      if (claimed.contains(s)) continue;
      if (own == null || s.startM < own.startM) own = s;
    }
    if (own != null) {
      claimed.add(own);
      out[m.index] = own.tunnel ? LevelHint.tunnel : LevelHint.flyover;
      continue;
    }
    if (!_forkLike(m.kind) || osmBridges.isEmpty) continue;
    // Laluan sendiri di atas jambatan sekitar simpang: tiada "jalan bawah".
    final from = math.max(0.0, at - 60);
    final to = math.min(route.totalM, at + 300);
    if (spans.any((s) => !s.tunnel && s.endM > from && s.startM < to)) {
      continue;
    }
    if (_parallelBridgeNear(route, osmBridges, from, to)) {
      out[m.index] = LevelHint.underFlyover;
    }
  }
  return out;
}

/// Benar jika satu jambatan OSM berjalan SELARI dengan laluan (beza arah < 30 darjah, tidak kira arah
/// lalu lintas) dalam 35 m dari garis laluan untuk sekurang-kurangnya 60 m antara [fromM] dan [toM].
/// Jejambat yang melintang (merentasi jalan) tidak dikira: itu bukan pilihan cabang.
bool _parallelBridgeNear(
  NavRoute route,
  List<List<GeoPoint>> bridges,
  double fromM,
  double toM,
) {
  const step = 20.0;
  const maxLateralM = 35.0;
  const maxAngle = 30.0;
  var run = 0;
  for (var d = fromM; d <= toM; d += step) {
    final p = route.pointAt(d);
    final heading = route.bearingAt(d);
    var hit = false;
    for (final line in bridges) {
      for (var i = 0; i < line.length - 1 && !hit; i++) {
        final proj = projectToSegment(p, line[i], line[i + 1]);
        if (proj.distanceM > maxLateralM) continue;
        final b = bearingDegrees(line[i], line[i + 1]);
        var diff = ((heading - b) % 180 + 180) % 180;
        if (diff > 90) diff = 180 - diff;
        if (diff <= maxAngle) hit = true;
      }
      if (hit) break;
    }
    run = hit ? run + 1 : 0;
    if (run >= 3) return true;
  }
  return false;
}

/// Rentang jambatan/terowong daripada tepi `trace_attributes` yang tersusun, dipetakan ke jarak
/// sepanjang [route] melalui indeks titik bentuk (lebih tepat daripada menjumlahkan panjang tepi).
/// Tepi bersebelahan berjenis sama dicantum.
List<StructureSpan> structureSpansFor(
  NavRoute route,
  Iterable<({int beginShapeIndex, int endShapeIndex, bool bridge, bool tunnel})>
  edges,
) {
  final cum = route.cum;
  if (cum.isEmpty) return const [];
  double at(int i) => cum[i.clamp(0, cum.length - 1)];
  final out = <StructureSpan>[];
  for (final e in edges) {
    if (!e.bridge && !e.tunnel) continue;
    final start = at(e.beginShapeIndex);
    final end = at(e.endShapeIndex);
    if (end <= start) continue;
    final tunnel = e.tunnel;
    if (out.isNotEmpty &&
        out.last.tunnel == tunnel &&
        start - out.last.endM < 1) {
      out[out.length - 1] = StructureSpan(out.last.startM, end, tunnel: tunnel);
    } else {
      out.add(StructureSpan(start, end, tunnel: tunnel));
    }
  }
  return out;
}
