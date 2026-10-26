import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Satu hasil carian tempat.
@immutable
class Place {
  const Place({
    required this.name,
    required this.subtitle,
    required this.point,
    this.category,
  });

  /// Nama utama yang dipaparkan (nama tempat, atau jalan jika tiada nama).
  final String name;

  /// Butiran kedua: jalan, daerah, bandar, negeri.
  final String subtitle;
  final GeoPoint point;

  /// Jenis OSM mudah (cth. `fuel`, `restaurant`, `mosque`) untuk ikon; boleh null.
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.name == name &&
      other.subtitle == subtitle &&
      other.point == point;

  @override
  int get hashCode => Object.hash(name, subtitle, point);
}

enum GeocodeFailureKind { network, rateLimited, unavailable, generic }

class GeocodeFailure implements Exception {
  const GeocodeFailure(this.kind, [this.detail]);

  final GeocodeFailureKind kind;
  final String? detail;

  @override
  String toString() =>
      'GeocodeFailure($kind${detail == null ? '' : ': $detail'})';
}
