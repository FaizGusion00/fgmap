import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'route_option.dart';
import 'route_options_merge.dart';

/// Satu permintaan tambahan untuk mencari laluan alternatif.
class CandidateRequest {
  const CandidateRequest(this.query, this.origin);

  final RouteQuery query;
  final RouteCandidateOrigin origin;
}

/// Perjalanan di bawah jarak ini jarang ada pilihan lebuh raya / jarak terpendek yang bermakna.
const _minHighwayTripM = 3000;
const _minShortestTripM = 1500;
const _minViaTripM = 1500;
const _minDetourTripM = 3000;

/// Susunan titik lalu: (pecahan sepanjang laluan, sisi) dengan sisi +1 = kiri dan -1 = kanan. Berselang
/// sisi supaya setiap kumpulan pertama sudah menghasilkan kedua-dua arah lencongan.
const _viaPlan = [
  (0.35, 1),
  (0.65, -1),
  (0.5, 1),
  (0.5, -1),
  (0.25, -1),
  (0.75, 1),
];

/// Merancang permintaan tambahan DIHAD ([maxExtra]) selepas laluan biasa tiba. Susunan keutamaan:
///  1. tanpa tol (jika laluan biasa ada tol);
///  2. elak lebuh raya;
///  3. jarak terpendek;
///  4. titik lalu (`through`) di kiri/kanan laluan utama: memaksa laluan melalui jalan lain;
///  5. satu lencongan paksa (bulatan dielakkan) di tengah laluan.
///
/// Titik lalu menghasilkan laluan yang benar-benar berbeza (disahkan terhadap Valhalla awam: 8 perjalanan
/// KL/Johor/Pulau Pinang, 4-330 km), tidak seperti lencongan bulatan yang sering kembali ke laluan sama.
/// Ofset titik lalu ialah 7% daripada jarak (400 m - 5 km). Bulatan tidak meliputi asal atau destinasi dan
/// jejarinya dihadkan 250-1400 m kerana had perimeter `exclude_polygons` pelayan awam ialah 10 km.
List<CandidateRequest> planCandidateRequests(
  RouteQuery base,
  List<RouteOption> standard, {
  int maxExtra = 10,
}) {
  if (standard.isEmpty) return const [];
  final main = standard.first;
  final out = <CandidateRequest>[];

  if (standard.any((r) => r.hasTolls)) {
    out.add(
      CandidateRequest(
        base.copyWith(avoidTolls: true, alternates: 0),
        RouteCandidateOrigin.noTolls,
      ),
    );
  }
  if (main.distanceM >= _minHighwayTripM) {
    out.add(
      CandidateRequest(
        base.copyWith(avoidHighways: true, alternates: 0),
        RouteCandidateOrigin.noHighways,
      ),
    );
  }
  if (main.distanceM >= _minShortestTripM) {
    out.add(
      CandidateRequest(
        base.copyWith(shortest: true, alternates: 0),
        RouteCandidateOrigin.shortest,
      ),
    );
  }

  for (final v in _viaPoints(main)) {
    out.add(
      CandidateRequest(
        base.copyWith(alternates: 0, via: [v]),
        RouteCandidateOrigin.detour,
      ),
    );
  }
  for (final e in _detourExclusions(base, main).take(1)) {
    out.add(
      CandidateRequest(
        base.copyWith(alternates: 0, exclusions: [e]),
        RouteCandidateOrigin.detour,
      ),
    );
  }
  return out.take(maxExtra).toList();
}

/// Titik di kiri/kanan [main] (serenjang) pada pecahan [_viaPlan]. Titik yang terlalu hampir dengan asal
/// atau destinasi dilangkau (laluan akan berpatah balik).
List<GeoPoint> _viaPoints(RouteOption main) {
  if (main.distanceM < _minViaTripM || main.points.length < 2) {
    return const [];
  }
  final along = _cumulative(main.points);
  final total = along.last;
  if (total <= 0) return const [];
  final offset = (main.distanceM * 0.07).clamp(400.0, 5000.0);
  final origin = main.points.first;
  final destination = main.points.last;

  final out = <GeoPoint>[];
  for (final (fraction, side) in _viaPlan) {
    final at = total * fraction;
    final here = _pointAt(main.points, along, at);
    final ahead = _pointAt(main.points, along, math.min(total, at + 50));
    final behind = _pointAt(main.points, along, math.max(0, at - 50));
    final bearing = bearingDegrees(behind, ahead);
    final via = destinationPoint(here, bearing + 90.0 * side, offset);
    if (distanceMeters(via, origin) < offset * 0.9 ||
        distanceMeters(via, destination) < offset * 0.9) {
      continue;
    }
    out.add(via);
  }
  return out;
}

List<RouteExclusion> _detourExclusions(RouteQuery base, RouteOption main) {
  if (main.distanceM < _minDetourTripM || main.points.length < 2) {
    return const [];
  }
  const fractions = [0.5];
  final radius = (main.distanceM * 0.02).clamp(250.0, 1400.0);
  final origin = main.points.first;
  final destination = main.points.last;

  final along = _cumulative(main.points);
  final total = along.last;
  if (total <= 0) return const [];

  final out = <RouteExclusion>[];
  for (final f in fractions) {
    final point = _pointAt(main.points, along, total * f);
    // Bulatan tidak boleh menelan asal atau destinasi.
    final margin = radius + 400;
    if (distanceMeters(point, origin) < margin ||
        distanceMeters(point, destination) < margin) {
      continue;
    }
    out.add(RouteExclusion(point, radius));
  }
  return out;
}

List<double> _cumulative(List<GeoPoint> points) {
  final out = <double>[0];
  for (var i = 1; i < points.length; i++) {
    out.add(out.last + distanceMeters(points[i - 1], points[i]));
  }
  return out;
}

GeoPoint _pointAt(List<GeoPoint> points, List<double> along, double meters) {
  var lo = 0;
  var hi = along.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (along[mid] < meters) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo == 0) return points.first;
  final span = along[lo] - along[lo - 1];
  final t = span <= 0 ? 0.0 : math.min(1.0, (meters - along[lo - 1]) / span);
  final a = points[lo - 1];
  final b = points[lo];
  return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
}
