import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'place.dart';
import 'place_query_expand.dart';

/// Kategori dalam indeks carian offline (`tools/places/build_places.py`, medan `cat`).
abstract final class OfflinePlaceCat {
  static const settlement = 0;
  static const road = 1;
  static const fuel = 2;
  static const ev = 3;
  static const mosque = 4;
  static const toilets = 5;
  static const restArea = 6;
  static const hospital = 7;
  static const food = 8;
  static const parking = 15;
}

/// Satu baris indeks offline.
@immutable
class OfflinePlaceRow {
  const OfflinePlaceRow({
    required this.name,
    required this.kind,
    required this.cat,
    required this.point,
    required this.rank,
    this.alt,
    this.area,
  });

  final String name;
  final String? alt;
  final String kind;
  final int cat;
  final GeoPoint point;
  final String? area;

  /// Kepentingan (bandar 100 … tandas 15) daripada pembina.
  final int rank;

  static OfflinePlaceRow? fromRow(Map<String, Object?> r) {
    final lat = r['lat'];
    final lng = r['lng'];
    final name = r['name'];
    if (lat is! num || lng is! num || name is! String) return null;
    return OfflinePlaceRow(
      name: name,
      alt: r['alt'] as String?,
      kind: (r['kind'] as String?) ?? '',
      cat: (r['cat'] as num?)?.toInt() ?? 16,
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
      area: r['area'] as String?,
      rank: (r['rank'] as num?)?.toInt() ?? 0,
    );
  }

  /// Sebagai [Place] untuk UI carian/laluan. `category` dipetakan kepada jenis OSM yang ikon app kenal.
  Place toPlace() => Place(
    name: name,
    subtitle: area ?? '',
    point: point,
    category: switch (cat) {
      OfflinePlaceCat.fuel => 'fuel',
      OfflinePlaceCat.ev => 'charging_station',
      OfflinePlaceCat.mosque => 'mosque',
      OfflinePlaceCat.toilets => 'toilets',
      OfflinePlaceCat.restArea => 'services',
      OfflinePlaceCat.hospital => 'hospital',
      OfflinePlaceCat.food => 'restaurant',
      OfflinePlaceCat.parking => 'parking',
      _ => kind,
    },
    osmKey: switch (cat) {
      OfflinePlaceCat.settlement => 'place',
      OfflinePlaceCat.road || OfflinePlaceCat.restArea => 'highway',
      9 => 'shop', // OfflinePlaceCat shop dalam build_places.py
      _ => 'amenity',
    },
    countryCode: 'MY',
    fromOffline: true,
  );
}

/// Singkatan / pasangan MY–EN yang tokenizer `simple` FTS4 tidak kembangkan sendiri.
const _ftsTokenAliases = <String, List<String>>{
  'jln': ['jalan', 'jln'],
  'jalan': ['jalan', 'jln'],
  'tmn': ['taman', 'tmn'],
  'taman': ['taman', 'tmn'],
  'lrg': ['lorong', 'lrg'],
  'lorong': ['lorong', 'lrg'],
  'psn': ['persiaran', 'psn'],
  'persiaran': ['persiaran', 'psn'],
  'kg': ['kampung', 'kampong', 'kg'],
  'kampung': ['kampung', 'kampong', 'kg'],
  'kampong': ['kampung', 'kampong', 'kg'],
  'bt': ['bukit', 'bt'],
  'bukit': ['bukit', 'bt'],
  'stn': ['stesen', 'station', 'stn'],
  'stesen': ['stesen', 'station', 'stn'],
  'station': ['stesen', 'station', 'stn'],
  'hosp': ['hospital', 'hosp'],
  'hospital': ['hospital', 'hosp'],
  'uni': ['universiti', 'university', 'uni'],
  'universiti': ['universiti', 'university', 'uni'],
  'university': ['universiti', 'university', 'uni'],
  'masjid': ['masjid', 'mosque'],
  'mosque': ['masjid', 'mosque'],
  'surau': ['surau', 'prayer'],
  ...extraFtsTokenAliases,
};

/// Ungkapan MATCH FTS4 untuk teks pengguna: setiap perkataan sebagai awalan ("jalan amp" → semua
/// "jalan* amp*"), dengan OR untuk varian Melayu/Inggeris (jln/jalan, stesen/station). Aksara selain
/// huruf/nombor dibuang (tokenizer `simple` memisahkan pada aksara itu). Null jika tiada perkataan.
/// Landasan (KLCC, Pavilion, …) dikembangkan melalui [expandPlaceQuery] sebelum tokenisasi.
String? ftsMatchQuery(String text) {
  final source = expandPlaceQuery(text);
  final normalized = source
      .toLowerCase()
      .replaceAll(RegExp(r"['’`]"), '')
      .replaceAll('&', ' ');
  final tokens = normalized
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .take(6)
      .toList();
  if (tokens.isEmpty) return null;
  return tokens.map(_ftsTokenClause).join(' ');
}

String _ftsTokenClause(String token) {
  final variants = _ftsTokenAliases[token] ?? [token];
  // Awalan pada setiap varian: "amp" padan "ampang"; OR menyatukan singkatan.
  final clauses = [for (final v in variants) '$v*'];
  if (clauses.length == 1) return clauses.single;
  return '(${clauses.join(' OR ')})';
}

/// Susun hasil offline: padanan nama tepat/awalan, kepentingan, dan jarak dari [near]. Pendua (nama
/// sama dalam 300 m) dibuang.
List<OfflinePlaceRow> rankOfflinePlaces(
  List<OfflinePlaceRow> rows,
  String query, {
  GeoPoint? near,
  int limit = 40,
}) {
  final q = query.trim().toLowerCase();
  final qTokens = q
      .replaceAll(RegExp(r"['’`]"), '')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  double score(OfflinePlaceRow r) {
    final name = r.name.toLowerCase();
    var s = r.rank.toDouble();
    if (name == q) {
      s += 40;
    } else if (name.startsWith(q)) {
      s += 20;
    } else if (name.contains(q)) {
      s += 8;
    } else if (qTokens.isNotEmpty) {
      final nameTokens = name.split(RegExp(r'[^a-z0-9]+'));
      final hit = qTokens.every(
        (t) => nameTokens.any((n) => n.startsWith(t) || t.startsWith(n)),
      );
      if (hit) s += 14;
    }
    if (near != null) {
      final km = distanceMeters(near, r.point) / 1000;
      // POI berhampiran menang untuk navigasi; penempatan berperingkat tinggi masih relevan jauh.
      final distancePenalty = math.min(55.0, math.sqrt(km) * 4.5);
      final settlementBoost = r.cat == OfflinePlaceCat.settlement ? 8.0 : 0.0;
      s -= distancePenalty;
      s += settlementBoost * math.min(1.0, km / 40);
    }
    return s;
  }

  final scored = [for (final r in rows) (r, score(r))]
    ..sort((a, b) => b.$2.compareTo(a.$2));
  final out = <OfflinePlaceRow>[];
  for (final (r, _) in scored) {
    final dup = out.any(
      (o) =>
          o.name.toLowerCase() == r.name.toLowerCase() &&
          distanceMeters(o.point, r.point) < 300,
    );
    if (dup) continue;
    out.add(r);
    if (out.length >= limit) break;
  }
  return out;
}
