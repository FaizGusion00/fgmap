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
const _minHighwayTripM = 5000;
const _minShortestTripM = 3000;
const _minDetourTripM = 3000;
const _longDetourTripM = 8000;

/// Merancang permintaan tambahan DIHAD ([maxExtra]) selepas laluan biasa tiba. Susunan keutamaan:
///  1. tanpa tol (jika laluan biasa ada tol);
///  2. elak lebuh raya;
///  3. jarak terpendek;
///  4. lencongan paksa: bulatan yang dielakkan pada 20-80% sepanjang laluan utama, bermula dari
///     tengah (yang paling menghasilkan laluan berbeza) ke hujung.
///
/// Lencongan paksa menjadikan alternatif benar-benar berbeza, bukan variasi kecil laluan yang sama.
/// Bulatan tidak meliputi asal atau destinasi (jika tidak, tiada laluan boleh dikira), dan jejarinya
/// dihadkan 250-1400 m kerana had perimeter `exclude_polygons` pelayan awam ialah 10 km.
List<CandidateRequest> planCandidateRequests(
  RouteQuery base,
  List<RouteOption> standard, {
  int maxExtra = 8,
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

  for (final e in _detourExclusions(base, main)) {
    out.add(
      CandidateRequest(
        base.copyWith(alternates: 0, exclusions: [e]),
        RouteCandidateOrigin.detour,
      ),
    );
  }
  return out.take(maxExtra).toList();
}

List<RouteExclusion> _detourExclusions(RouteQuery base, RouteOption main) {
  if (main.distanceM < _minDetourTripM || main.points.length < 2) {
    return const [];
  }
  final fractions = main.distanceM >= _longDetourTripM
      ? const [0.5, 0.35, 0.65, 0.2, 0.8]
      : const [0.5, 0.3, 0.7];
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
