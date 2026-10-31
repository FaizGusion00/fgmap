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
///
/// Dengan [middleOnly], hanya bahagian tengah (buang [middleCut] di awal dan akhir yang hampir selalu
/// dikongsi oleh semua laluan) dibandingkan, jadi laluan yang berbeza di tengah tidak dianggap sama.
bool isSameRoute(
  RouteOption a,
  RouteOption b, {
  double threshold = 0.85,
  bool middleOnly = false,
}) {
  final pa = middleOnly ? middleOf(a.points) : a.points;
  final pb = middleOnly ? middleOf(b.points) : b.points;
  return routeCoverage(pa, pb) >= threshold &&
      routeCoverage(pb, pa) >= threshold;
}

/// Bahagian tengah garis: buang [cut] (pecahan) di awal dan akhir.
List<GeoPoint> middleOf(List<GeoPoint> points, {double cut = 0.15}) {
  if (points.length < 8) return points;
  final from = (points.length * cut).floor();
  final to = (points.length * (1 - cut)).ceil();
  return points.sublist(from, to);
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
  final Map<(RouteOption, RouteOption, bool), bool> _cache = {};

  bool isSame(
    RouteOption a,
    RouteOption b,
    double threshold, {
    bool middleOnly = false,
  }) {
    final key = identityHashCode(a) <= identityHashCode(b)
        ? (a, b, middleOnly)
        : (b, a, middleOnly);
    return _cache.putIfAbsent(
      key,
      () => isSameRoute(a, b, threshold: threshold, middleOnly: middleOnly),
    );
  }
}

class _Candidate {
  _Candidate(this.route, this.origin);

  final RouteOption route;
  final RouteCandidateOrigin origin;
  late final double score = routeScore(route);
  late final int turns = turnCountOf(route);

  /// [score] ditambah kos jarak melebihi laluan terpendek (diisi selepas penapisan).
  double adjustedScore = 0;
}

/// Kos jarak dalam saat bagi setiap km melebihi laluan terpendek yang dikekalkan. Tanpa ini "Disyorkan"
/// hanya menimbang masa, jadi laluan jauh yang kebetulan lebih laju (atau sama laju) menang walaupun ada
/// laluan jauh lebih pendek.
const distanceCostSecondsPerKm = 40.0;

/// Tetingkap masa (nisbah daripada yang terpantas) bagi calon laluan utama.
const primaryTimeWindow = 1.08;

/// Satu laluan "didominasi" jika yang lain lebih pendek DAN lebih laju, masing-masing sekurang-kurangnya
/// ini lebih baik secara relatif (beza kecil tidak dikira supaya laluan lebih mudah masih boleh menang).
const _dominanceMinRelative = 0.03;

/// Calon baharu hanya menggantikan laluan utama sebelumnya jika skornya lebih baik sekurang-kurangnya ini
/// (saat), supaya kad pertama tidak bertukar di bawah mata pengguna semasa laluan tiba berperingkat.
const primaryStickinessS = 60.0;

/// Had paparan lalai bagi satu senarai pilihan.
const maxRouteOptions = 10;

/// Sasaran minimum pilihan (jika wujud laluan yang benar-benar berbeza); penapis dilonggarkan sehingga ini.
const minRouteOptions = 5;

class _MergeTier {
  const _MergeTier(
    this.timeRatio,
    this.timePlusS,
    this.minPlusS,
    this.threshold,
    this.middleOnly,
  );

  final double timeRatio;
  final double timePlusS;
  final double minPlusS;
  final double threshold;
  final bool middleOnly;
}

/// Peringkat 1 ialah penapis asal (1.4x / +15 min, liputan penuh 0.75). Peringkat 2-3 dikira daripada
/// probe Valhalla awam (8 perjalanan): peringkat 1 sahaja memberi 3-9 pilihan; peringkat 2 memberi >= 5.
const _mergeTiers = [
  _MergeTier(1.4, 900, 180, 0.75, false),
  _MergeTier(1.6, 1500, 300, 0.75, true),
  _MergeTier(1.8, 2100, 420, 0.85, true),
];

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
  RouteOption? incumbent,
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

  // Penapis berperingkat: peringkat ketat dahulu; jika kurang daripada [minRouteOptions] pilihan, longgarkan
  // (had masa lebih luas, banding bahagian tengah sahaja) sehingga cukup atau peringkat habis.
  List<_Candidate> keepFor(_MergeTier tier) {
    final limitS = math.max(
      math.min(fastestS * tier.timeRatio, fastestS + tier.timePlusS),
      fastestS + tier.minPlusS,
    );
    final out = <_Candidate>[];
    for (final c in sorted) {
      if (c.route.durationS > limitS) continue;
      if (out.any(
        (k) => same.isSame(
          k.route,
          c.route,
          tier.threshold,
          middleOnly: tier.middleOnly,
        ),
      )) {
        continue;
      }
      out.add(c);
    }
    // Feri dan jalan bersekatan masa hanya jika tiada pilihan bersih.
    bool flagged(_Candidate c) =>
        c.route.hasFerry || c.route.hasTimeRestrictions;
    return out.any((c) => !flagged(c))
        ? out.where((c) => !flagged(c)).toList()
        : out;
  }

  var kept = <_Candidate>[];
  for (final tier in _mergeTiers) {
    final candidate = keepFor(tier);
    if (candidate.length > kept.length) kept = candidate;
    if (kept.length >= minRouteOptions) break;
  }

  final keptFastest = kept.first;
  final shortestKeptM = kept.map((c) => c.route.distanceM).reduce(math.min);
  for (final c in kept) {
    c.adjustedScore =
        c.score +
        math.max(0, c.route.distanceM - shortestKeptM) /
            1000 *
            distanceCostSecondsPerKm;
  }

  // Laluan yang LEBIH JAUH DAN LEBIH LAMA daripada laluan lain tidak patut dipilih sebagai
  // "Disyorkan"/"Terpantas"/"Terpendek" (ia hanya alternatif).
  final keptList = kept;
  // Masa berkesan menimbang kualiti jalan: laluan yang sedikit lebih laju tetapi melalui banyak jalan
  // kampung tidak "mengalahkan" laluan jalan utama yang lebih lama beberapa minit.
  double effectiveS(_Candidate c) =>
      c.route.durationS * (1 + c.route.roadPenalty);
  bool dominated(_Candidate c) => keptList.any(
    (o) =>
        o != c &&
        c.route.distanceM - o.route.distanceM >=
            o.route.distanceM * _dominanceMinRelative &&
        effectiveS(c) - effectiveS(o) >= effectiveS(o) * _dominanceMinRelative,
  );

  // Laluan utama: skor terbaik (masa + belokan + kos jarak) dalam tetingkap masa daripada yang terpantas.
  final window = kept
      .where(
        (c) =>
            c.route.durationS <=
                keptFastest.route.durationS * primaryTimeWindow &&
            !dominated(c),
      )
      .toList();
  final nearFastest = window.isEmpty ? [keptFastest] : window;
  var primary = nearFastest.reduce((best, c) {
    if (c.adjustedScore < best.adjustedScore - 0.5) return c;
    return best;
  });
  if (incumbent != null) {
    final held = nearFastest
        .where(
          (c) =>
              c != primary &&
              same.isSame(c.route, incumbent, routeDuplicateThreshold),
        )
        .firstOrNull;
    if (held != null &&
        primary.adjustedScore > held.adjustedScore - primaryStickinessS) {
      primary = held;
    }
  }

  final rest = kept.where((c) => c != primary).toList();
  final chosen = <_Candidate, RouteLabel>{primary: RouteLabel.recommended};

  // Terpantas, jika jelas lebih laju (>= 1 minit) daripada laluan utama.
  if (keptFastest != primary &&
      primary.route.durationS - keptFastest.route.durationS >= 60 &&
      !dominated(keptFastest)) {
    chosen[keptFastest] = RouteLabel.fastest;
  }

  // Terpendek diberi SEBELUM label khas lain supaya laluan jarak minimum tidak hilang labelnya.
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

  // "Tanpa lebuh raya" mesti benar: calon daripada permintaan itu DAN laluan sebenar tiada lebuh raya
  // (Valhalla hanya menganggap use_highways=0 sebagai keutamaan lembut).
  final noHighway = rest
      .where(
        (c) =>
            !chosen.containsKey(c) &&
            c.origin == RouteCandidateOrigin.noHighways &&
            !c.route.hasHighway,
      )
      .firstOrNull;
  if (noHighway != null) chosen[noHighway] = RouteLabel.noHighways;

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
