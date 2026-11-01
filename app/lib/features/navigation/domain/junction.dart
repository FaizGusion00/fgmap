import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'nav_route.dart';

/// Bentuk simpang.
enum JunctionKind {
  /// Simpang empat (atau lebih).
  cross,

  /// Simpang tiga.
  tee,

  /// Bulatan.
  roundabout,
}

/// Bentuk sebenar simpang pada satu manuver, daripada data jalan OSM (Valhalla `trace_attributes`):
/// setiap jalan yang bertemu di simpang itu pada sudut sebenarnya. Sudut adalah relatif kepada arah
/// kenderaan masuk (0 = terus ke hadapan, positif = ke kanan), jadi jalan masuk sentiasa di bawah.
///
/// Ini BUKAN data lorong: ia hanya geometri jalan, dan cukup untuk menunjukkan "keluar jalan mana".
@immutable
class Junction {
  const Junction({
    required this.kind,
    required this.exitDeg,
    required this.otherArmsDeg,
    this.roundaboutExit,
  });

  final JunctionKind kind;

  /// Jalan yang diambil.
  final double exitDeg;

  /// Jalan lain yang bertemu di simpang (tidak termasuk jalan masuk dan jalan yang diambil).
  final List<double> otherArmsDeg;

  /// Nombor keluar bulatan (daripada arahan laluan), jika bulatan.
  final int? roundaboutExit;

  /// Bilangan jalan di simpang termasuk jalan masuk.
  int get armCount => otherArmsDeg.length + 2;

  @override
  bool operator ==(Object other) =>
      other is Junction &&
      other.kind == kind &&
      other.exitDeg == exitDeg &&
      listEquals(other.otherArmsDeg, otherArmsDeg) &&
      other.roundaboutExit == roundaboutExit;

  @override
  int get hashCode =>
      Object.hash(kind, exitDeg, Object.hashAll(otherArmsDeg), roundaboutExit);
}

/// Manuver yang patut mendapat gambar simpang (belokan sebenar di persimpangan).
bool wantsJunction(NavManeuver m) => switch (m.kind) {
  ManeuverKind.left ||
  ManeuverKind.right ||
  ManeuverKind.sharpLeft ||
  ManeuverKind.sharpRight ||
  ManeuverKind.slightLeft ||
  ManeuverKind.slightRight ||
  ManeuverKind.roundabout => true,
  _ => false,
};

/// Bahagian laluan yang dihantar ke Valhalla: ~80 m sebelum manuver hingga selepasnya (bulatan:
/// seluruh lingkaran, dihadkan). Pendek supaya permintaan kecil dan pantas, juga pada telefon murah.
List<GeoPoint> junctionSlice(NavRoute route, NavManeuver m) {
  final from = math.max(0.0, m.startM - 80);
  final after = m.kind == ManeuverKind.roundabout
      ? math.min(m.lengthM, 300.0) + 60
      : 60.0;
  final to = math.min(route.totalM, m.startM + after);
  if (to - from < 20) return const [];
  final out = <GeoPoint>[route.pointAt(from)];
  for (var i = 0; i < route.points.length; i++) {
    final d = route.cum[i];
    if (d > from && d < to) out.add(route.points[i]);
  }
  out.add(route.pointAt(to));
  return out;
}

/// Permintaan `trace_attributes` untuk [slice]: hanya medan geometri simpang.
Map<String, Object?> buildJunctionRequest(
  List<GeoPoint> slice,
  String costing,
) => {
  'shape': [
    for (final p in slice) {'lat': p.lat, 'lon': p.lng},
  ],
  'costing': costing,
  'shape_match': 'map_snap',
  'filters': {
    'attributes': [
      'shape',
      'edge.begin_shape_index',
      'edge.end_shape_index',
      'edge.begin_heading',
      'edge.end_heading',
      'edge.roundabout',
      'node.intersecting_edge.begin_heading',
      'node.intersecting_edge.use',
      'node.intersecting_edge.driveability',
    ],
    'action': 'include',
  },
};

/// Jalan yang dilukis: jalan biasa dan ramp yang boleh dipandu (bukan lintasan pejalan kaki,
/// lorong servis, atau laluan basikal).
bool _isRoadArm(Map<dynamic, dynamic> e) {
  final use = e['use'];
  final drive = e['driveability'];
  return (use == 'road' || use == 'ramp') && drive is String && drive != 'none';
}

/// Menghurai simpang di [at] (titik manuver) daripada respons `trace_attributes`. Null jika simpang
/// tidak ditemui berhampiran [at] (padanan gagal) atau data tidak lengkap: pemanggil kembali ke
/// gambar anggaran.
Junction? parseJunction(
  Object? body, {
  required GeoPoint at,
  required bool roundabout,
  int? roundaboutExit,
}) {
  final decoded = body is String ? jsonDecode(body) : body;
  if (decoded is! Map) return null;
  final edges = decoded['edges'];
  final shapeText = decoded['shape'];
  if (edges is! List || edges.length < 2 || shapeText is! String) return null;
  final shape = decodePolyline(shapeText);
  if (shape.isEmpty) return null;

  // Tepi masuk: tepi yang nod hujungnya paling hampir dengan titik manuver.
  var best = -1;
  var bestD = double.infinity;
  for (var i = 0; i < edges.length - 1; i++) {
    final e = edges[i];
    if (e is! Map) continue;
    final end = e['end_shape_index'];
    if (end is! int || end < 0 || end >= shape.length) continue;
    final d = distanceMeters(shape[end], at);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  if (best < 0 || bestD > 30) return null;
  final entry = edges[best] as Map;
  final inHeading = entry['end_heading'];
  if (inHeading is! num) return null;
  double rel(num heading) =>
      angleDelta(inHeading.toDouble(), heading.toDouble());

  if (!roundabout) {
    final out = edges[best + 1];
    if (out is! Map) return null;
    final outHeading = out['begin_heading'];
    if (outHeading is! num) return null;
    final node = entry['end_node'];
    final others = <double>[];
    if (node is Map && node['intersecting_edges'] is List) {
      for (final x in node['intersecting_edges'] as List) {
        if (x is! Map || !_isRoadArm(x)) continue;
        final h = x['begin_heading'];
        if (h is num) others.add(rel(h));
      }
    }
    // Jalan masuk dari belakang (~180) bukan "jalan lain"; begitu juga pendua jalan yang diambil.
    final exit = rel(outHeading);
    final arms = _dedupe(
      others.where((a) => a.abs() < 160 && (a - exit).abs() > 12),
    );
    return Junction(
      kind: arms.length >= 2 ? JunctionKind.cross : JunctionKind.tee,
      exitDeg: exit,
      otherArmsDeg: arms,
    );
  }

  // Bulatan: ikut tepi lingkaran hingga keluar; jalan yang ditemui di sepanjang lingkaran ialah
  // jalan sebenar (dilukis pudar, tanpa nombor: kiraan keluar mengikut arahan laluan sahaja).
  final others = <double>[];
  var i = best + 1;
  var sawRing = false;
  for (; i < edges.length; i++) {
    final e = edges[i];
    if (e is! Map) return null;
    if (e['roundabout'] != true) break;
    sawRing = true;
    final node = e['end_node'];
    if (i + 1 < edges.length &&
        (edges[i + 1] as Map?)?['roundabout'] == true &&
        node is Map &&
        node['intersecting_edges'] is List) {
      for (final x in node['intersecting_edges'] as List) {
        if (x is! Map || !_isRoadArm(x)) continue;
        // Jalan sehala MASUK ke bulatan sahaja: bukan jalan keluar.
        if (x['driveability'] == 'backward') continue;
        final h = x['begin_heading'];
        if (h is num) others.add(rel(h));
      }
    }
  }
  if (!sawRing || i >= edges.length) return null;
  final outHeading = (edges[i] as Map)['begin_heading'];
  if (outHeading is! num) return null;
  final exit = rel(outHeading);
  return Junction(
    kind: JunctionKind.roundabout,
    exitDeg: exit,
    otherArmsDeg: _dedupe(others.where((a) => (a - exit).abs() > 15)),
    roundaboutExit: roundaboutExit,
  );
}

List<double> _dedupe(Iterable<double> angles) {
  final out = <double>[];
  for (final a in angles) {
    if (out.every((b) => angleDelta(a, b).abs() > 15)) out.add(a);
  }
  return out;
}
