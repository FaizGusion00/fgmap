import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'route_option.dart';
import 'route_scoring.dart';

/// Daripada permintaan mana satu calon laluan datang.
enum RouteCandidateOrigin { standard, noTolls, noHighways, shortest, detour }

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

/// Ingatan keputusan [isSameRoute] supaya pasangan yang sama tidak dikira semula setiap kali
/// calon baharu tiba (penggabungan berlaku berkali-kali semasa laluan tiba berperingkat).
class SameRouteMemo {
  final Map<(RouteOption, RouteOption), bool> _cache = {};

  bool isSame(RouteOption a, RouteOption b, double threshold) {
    final key = identityHashCode(a) <= identityHashCode(b) ? (a, b) : (b, a);
    return _cache.putIfAbsent(
      key,
      () => isSameRoute(a, b, threshold: threshold),
    );
  }
}

class _Candidate {
  _Candidate(this.route, this.origin);

  final RouteOption route;
  final RouteCandidateOrigin origin;
  late final double score = routeScore(route);
  late final int turns = turnCountOf(route);
}

/// Had paparan lalai bagi satu senarai pilihan.
const maxRouteOptions = 10;

/// Dua laluan dianggap pendua jika liputan bersama sekurang-kurangnya ini.
const routeDuplicateThreshold = 0.75;

/// Menggabungkan laluan daripada beberapa permintaan menjadi senarai pilihan yang bermakna:
/// membuang pendua dan lencongan melampau, memilih sehingga [maxOptions], melabel setiap satu dan
/// menyusun: **laluan utama dahulu**, kemudian selebihnya mengikut masa.
///
/// Laluan utama BUKAN semestinya yang terpantas: ia ialah skor terbaik ([routeScore]) antara laluan
/// yang masanya dalam 5% daripada yang terpantas, jadi laluan yang jauh lebih mudah dan selamat
/// menang ke atas penjimatan beberapa saat melalui lorong kecil.
///
/// Penapis: masa dalam [fastest x 1.4] dan [fastest + 15 min] (dengan lantai +3 min untuk perjalanan
/// pendek); laluan feri / bersekatan masa dibuang jika wujud yang bersih.
List<RouteOption> mergeRouteCandidates({
  required List<RouteOption> standard,
  List<RouteOption> noTolls = const [],
  List<RouteOption> noHighways = const [],
  List<RouteOption> shortest = const [],
  List<RouteOption> detours = const [],
  int maxOptions = maxRouteOptions,
  SameRouteMemo? memo,
}) {
  final all = <_Candidate>[
    for (final r in standard) _Candidate(r, RouteCandidateOrigin.standard),
    for (final r in noTolls) _Candidate(r, RouteCandidateOrigin.noTolls),
    for (final r in noHighways) _Candidate(r, RouteCandidateOrigin.noHighways),
    for (final r in shortest) _Candidate(r, RouteCandidateOrigin.shortest),
    for (final r in detours) _Candidate(r, RouteCandidateOrigin.detour),
  ];
  if (all.isEmpty) return const [];
  final same = memo ?? SameRouteMemo();

  // Susunan stabil mengikut masa: pada masa sama, calon permintaan biasa didahulukan.
  final sorted = [...all]
    ..sort((a, b) {
      final byTime = a.route.durationS.compareTo(b.route.durationS);
      return byTime != 0 ? byTime : a.origin.index.compareTo(b.origin.index);
    });

  final fastestS = sorted.first.route.durationS;
  final limitS = math.max(
    math.min(fastestS * 1.4, fastestS + 900),
    fastestS + 180,
  );

  var kept = <_Candidate>[];
  for (final c in sorted) {
    if (c.route.durationS > limitS) continue;
    if (kept.any(
      (k) => same.isSame(k.route, c.route, routeDuplicateThreshold),
    )) {
      continue;
    }
    kept.add(c);
  }

  // Feri dan jalan bersekatan masa hanya jika tiada pilihan bersih.
  bool flagged(_Candidate c) => c.route.hasFerry || c.route.hasTimeRestrictions;
  if (kept.any((c) => !flagged(c))) {
    kept = kept.where((c) => !flagged(c)).toList();
  }

  final keptFastest = kept.first;
  // Laluan utama: skor terbaik dalam 5% daripada yang terpantas (sepadan: lebih laju menang).
  final nearFastest = kept
      .where((c) => c.route.durationS <= keptFastest.route.durationS * 1.05)
      .toList();
  final primary = nearFastest.reduce((best, c) {
    if (c.score < best.score - 0.5) return c;
    return best;
  });

  final rest = kept.where((c) => c != primary).toList();
  final chosen = <_Candidate, RouteLabel>{primary: RouteLabel.recommended};

  // Terpantas, jika jelas lebih laju (>= 1 minit) daripada laluan utama.
  if (keptFastest != primary &&
      primary.route.durationS - keptFastest.route.durationS >= 60) {
    chosen[keptFastest] = RouteLabel.fastest;
  }

  if (primary.route.hasTolls) {
    // Utamakan calon daripada permintaan "tanpa tol"; jika tiada, mana-mana yang bebas tol.
    final tollFreeAll = rest
        .where((c) => !chosen.containsKey(c) && !c.route.hasTolls)
        .toList();
    final tollFree =
        tollFreeAll
            .where((c) => c.origin == RouteCandidateOrigin.noTolls)
            .firstOrNull ??
        tollFreeAll.firstOrNull;
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

  final shortestCand = rest
      .where((c) => !chosen.containsKey(c))
      .fold<_Candidate?>(
        null,
        (best, c) =>
            best == null || c.route.distanceM < best.route.distanceM ? c : best,
      );
  if (shortestCand != null &&
      _clearlyShorter(shortestCand.route, primary.route, kept)) {
    chosen[shortestCand] = RouteLabel.shortest;
  }

  // Paling mudah: belokan jauh lebih sedikit daripada laluan utama (yang sendiri banyak belokan).
  if (primary.turns >= 8) {
    final simplest = rest
        .where((c) => !chosen.containsKey(c) && c.turns <= primary.turns * 0.7)
        .fold<_Candidate?>(
          null,
          (best, c) => best == null || c.turns < best.turns ? c : best,
        );
    if (simplest != null) chosen[simplest] = RouteLabel.simplest;
  }

  for (final c in rest) {
    if (chosen.length >= maxOptions) break;
    chosen.putIfAbsent(c, () => RouteLabel.alternative);
  }

  // Utama dahulu; selebihnya mengikut masa. Label khas diutamakan jika melebihi had.
  final others = chosen.entries.where((e) => e.key != primary).toList()
    ..sort((a, b) => a.key.route.durationS.compareTo(b.key.route.durationS));
  return [
    primary.route.withLabel(RouteLabel.recommended),
    for (final e in others.take(maxOptions - 1)) e.key.route.withLabel(e.value),
  ];
}

/// [candidate] ialah yang terpendek dan beza jaraknya cukup bermakna (>= 5% dan >= 500 m).
bool _clearlyShorter(
  RouteOption candidate,
  RouteOption primary,
  List<_Candidate> all,
) {
  if (all.any((c) => c.route.distanceM < candidate.distanceM)) return false;
  final saved = primary.distanceM - candidate.distanceM;
  return saved >= 500 && saved >= primary.distanceM * 0.05;
}
