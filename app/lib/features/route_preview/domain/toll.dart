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
  });

  final int plazaCount;

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
  const _OpenPlaza(this.point, this.ratesRm);

  final GeoPoint point;
  final Map<String, double> ratesRm;
}

@immutable
class _ClosedPlaza {
  const _ClosedPlaza(this.name, this.point);

  final String name;

  /// Null jika plaza ini tidak dapat dipadankan dengan koordinat OSM semasa pembinaan dataset.
  final GeoPoint? point;
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
  const _Hit.closed(this.system, this.index) : openRate = null, isOpen = false;
  const _Hit.open(this.openRate) : system = -1, index = -1, isOpen = true;
  const _Hit.none() : system = -1, index = -1, openRate = null, isOpen = false;

  final int system;
  final int index;
  final double? openRate;
  final bool isOpen;

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

  bool get isEmpty => _open.isEmpty && _closed.isEmpty;

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
      out.add(_OpenPlaza(GeoPoint(lat.toDouble(), lng.toDouble()), parsed));
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
  TollEstimate estimate(List<TollPlaza> plazas, RouteVehicle vehicle) {
    final cls = tollClassOf(vehicle);
    if (cls == null) {
      // Kenderaan tanpa kelas dalam data: tiada harga (bukan percuma).
      return TollEstimate(
        plazaCount: plazas.length,
        unknownCount: plazas.length,
        knownRm: 0,
      );
    }
    final hits = [for (final p in plazas) _match(p.point, cls)];

    var known = 0.0;
    var unknown = 0;
    var i = 0;
    while (i < hits.length) {
      final h = hits[i];
      if (h.isOpen) {
        if (h.openRate == null) {
          unknown++;
        } else {
          known += h.openRate!;
        }
        i++;
      } else if (h.isClosed) {
        // Larian plaza berturutan pada sistem yang sama: pertama = masuk, terakhir = keluar.
        var j = i;
        while (j + 1 < hits.length &&
            hits[j + 1].isClosed &&
            hits[j + 1].system == h.system) {
          j++;
        }
        final count = j - i + 1;
        final fare = count < 2
            ? null
            : _closed[h.system].fare(h.index, hits[j].index);
        if (fare == null) {
          unknown += count;
        } else {
          known += fare;
        }
        i = j + 1;
      } else {
        unknown++;
        i++;
      }
    }
    return TollEstimate(
      plazaCount: plazas.length,
      unknownCount: unknown,
      knownRm: known,
    );
  }

  _Hit _match(GeoPoint point, String cls) {
    var best = matchRadiusM;
    _Hit? hit;
    for (var s = 0; s < _closed.length; s++) {
      final plazas = _closed[s].plazas;
      for (var k = 0; k < plazas.length; k++) {
        final p = plazas[k].point;
        if (p == null) continue;
        final d = distanceMeters(point, p);
        if (d <= best) {
          best = d;
          hit = _Hit.closed(s, k);
        }
      }
    }
    for (final p in _open) {
      final d = distanceMeters(point, p.point);
      if (d <= best) {
        best = d;
        hit = _Hit.open(p.ratesRm[cls]);
      }
    }
    return hit ?? const _Hit.none();
  }
}

/// Kunci stabil sebuah laluan untuk memadankan hasil kemudian (anggaran tol) dengan pilihan.
String routeKey(RouteOption r) =>
    '${r.durationS}:${r.distanceM}:${r.points.length}';

/// Mengelompokkan [nodes] yang berada dalam [toleranceM] daripada garis [route] kepada plaza,
/// disusun mengikut kedudukan sepanjang laluan. Palang/lorong yang berjarak <= [clusterGapM]
/// sepanjang laluan dikira satu plaza.
List<TollPlaza> matchTollPlazas(
  List<GeoPoint> route,
  List<({String id, GeoPoint point, String? name})> nodes, {
  double toleranceM = 40,
  double clusterGapM = 150,
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
    var bestD = toleranceM;
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
