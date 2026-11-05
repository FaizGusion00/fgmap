import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Jenis pintu masuk, mengikut keutamaan paparan.
enum EntranceKind {
  /// Disimpan oleh pengguna sendiri (paling dipercayai).
  saved,

  /// `entrance=main`.
  main,

  /// Pondok pengawal / pintu pelawat (`building=guardhouse`, pagar bernama "guard"/"pelawat").
  visitor,

  /// `amenity=parking_entrance` atau `entrance=garage`.
  parking,

  /// Pagar / palang masuk kawasan.
  gate,

  /// `amenity=loading_dock` atau pintu servis bernama "loading".
  loading,

  /// `entrance=service`.
  service,

  /// Pintu bangunan lain (`entrance=yes/home/secondary`), biasanya dengan blok atau nombor.
  door,
}

/// Satu pintu masuk berhampiran destinasi.
@immutable
class Entrance {
  const Entrance({
    required this.point,
    required this.kind,
    this.detail,
    this.onBuilding = false,
    this.distanceM = 0,
  });

  final GeoPoint point;
  final EntranceKind kind;

  /// Blok, tower, nombor pintu atau nama (cth. "Blok A", "Pintu 3"); null jika tiada.
  final String? detail;

  /// Pintu pada garis luar bangunan destinasi itu sendiri (bukan bangunan jiran).
  final bool onBuilding;

  /// Jarak dari pin destinasi.
  final double distanceM;

  Entrance copyWith({double? distanceM, bool? onBuilding}) => Entrance(
    point: point,
    kind: kind,
    detail: detail,
    onBuilding: onBuilding ?? this.onBuilding,
    distanceM: distanceM ?? this.distanceM,
  );

  @override
  bool operator ==(Object other) =>
      other is Entrance &&
      other.point == point &&
      other.kind == kind &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(point, kind, detail);
}

final _visitorWords = RegExp(
  r'guard|pengawal|security|keselamatan|visitor|pelawat|main gate|pintu utama|reception',
  caseSensitive: false,
);
final _loadingWords = RegExp(
  r'loading|muat|delivery|penghantaran',
  caseSensitive: false,
);

/// Jenis pintu daripada tag OSM, atau null jika bukan pintu masuk yang berguna untuk kenderaan/pelawat
/// (kecemasan, keluar sahaja, tangga dalaman, dilarang).
EntranceKind? classifyEntrance(Map<String, String> tags) {
  final access = tags['access'];
  if (access == 'no') return null;
  final text = [
    tags['name'],
    tags['description'],
    tags['ref'],
  ].whereType<String>().join(' ');
  if (tags['amenity'] == 'parking_entrance') return EntranceKind.parking;
  if (tags['amenity'] == 'loading_dock') return EntranceKind.loading;
  if (tags['building'] == 'guardhouse') return EntranceKind.visitor;
  final entrance = tags['entrance'];
  if (entrance != null) {
    return switch (entrance) {
      'main' => EntranceKind.main,
      'service' =>
        _loadingWords.hasMatch(text)
            ? EntranceKind.loading
            : EntranceKind.service,
      'garage' => EntranceKind.parking,
      'emergency' || 'exit' || 'no' || 'staircase' => null,
      _ => EntranceKind.door,
    };
  }
  final barrier = tags['barrier'];
  if (barrier != null) {
    if (tags['emergency'] == 'yes') return null;
    return _visitorWords.hasMatch(text)
        ? EntranceKind.visitor
        : EntranceKind.gate;
  }
  return null;
}

/// "Blok A", "Pintu 3", "Menara 2" daripada tag; null jika tiada label berguna.
String? entranceDetail(Map<String, String> tags) {
  final parts = <String>[];
  for (final key in ['name', 'ref', 'addr:unit', 'addr:housenumber']) {
    final v = tags[key]?.trim();
    if (v == null || v.isEmpty) continue;
    if (parts.any((p) => p.toLowerCase() == v.toLowerCase())) continue;
    parts.add(v);
    if (parts.length == 2) break;
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Senarai pintu untuk dipaparkan: pintu bangunan destinasi dahulu, kemudian mengikut jarak; pendua
/// (< 8 m, jenis sama) dibuang; paling banyak [perKind] bagi setiap jenis dan [max] semuanya.
List<Entrance> rankEntrances(
  List<Entrance> all,
  GeoPoint place, {
  int perKind = 2,
  int max = 8,
}) {
  final withDistance =
      [
        for (final e in all)
          e.copyWith(distanceM: distanceMeters(place, e.point)),
      ]..sort((a, b) {
        if (a.onBuilding != b.onBuilding) return a.onBuilding ? -1 : 1;
        return a.distanceM.compareTo(b.distanceM);
      });
  final out = <Entrance>[];
  final counts = <EntranceKind, int>{};
  for (final e in withDistance) {
    if (out.length >= max) break;
    if (out.any(
      (o) => o.kind == e.kind && distanceMeters(o.point, e.point) < 8,
    )) {
      continue;
    }
    final n = counts[e.kind] ?? 0;
    if (n >= perKind) continue;
    counts[e.kind] = n + 1;
    out.add(e);
  }
  return out;
}
