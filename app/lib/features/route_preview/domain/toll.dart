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

/// Kelas kenderaan untuk kadar tol Malaysia: kereta = kelas 1, motosikal = kelas 4.
String tollClassOf(RouteVehicle vehicle) =>
    vehicle == RouteVehicle.motorcycle ? '4' : '1';

@immutable
class _RatedPlaza {
  const _RatedPlaza(this.point, this.ratesRm);

  final GeoPoint point;
  final Map<String, double> ratesRm;
}

/// Kadar tol yang disahkan (`assets/tolls/my_tolls.json`). Hanya plaza berharga tetap ("open") dengan
/// kadar bagi kelas kenderaan yang berkenaan dikira; sistem tertutup (masuk-keluar), plaza tiada dalam
/// fail, atau kelas tanpa kadar kekal "tidak diketahui". Tiada nilai tersirat: motosikal tidak dianggap
/// percuma.
class TollRates {
  const TollRates._(this._plazas, {this.lastVerified});

  static const empty = TollRates._([]);

  final List<_RatedPlaza> _plazas;
  final String? lastVerified;

  /// Jarak maksimum antara plaza OSM dan entri dataset untuk dianggap sama.
  static const matchRadiusM = 250.0;

  bool get isEmpty => _plazas.isEmpty;

  /// Menghurai fail kadar. Fail rosak atau versi tidak dikenali -> [empty] (tidak merosakkan app);
  /// entri tidak sah dilangkau satu-satu.
  static TollRates parse(String? json) {
    if (json == null) return empty;
    try {
      final root = jsonDecode(json);
      if (root is! Map<String, dynamic> || root['version'] != 1) return empty;
      final plazas = root['plazas'];
      if (plazas is! List) return empty;
      final out = <_RatedPlaza>[];
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
        out.add(_RatedPlaza(GeoPoint(lat.toDouble(), lng.toDouble()), parsed));
      }
      final verified = root['lastVerified'];
      return TollRates._(
        out,
        lastVerified: verified is String ? verified : null,
      );
    } on FormatException {
      return empty;
    }
  }

  /// Anggaran bagi [plazas] untuk [vehicle].
  TollEstimate estimate(List<TollPlaza> plazas, RouteVehicle vehicle) {
    final cls = tollClassOf(vehicle);
    var known = 0.0;
    var unknown = 0;
    for (final plaza in plazas) {
      final rate = _rateFor(plaza.point, cls);
      if (rate == null) {
        unknown++;
      } else {
        known += rate;
      }
    }
    return TollEstimate(
      plazaCount: plazas.length,
      unknownCount: unknown,
      knownRm: known,
    );
  }

  double? _rateFor(GeoPoint point, String cls) {
    _RatedPlaza? best;
    var bestD = matchRadiusM;
    for (final p in _plazas) {
      final d = distanceMeters(point, p.point);
      if (d <= bestD) {
        bestD = d;
        best = p;
      }
    }
    return best?.ratesRm[cls];
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
