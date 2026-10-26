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
    this.osmKey,
    this.osmType,
    this.osmId,
    this.extentDiagonalM,
    this.countryCode,
  });

  /// Nama utama yang dipaparkan (nama tempat, atau jalan jika tiada nama).
  final String name;

  /// Butiran kedua: jalan, daerah, bandar, negeri.
  final String subtitle;
  final GeoPoint point;

  /// Jenis OSM mudah (cth. `fuel`, `restaurant`, `mosque`) untuk ikon; boleh null.
  final String? category;

  /// Kunci OSM (cth. `amenity`, `shop`, `highway`, `public_transport`); membezakan kedai dengan
  /// perhentian bas yang bernama sama. Null bagi sejarah lama atau pautan kongsi.
  final String? osmKey;

  /// Jenis objek OSM: `N` (titik), `W` (garisan/bangunan), `R` (hubungan/kawasan).
  final String? osmType;
  final int? osmId;

  /// Panjang pepenjuru kotak sempadan (meter) bagi bangunan/kawasan; null untuk titik.
  final double? extentDiagonalM;

  /// Kod negara ISO (huruf besar), cth. `MY`.
  final String? countryCode;

  /// Bangunan atau kawasan (bukan titik tunggal): titik [point] ialah pusat, bukan pintu masuk.
  bool get isArea => osmType == 'W' || osmType == 'R';

  /// Jarak calon jalan (meter) untuk laluan ke tempat ini: separuh pepenjuru bangunan, dihadkan
  /// 15 hingga 60 m. Null untuk titik tunggal atau bangunan tanpa saiz diketahui.
  double? get routingRadiusM {
    final extent = extentDiagonalM;
    if (!isArea || extent == null) return null;
    return (extent / 2).clamp(15.0, 60.0);
  }

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
