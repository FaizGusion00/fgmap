import 'dart:math' as math;

import '../../../core/utils/geo.dart';

/// Koordinat Kaabah (Makkah) — rujukan kiblat piawai.
const kaaba = GeoPoint(21.422487, 39.826206);

/// Arah kiblat (darjah dari utara benar, 0–360) dari [from].
double qiblaBearingDegrees(GeoPoint from) => bearingDegrees(from, kaaba);

/// Sudut putar anak panah relatif kepada heading peranti (darjah).
///
/// [headingDegrees] ialah arah bahagian atas telefon (0 = utara). Null jika
/// heading tidak diketahui — UI papar arah mutlak dari utara sahaja.
double? qiblaRelativeDegrees(GeoPoint from, double? headingDegrees) {
  final qibla = qiblaBearingDegrees(from);
  if (headingDegrees == null) return null;
  var d = qibla - headingDegrees;
  while (d < 0) {
    d += 360;
  }
  while (d >= 360) {
    d -= 360;
  }
  return d;
}

/// Jarak ke Makkah (km), untuk paparan ringkas.
double qiblaDistanceKm(GeoPoint from) =>
    distanceMeters(from, kaaba) / 1000;

/// Normalisasi sudut ke julat −180…180 (ujian / animasi).
double normalizeDeltaDegrees(double degrees) {
  var d = degrees % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

/// Sin/cos untuk lukisan (ujian tidak bergantung Flutter).
(double sin, double cos) qiblaUnit(double degrees) {
  final r = degrees * math.pi / 180;
  return (math.sin(r), math.cos(r));
}
