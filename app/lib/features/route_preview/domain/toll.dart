import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'route_option.dart';

/// Satu plaza tol yang dikesan pada laluan (kelompok palang/lorong OSM yang berdekatan).
@immutable
class TollPlaza {
  const TollPlaza({
    required this.id,
    required this.point,
    required this.alongM,
    this.name,
  });

  /// ID nod OSM pertama dalam kelompok.
  final String id;
  final GeoPoint point;

  /// Kedudukan sepanjang laluan (meter dari permulaan).
  final double alongM;
  final String? name;
}

/// Anggaran tol satu laluan. Harga hanya daripada plaza yang ada dalam dataset yang disahkan.
@immutable
class TollEstimate {
  const TollEstimate({
    required this.plazaCount,
    required this.unknownCount,
    required this.knownRm,
    this.reportedCount = 0,
  });

  final int plazaCount;

  /// Plaza berharga yang kadarnya daripada laporan berita (`basis: "reported"`), bukan jadual rasmi.
  final int reportedCount;

  /// Plaza yang tiada harga disahkan.
  final int unknownCount;

  /// Jumlah harga plaza yang diketahui (RM). 0 jika tiada.
  final double knownRm;

  /// Semua plaza ada harga: jumlah tepat (mengikut dataset).
  bool get isExact => plazaCount > 0 && unknownCount == 0;

  /// Sebahagian plaza ada harga: jumlah ialah had bawah ("RM x+").
  bool get isPartial => unknownCount > 0 && unknownCount < plazaCount;

  /// Tiada harga langsung.
  bool get isUnknown => plazaCount > 0 && unknownCount == plazaCount;
}

/// Kelas kenderaan dalam kalkulator rasmi LLM (`transCode`): 1 = kereta, 2 = van/lori kecil, 3 = lori
/// besar, 4 = teksi, 5 = bas. (Disahkan daripada data: kelas 4 = 50% dan kelas 5 = 75% daripada kelas 1.)
/// LLM TIADA kelas motosikal (motosikal bebas tol di kebanyakan lebuh raya, tidak di semua), jadi
/// motosikal dipulangkan null: harga TIDAK diketahui, bukan kelas lain dan bukan percuma.
String? tollClassOf(RouteVehicle vehicle) =>
    vehicle == RouteVehicle.motorcycle ? null : '1';

@immutable
class _OpenPlaza {
  const _OpenPlaza(
    this.point,
    this.ratesRm, {
    this.reported = false,
    this.booths = const [],
    this.boothsOnWay = false,
  });

  final GeoPoint point;

  /// Titik booth OSM sebenar (kosong = data lama, hanya [point]).
  final List<GeoPoint> booths;

  /// Semua [booths] ialah nod jalan OSM: dipadankan dengan [TollRates.onWayToleranceM].
  final bool boothsOnWay;
  final Map<String, double> ratesRm;

  /// Kadar daripada laporan (berita), bukan jadual rasmi pengendali.
  final bool reported;
}

@immutable
class _ClosedPlaza {
  const _ClosedPlaza(
    this.name,
    this.point, {
    this.booths = const [],
    this.boothsOnWay = false,
  });

  final String name;

  /// Null jika plaza ini tidak dapat dipadankan dengan koordinat OSM semasa pembinaan dataset.
  final GeoPoint? point;

  /// Titik booth OSM sebenar. Plaza persimpangan ada booth di kedua-dua belah lebuh raya; purata [point]
  /// boleh jatuh di atas laluan utama, jadi padanan menggunakan booth bila ada.
  final List<GeoPoint> booths;

  /// Semua [booths] ialah nod jalan OSM: dipadankan dengan [TollRates.onWayToleranceM].
  final bool boothsOnWay;
}

/// Titik padanan sebuah plaza: booth sebenar, atau [point] bagi data lama.
List<GeoPoint> _matchPoints(GeoPoint point, List<GeoPoint> booths) =>
    booths.isEmpty ? [point] : booths;

/// `booths: [[lat, lng], ...]` -> titik sah dalam Malaysia; entri rosak dilangkau.
List<GeoPoint> _parseBooths(Object? raw) {
  if (raw is! List) return const [];
  final out = <GeoPoint>[];
  for (final b in raw) {
    if (b is! List || b.length < 2) continue;
    final lat = b[0];
    final lng = b[1];
    if (lat is! num || lng is! num) continue;
    if (lat < 0.8 || lat > 7.5 || lng < 99 || lng > 120) continue;
    out.add(GeoPoint(lat.toDouble(), lng.toDouble()));
  }
  return out;
}

/// Sistem tol tertutup (tiket masuk, bayar keluar): kadar bergantung pada PASANGAN plaza masuk dan keluar.
/// [matrix] ialah jadual N x N kadar kelas 1 (RM) mengikut indeks [plazas]; null = tiada laluan.
class _ClosedSystem {
  const _ClosedSystem(this.id, this.name, this.plazas, this.matrix);

  final String id;
  final String name;
  final List<_ClosedPlaza> plazas;
  final List<double?> matrix;

  double? fare(int entry, int exit) => matrix[entry * plazas.length + exit];
}

/// Hasil padanan satu plaza laluan dengan dataset.
@immutable
class _Hit {
  const _Hit.closed(this.system, this.index)
    : openRate = null,
      isOpen = false,
      reported = false;
  const _Hit.open(this.openRate, {this.reported = false})
    : system = -1,
      index = -1,
      isOpen = true;

  final int system;
  final int index;
  final double? openRate;
  final bool isOpen;
  final bool reported;

  bool get isClosed => system >= 0;
}

/// Kadar tol yang disahkan (`assets/tolls/my_tolls.json`).
///
/// Dua jenis:
///  - **tertutup** (versi 2, PLUS/LPT/WCE dsb.): matriks kadar kelas 1 bagi setiap pasangan masuk-keluar,
///    daripada kalkulator rasmi LLM. Dalam satu larian plaza berturutan pada sistem yang sama, plaza
///    pertama = masuk dan plaza terakhir = keluar.
///  - **harga tetap** ("open"): satu kadar setiap plaza; `source` dan `verifiedOn` wajib setiap entri.
///
/// Plaza yang tidak dipadankan, pasangan tanpa kadar, atau kenderaan tanpa kelas (motosikal) kekal "tidak
/// diketahui". Tiada nilai tersirat.
class TollRates {
  const TollRates._(this._open, this._closed, {this.lastVerified, this.source});

  static const empty = TollRates._([], []);

  final List<_OpenPlaza> _open;
  final List<_ClosedSystem> _closed;

  /// Tarikh data terakhir diambil/disahkan, dan sumbernya (untuk dipaparkan).
  final String? lastVerified;
  final String? source;

  /// Jarak maksimum antara plaza OSM dan entri dataset untuk dianggap sama.
  static const matchRadiusM = 250.0;

  /// Toleransi garisan laluan ke titik BOOTH sebenar: laluan melalui lorong booth, jadi jaraknya kecil.
  /// Laluan utama yang lalu di sebelah plaza susur (biasanya > 30 m) tidak dikira.
  static const boothToleranceM = 25.0;

  /// Toleransi bagi booth yang ialah nod jalan OSM. Garisan laluan Valhalla mengikut geometri jalan yang
  /// sama dan melalui nod itu (< 1 m); laluan utama yang lalu 10-20 m di sebelah booth susur (cth. SPE di
  /// Setiawangsa) tidak dikira.
  static const onWayToleranceM = 6.0;

  bool get isEmpty => _open.isEmpty && _closed.isEmpty;

  /// Semua plaza berkoordinat dalam dataset (tertutup + harga tetap), untuk dipadankan terus ke garisan
  /// laluan tanpa pertanyaan rangkaian.
  ///
  /// Plaza yang ada booth: satu nod bagi setiap booth (id sama; dikelompokkan semula oleh
  /// [matchTollPlazas]); toleransinya dalam [plazaTolerances]. Data lama: titik plaza sahaja.
  List<({String id, GeoPoint point, String? name})> get plazaNodes => [
    for (final sys in _closed)
      for (var k = 0; k < sys.plazas.length; k++)
        if (sys.plazas[k].point != null)
          for (final p in _matchPoints(
            sys.plazas[k].point!,
            sys.plazas[k].booths,
          ))
            (id: '${sys.id}:$k', point: p, name: sys.plazas[k].name),
    for (var i = 0; i < _open.length; i++)
      for (final p in _matchPoints(_open[i].point, _open[i].booths))
        (id: 'open:$i', point: p, name: null),
  ];

  /// Toleransi padanan bagi nod [plazaNodes] yang ialah booth sebenar ([boothToleranceM]).
  Map<String, double> get plazaTolerances => {
    for (final sys in _closed)
      for (var k = 0; k < sys.plazas.length; k++)
        if (sys.plazas[k].booths.isNotEmpty)
          '${sys.id}:$k': sys.plazas[k].boothsOnWay
              ? onWayToleranceM
              : boothToleranceM,
    for (var i = 0; i < _open.length; i++)
      if (_open[i].booths.isNotEmpty)
        'open:$i': _open[i].boothsOnWay ? onWayToleranceM : boothToleranceM,
  };

  /// Menghurai fail kadar. Fail rosak atau versi tidak dikenali -> [empty] (tidak merosakkan app);
  /// entri tidak sah dilangkau satu-satu. Versi 1: hanya `plazas` harga tetap. Versi 2: `closed` + `open`.
  static TollRates parse(String? json) {
    if (json == null) return empty;
    try {
      final root = jsonDecode(json);
      if (root is! Map<String, dynamic>) return empty;
      final version = root['version'];
      if (version != 1 && version != 2) return empty;
      final open = _parseOpen(version == 1 ? root['plazas'] : root['open']);
      final closed = version == 2
          ? _parseClosed(root['closed'])
          : const <_ClosedSystem>[];
      final verified = root['lastVerified'];
      final source = root['source'];
      return TollRates._(
        open,
        closed,
        lastVerified: verified is String ? verified : null,
        source: source is String ? source : null,
      );
    } on FormatException {
      return empty;
    }
  }

  static List<_OpenPlaza> _parseOpen(Object? plazas) {
    if (plazas is! List) return const [];
    final out = <_OpenPlaza>[];
    for (final p in plazas) {
      if (p is! Map<String, dynamic>) continue;
      final lat = p['lat'];
      final lng = p['lng'];
      final rates = p['ratesRm'];
      if (p['type'] != 'open' ||
          lat is! num ||
          lng is! num ||
          rates is! Map<String, dynamic> ||
          // Sumber dan tarikh pengesahan wajib: entri tanpa jejak tidak dipercayai.
          p['source'] is! String ||
          p['verifiedOn'] is! String) {
        continue;
      }
      final parsed = <String, double>{};
      rates.forEach((k, v) {
        if (v is num && v >= 0 && v.isFinite) parsed[k] = v.toDouble();
      });
      if (parsed.isEmpty) continue;
      out.add(
        _OpenPlaza(
          GeoPoint(lat.toDouble(), lng.toDouble()),
          parsed,
          reported: p['basis'] == 'reported',
          booths: _parseBooths(p['booths']),
          boothsOnWay: p['boothsOnWay'] == true,
        ),
      );
    }
    return out;
  }

  static List<_ClosedSystem> _parseClosed(Object? systems) {
    if (systems is! List) return const [];
    final out = <_ClosedSystem>[];
    for (final sys in systems) {
      if (sys is! Map<String, dynamic>) continue;
      final id = sys['id'];
      final name = sys['name'];
      final plazas = sys['plazas'];
      final matrix = sys['matrix'];
      if (id is! String ||
          name is! String ||
          plazas is! List ||
          matrix is! List) {
        continue;
      }
      final parsedPlazas = <_ClosedPlaza>[];
      var valid = true;
      for (final p in plazas) {
        if (p is! Map<String, dynamic> || p['name'] is! String) {
          valid = false;
          break;
        }
        final lat = p['lat'];
        final lng = p['lng'];
        final inMalaysia =
            lat is num &&
            lng is num &&
            lat >= 0.8 &&
            lat <= 7.5 &&
            lng >= 99 &&
            lng <= 120;
        parsedPlazas.add(
          _ClosedPlaza(
            p['name'] as String,
            inMalaysia ? GeoPoint(lat.toDouble(), lng.toDouble()) : null,
            booths: inMalaysia ? _parseBooths(p['booths']) : const [],
            boothsOnWay: inMalaysia && p['boothsOnWay'] == true,
          ),
        );
      }
      final n = parsedPlazas.length;
      // Matriks mesti tepat N x N; jika tidak, sistem ini tidak dipercayai.
      if (!valid || n == 0 || matrix.length != n * n) continue;
      final cells = <double?>[
        for (final v in matrix)
          v is num && v.isFinite && v > 0 ? v.toDouble() : null,
      ];
      out.add(_ClosedSystem(id, name, parsedPlazas, cells));
    }
    return out;
  }

  /// Anggaran bagi [plazas] (mengikut susunan perjalanan) untuk [vehicle].
  ///
  /// Dengan [route], larian sistem tertutup dipecah di tempat laluan KELUAR dari jalan bertol
  /// (>= [freeGapM] manuver tanpa tol di antara dua plaza): keluar di Jalan Duta, merentas KL di jalan
  /// percuma dan masuk semula di Sungai Besi ialah dua perjalanan, bukan satu tiket Rawang-Kajang.
  TollEstimate estimate(
    List<TollPlaza> plazas,
    RouteVehicle vehicle, {
    RouteOption? route,
  }) {
    final cls = tollClassOf(vehicle);
    if (cls == null) {
      // Kenderaan tanpa kelas dalam data: tiada harga (bukan percuma).
      return TollEstimate(
        plazaCount: plazas.length,
        unknownCount: plazas.length,
        knownRm: 0,
      );
    }
    final cands = [for (final p in plazas) _candidates(p.point, cls)];
    final freeBetween = route == null ? null : _freeMetres(route);
    final spans = route == null ? null : _tollSpans(route);

    var known = 0.0;
    var unknown = 0;
    var reported = 0;
    var i = 0;
    while (i < cands.length) {
      final c = cands[i];
      if (c.isEmpty) {
        unknown++;
        i++;
        continue;
      }
      if (c.first.isOpen) {
        final rate = c.first.openRate;
        if (rate == null) {
          unknown++;
        } else {
          known += rate;
          if (c.first.reported) reported++;
        }
        i++;
        continue;
      }
      // Larian plaza berturutan pada sistem tertutup yang sama. Pilih sistem yang memberi larian
      // terpanjang (plaza dikongsi dua sistem, cth. SKVE/WCE, atau kembar (U)/(S) pada titik sama).
      var bestSystem = -1;
      var bestEnd = i;
      for (final s in {
        for (final h in c)
          if (h.isClosed) h.system,
      }) {
        var j = i;
        while (j + 1 < cands.length &&
            cands[j + 1].any((h) => h.isClosed && h.system == s)) {
          j++;
        }
        if (j > bestEnd || bestSystem < 0) {
          bestSystem = s;
          bestEnd = j;
        }
      }
      final sys = _closed[bestSystem];
      List<int> indices(int k) => [
        for (final h in cands[k])
          if (h.isClosed && h.system == bestSystem) h.index,
      ];
      // Dalam satu perjalanan: plaza pertama = masuk, terakhir = keluar (plaza di tengah, cth. susur
      // yang hampir dengan laluan utama, diabaikan).
      void trip(int from, int to) {
        // Masuk atau keluar sebenar tidak dikesan (jalan bertol berterusan jauh melepasi plaza pertama/
        // terakhir tanpa plaza lain): harga pasangan yang dikesan akan terlalu rendah. Tidak diketahui.
        if (spans != null && _missesEnds(plazas, from, to, spans)) {
          unknown += to - from + 1;
          return;
        }
        // Satu plaza sahaja: tiada pasangan masuk-keluar. (Pepenjuru matriks bukan kadar yang boleh
        // dipercayai: data sumber lama mengandungi nilai pasangan lain di situ.)
        if (from == to) {
          unknown++;
          return;
        }
        double? fare;
        for (final a in indices(from)) {
          for (final b in indices(to)) {
            final f = sys.fare(a, b);
            if (f != null && (fare == null || f < fare)) fare = f;
          }
        }
        if (fare == null) {
          unknown += to - from + 1;
        } else {
          known += fare;
        }
      }

      var tripStart = i;
      for (var k = i; k < bestEnd; k++) {
        final left =
            freeBetween != null &&
            freeBetween(plazas[k].alongM, plazas[k + 1].alongM) >= freeGapM;
        if (left) {
          trip(tripStart, k);
          tripStart = k + 1;
        }
      }
      trip(tripStart, bestEnd);
      i = bestEnd + 1;
    }
    return TollEstimate(
      plazaCount: plazas.length,
      unknownCount: unknown,
      knownRm: known,
      reportedCount: reported,
    );
  }

  /// Jarak manuver tanpa tol di antara dua plaza yang menandakan laluan keluar dari sistem tertutup.
  /// Bukan lebih kecil: tag tol OSM selalunya bermula selepas plaza susur (Setia Alam: ~1 km jalan
  /// "tanpa tol" antara plaza dan NKVE), dan itu bukan keluar-masuk semula.
  static const freeGapM = 2500.0;

  /// Jalan bertol sejauh ini sebelum plaza masuk (atau selepas plaza keluar) tanpa plaza lain bermaksud
  /// plaza masuk/keluar sebenar tidak dikesan.
  static const missedEndM = 15000.0;

  /// Rentang jalan bertol (meter sepanjang laluan) daripada manuver `toll`; jurang tanpa tol < [freeGapM]
  /// dicantum (tag tol OSM yang terputus seketika).
  static List<(double, double)> _tollSpans(RouteOption route) {
    final pts = route.points;
    final along = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      along.add(along.last + distanceMeters(pts[i - 1], pts[i]));
    }
    double at(int shape) =>
        along.isEmpty ? 0 : along[shape.clamp(0, along.length - 1)];
    final out = <(double, double)>[];
    final ms = route.maneuvers;
    for (var i = 0; i < ms.length; i++) {
      if (!ms[i].toll) continue;
      final start = at(ms[i].beginShapeIndex);
      final end = i + 1 < ms.length
          ? at(ms[i + 1].beginShapeIndex)
          : (along.isEmpty ? 0.0 : along.last);
      if (end <= start) continue;
      if (out.isNotEmpty && start - out.last.$2 < freeGapM) {
        out[out.length - 1] = (out.last.$1, end);
      } else {
        out.add((start, end));
      }
    }
    return out;
  }

  /// Benar jika rentang bertol yang mengandungi perjalanan [from]..[to] berterusan lebih [missedEndM]
  /// sebelum [from] atau selepas [to] tanpa sebarang plaza lain yang dikesan di situ.
  static bool _missesEnds(
    List<TollPlaza> plazas,
    int from,
    int to,
    List<(double, double)> spans,
  ) {
    const slack = 300.0;
    final a = plazas[from].alongM;
    final b = plazas[to].alongM;
    for (final (start, end) in spans) {
      if (a < start - slack || a > end + slack) continue;
      final lead = a - start;
      if (lead > missedEndM &&
          !plazas
              .take(from)
              .any((p) => p.alongM >= start - slack && p.alongM < a)) {
        return true;
      }
      break;
    }
    for (final (start, end) in spans) {
      if (b < start - slack || b > end + slack) continue;
      final tail = end - b;
      if (tail > missedEndM &&
          !plazas
              .skip(to + 1)
              .any((p) => p.alongM > b && p.alongM <= end + slack)) {
        return true;
      }
      break;
    }
    return false;
  }

  /// Fungsi: meter jalan TANPA tol di antara dua kedudukan sepanjang [route].
  static double Function(double, double) _freeMetres(RouteOption route) {
    final pts = route.points;
    final along = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      along.add(along.last + distanceMeters(pts[i - 1], pts[i]));
    }
    double at(int shape) =>
        along.isEmpty ? 0 : along[shape.clamp(0, along.length - 1)];
    final spans = <(double, double)>[];
    final ms = route.maneuvers;
    for (var i = 0; i < ms.length; i++) {
      if (ms[i].toll) continue;
      final start = at(ms[i].beginShapeIndex);
      final end = i + 1 < ms.length
          ? at(ms[i + 1].beginShapeIndex)
          : (along.isEmpty ? 0.0 : along.last);
      if (end > start) spans.add((start, end));
    }
    return (a, b) {
      final lo = a < b ? a : b, hi = a < b ? b : a;
      var sum = 0.0;
      for (final (s, e) in spans) {
        final o = (e < hi ? e : hi) - (s > lo ? s : lo);
        if (o > 0) sum += o;
      }
      return sum;
    };
  }

  static double _nearest(GeoPoint p, List<GeoPoint> points) {
    var best = double.infinity;
    for (final q in points) {
      final d = distanceMeters(p, q);
      if (d < best) best = d;
    }
    return best;
  }

  /// Semua padanan dataset bagi satu plaza laluan, terdekat dahulu. Calon dalam 5 m daripada yang
  /// terdekat dikekalkan bersama (plaza kembar arah (U)/(S) pada koordinat sama, plaza dikongsi dua
  /// sistem): pemilihan akhir dibuat oleh pasangan yang benar-benar ada kadar.
  List<_Hit> _candidates(GeoPoint point, String cls) {
    final found = <(double, _Hit)>[];
    for (var s = 0; s < _closed.length; s++) {
      final plazas = _closed[s].plazas;
      for (var k = 0; k < plazas.length; k++) {
        final p = plazas[k].point;
        if (p == null) continue;
        final d = _nearest(point, _matchPoints(p, plazas[k].booths));
        if (d <= matchRadiusM) found.add((d, _Hit.closed(s, k)));
      }
    }
    for (final p in _open) {
      final d = _nearest(point, _matchPoints(p.point, p.booths));
      if (d <= matchRadiusM) {
        found.add((d, _Hit.open(p.ratesRm[cls], reported: p.reported)));
      }
    }
    if (found.isEmpty) return const [];
    // Seri jarak: harga tetap dahulu (seperti sebelum ini), kemudian tertutup.
    found.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      return (b.$2.isOpen ? 1 : 0) - (a.$2.isOpen ? 1 : 0);
    });
    final nearest = found.first.$1;
    return [
      for (final (d, h) in found)
        if (d <= nearest + 5) h,
    ];
  }
}

/// Kunci stabil sebuah laluan untuk memadankan hasil kemudian (anggaran tol) dengan pilihan.
String routeKey(RouteOption r) =>
    '${r.durationS}:${r.distanceM}:${r.points.length}';

/// Mengelompokkan [nodes] yang berada dalam [toleranceM] daripada garis [route] kepada plaza,
/// disusun mengikut kedudukan sepanjang laluan. Palang/lorong yang berjarak <= [clusterGapM]
/// sepanjang laluan dikira satu plaza. [toleranceById] menggantikan [toleranceM] bagi nod tertentu (booth
/// sebenar dataset, yang dipadankan lebih ketat).
List<TollPlaza> matchTollPlazas(
  List<GeoPoint> route,
  List<({String id, GeoPoint point, String? name})> nodes, {
  double toleranceM = 40,
  double clusterGapM = 150,
  Map<String, double> toleranceById = const {},
}) {
  if (route.length < 2 || nodes.isEmpty) return const [];
  final along = <double>[0];
  for (var i = 1; i < route.length; i++) {
    along.add(along.last + distanceMeters(route[i - 1], route[i]));
  }
  final slack = toleranceM / 111000 * 1.5;

  final hits = <({String id, GeoPoint point, String? name, double alongM})>[];
  for (final n in nodes) {
    double? bestAlong;
    var bestD = toleranceById[n.id] ?? toleranceM;
    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];
      if (n.point.lat > (a.lat > b.lat ? a.lat : b.lat) + slack ||
          n.point.lat < (a.lat < b.lat ? a.lat : b.lat) - slack) {
        continue;
      }
      final proj = projectToSegment(n.point, a, b);
      if (proj.distanceM <= bestD) {
        bestD = proj.distanceM;
        bestAlong = along[i] + proj.t * (along[i + 1] - along[i]);
      }
    }
    if (bestAlong != null) {
      hits.add((id: n.id, point: n.point, name: n.name, alongM: bestAlong));
    }
  }
  hits.sort((a, b) => a.alongM.compareTo(b.alongM));

  final out = <TollPlaza>[];
  var group = <({String id, GeoPoint point, String? name, double alongM})>[];
  void flush() {
    if (group.isEmpty) return;
    final lat =
        group.map((g) => g.point.lat).reduce((a, b) => a + b) / group.length;
    final lng =
        group.map((g) => g.point.lng).reduce((a, b) => a + b) / group.length;
    out.add(
      TollPlaza(
        id: group.first.id,
        point: GeoPoint(lat, lng),
        alongM: group.first.alongM,
        name: group.map((g) => g.name).whereType<String>().firstOrNull,
      ),
    );
    group = [];
  }

  for (final h in hits) {
    if (group.isNotEmpty && h.alongM - group.last.alongM > clusterGapM) flush();
    group.add(h);
  }
  flush();
  return out;
}
