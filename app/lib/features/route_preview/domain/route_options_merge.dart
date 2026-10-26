import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'route_option.dart';

/// Daripada permintaan mana satu calon laluan datang.
enum RouteCandidateOrigin { standard, noTolls, noHighways }

/// Nisbah (0-1) titik [a] yang disampel dan terletak dalam [toleranceM] daripada garis [b].
double routeCoverage(
  List<GeoPoint> a,
  List<GeoPoint> b, {
  double toleranceM = 40,
  int samples = 48,
}) {
  if (a.isEmpty || b.length < 2) return 0;
  final step = math.max(1, a.length ~/ samples);
  // Selang lintang yang terlalu jauh dilangkau tanpa mengira jarak (1 darjah ≈ 111 km).
  final latSlack = toleranceM / 111000 * 1.5;
  var near = 0;
  var total = 0;
  for (var i = 0; i < a.length; i += step) {
    total++;
    final p = a[i];
    for (var j = 0; j < b.length - 1; j++) {
      final s = b[j];
      final e = b[j + 1];
      if (p.lat > math.max(s.lat, e.lat) + latSlack ||
          p.lat < math.min(s.lat, e.lat) - latSlack) {
        continue;
      }
      if (projectToSegment(p, s, e).distanceM <= toleranceM) {
        near++;
        break;
      }
    }
  }
  return total == 0 ? 0 : near / total;
}

/// Dua laluan dianggap sama jika masing-masing hampir sepenuhnya terletak pada yang satu lagi.
bool isSameRoute(RouteOption a, RouteOption b, {double threshold = 0.85}) {
  return routeCoverage(a.points, b.points) >= threshold &&
      routeCoverage(b.points, a.points) >= threshold;
}

/// Indeks laluan yang paling hampir dengan [tap] dan dalam [toleranceM], atau null. Untuk memilih
/// laluan dengan mengetuknya pada peta.
int? nearestRouteIndex(
  List<List<GeoPoint>> routes,
  GeoPoint tap, {
  required double toleranceM,
}) {
  int? best;
  var bestM = toleranceM;
  final latSlack = toleranceM / 111000 * 1.5;
  for (var r = 0; r < routes.length; r++) {
    final pts = routes[r];
    for (var j = 0; j < pts.length - 1; j++) {
      final s = pts[j];
      final e = pts[j + 1];
      if (tap.lat > math.max(s.lat, e.lat) + latSlack ||
          tap.lat < math.min(s.lat, e.lat) - latSlack) {
        continue;
      }
      final d = projectToSegment(tap, s, e).distanceM;
      if (d < bestM) {
        bestM = d;
        best = r;
      }
    }
  }
  return best;
}

class _Candidate {
  _Candidate(this.route, this.origin);

  final RouteOption route;
  final RouteCandidateOrigin origin;
}

/// Menggabungkan laluan daripada beberapa permintaan menjadi senarai pilihan yang bermakna:
/// membuang pendua dan lencongan melampau, memilih sehingga [maxOptions] yang paling berguna, melabel
/// setiap satu dan menyusun mengikut masa (yang terpantas dahulu).
///
/// [standard] ialah hasil permintaan biasa (laluan utama + alternatif Valhalla); [noTolls] dan
/// [noHighways] hasil permintaan yang mengutamakan mengelak tol / lebuh raya. Valhalla menganggap
/// kedua-duanya keutamaan lembut, jadi hasilnya mungkin sama dengan laluan biasa; ia dibuang sebagai pendua.
List<RouteOption> mergeRouteCandidates({
  required List<RouteOption> standard,
  List<RouteOption> noTolls = const [],
  List<RouteOption> noHighways = const [],
  int maxOptions = 4,
}) {
  final all = <_Candidate>[
    for (final r in standard) _Candidate(r, RouteCandidateOrigin.standard),
    for (final r in noTolls) _Candidate(r, RouteCandidateOrigin.noTolls),
    for (final r in noHighways) _Candidate(r, RouteCandidateOrigin.noHighways),
  ];
  if (all.isEmpty) return const [];

  // Susunan stabil mengikut masa: pada masa sama, calon permintaan biasa didahulukan.
  final sorted = [...all]
    ..sort((a, b) {
      final byTime = a.route.durationS.compareTo(b.route.durationS);
      return byTime != 0 ? byTime : a.origin.index.compareTo(b.origin.index);
    });

  final fastestS = sorted.first.route.durationS;
  // Lencongan yang terlalu panjang tidak berguna sebagai pilihan.
  final limitS = math.max(fastestS * 2, fastestS + 600);

  final kept = <_Candidate>[];
  for (final c in sorted) {
    if (c.route.durationS > limitS) continue;
    if (kept.any((k) => isSameRoute(k.route, c.route))) continue;
    kept.add(c);
  }

  final fastest = kept.first;
  final rest = kept.skip(1).toList();

  // Pilih yang paling berguna dahulu: tanpa tol, tanpa lebuh raya, terpendek; kemudian ikut masa.
  final chosen = <_Candidate, RouteLabel>{fastest: RouteLabel.fastest};

  if (fastest.route.hasTolls) {
    final tollFree = rest.where((c) => !c.route.hasTolls).firstOrNull;
    if (tollFree != null) chosen[tollFree] = RouteLabel.noTolls;
  }

  final noHighway = rest
      .where(
        (c) =>
            !chosen.containsKey(c) &&
            c.origin == RouteCandidateOrigin.noHighways,
      )
      .firstOrNull;
  if (noHighway != null) chosen[noHighway] = RouteLabel.noHighways;

  final shortest = rest
      .where((c) => !chosen.containsKey(c))
      .fold<_Candidate?>(
        null,
        (best, c) =>
            best == null || c.route.distanceM < best.route.distanceM ? c : best,
      );
  if (shortest != null &&
      _clearlyShorter(shortest.route, fastest.route, kept)) {
    chosen[shortest] = RouteLabel.shortest;
  }

  for (final c in rest) {
    if (chosen.length >= maxOptions) break;
    chosen.putIfAbsent(c, () => RouteLabel.alternative);
  }

  // Sempadan maxOptions untuk label khas (tanpa tol + tanpa lebuh raya + terpendek + terpantas).
  final picked = chosen.entries.toList()
    ..sort((a, b) => a.key.route.durationS.compareTo(b.key.route.durationS));
  return [
    for (final e in picked.take(maxOptions)) e.key.route.withLabel(e.value),
  ];
}

/// [candidate] ialah yang terpendek dan beza jaraknya cukup bermakna (>= 5% dan >= 500 m).
bool _clearlyShorter(
  RouteOption candidate,
  RouteOption fastest,
  List<_Candidate> all,
) {
  if (all.any((c) => c.route.distanceM < candidate.distanceM)) return false;
  final saved = fastest.distanceM - candidate.distanceM;
  return saved >= 500 && saved >= fastest.distanceM * 0.05;
}
