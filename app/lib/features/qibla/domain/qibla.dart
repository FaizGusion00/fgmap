import 'dart:math' as math;

import '../../../core/utils/geo.dart';

/// Koordinat Kaabah (Makkah) — rujukan kiblat piawai.
const kaaba = GeoPoint(21.422487, 39.826206);

const _deg = math.pi / 180;

/// Hasil masalah songsang geodesik pada elipsoid WGS84.
typedef Geodesic = ({double distanceM, double initialBearingDeg});

/// Jarak dan azimut awal geodesik dari [a] ke [b] pada elipsoid WGS84 (formula songsang Vincenty).
///
/// Bumi bukan sfera: formula bulatan besar sfera boleh tersasar sehingga ~0.2° berbanding geodesik
/// sebenar pada jarak Malaysia–Makkah. Jika lelaran tidak menumpu (titik hampir antipod), jatuh
/// semula kepada bulatan besar sfera.
Geodesic geodesicInverse(GeoPoint a, GeoPoint b) {
  const eqR = 6378137.0;
  const f = 1 / 298.257223563;
  const polR = eqR * (1 - f);

  final l = (b.lng - a.lng) * _deg;
  final u1 = math.atan((1 - f) * math.tan(a.lat * _deg));
  final u2 = math.atan((1 - f) * math.tan(b.lat * _deg));
  final sinU1 = math.sin(u1), cosU1 = math.cos(u1);
  final sinU2 = math.sin(u2), cosU2 = math.cos(u2);

  var lambda = l;
  double sinSigma = 0, cosSigma = 0, sigma = 0, cos2Alpha = 0, cos2SigmaM = 0;
  var converged = false;
  for (var i = 0; i < 200; i++) {
    final sinL = math.sin(lambda), cosL = math.cos(lambda);
    sinSigma = math.sqrt(
      math.pow(cosU2 * sinL, 2) +
          math.pow(cosU1 * sinU2 - sinU1 * cosU2 * cosL, 2),
    );
    if (sinSigma == 0) return (distanceM: 0, initialBearingDeg: 0);
    cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosL;
    sigma = math.atan2(sinSigma, cosSigma);
    final sinAlpha = cosU1 * cosU2 * sinL / sinSigma;
    cos2Alpha = 1 - sinAlpha * sinAlpha;
    cos2SigmaM = cos2Alpha == 0 ? 0 : cosSigma - 2 * sinU1 * sinU2 / cos2Alpha;
    final c = f / 16 * cos2Alpha * (4 + f * (4 - 3 * cos2Alpha));
    final prev = lambda;
    lambda =
        l +
        (1 - c) *
            f *
            sinAlpha *
            (sigma +
                c *
                    sinSigma *
                    (cos2SigmaM +
                        c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
    if ((lambda - prev).abs() < 1e-12) {
      converged = true;
      break;
    }
  }
  if (!converged) {
    return (
      distanceM: distanceMeters(a, b),
      initialBearingDeg: bearingDegrees(a, b),
    );
  }

  final uSq = cos2Alpha * (eqR * eqR - polR * polR) / (polR * polR);
  final bigA =
      1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
  final bigB = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));
  final deltaSigma =
      bigB *
      sinSigma *
      (cos2SigmaM +
          bigB /
              4 *
              (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
                  bigB /
                      6 *
                      cos2SigmaM *
                      (-3 + 4 * sinSigma * sinSigma) *
                      (-3 + 4 * cos2SigmaM * cos2SigmaM)));
  final s = polR * bigA * (sigma - deltaSigma);
  final alpha1 = math.atan2(
    cosU2 * math.sin(lambda),
    cosU1 * sinU2 - sinU1 * cosU2 * math.cos(lambda),
  );
  return (distanceM: s, initialBearingDeg: normalizeBearing(alpha1 / _deg));
}

/// Arah kiblat (darjah dari utara benar, 0–360) dari [from], mengikut geodesik WGS84.
double qiblaBearingDegrees(GeoPoint from) =>
    geodesicInverse(from, kaaba).initialBearingDeg;

/// Sudut putar anak panah relatif kepada heading peranti (darjah, 0–360).
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

/// Jarak ke Makkah (km) sepanjang geodesik, untuk paparan ringkas.
double qiblaDistanceKm(GeoPoint from) =>
    geodesicInverse(from, kaaba).distanceM / 1000;

/// Normalisasi sudut ke julat −180…180 (ujian / animasi).
double normalizeDeltaDegrees(double degrees) {
  var d = degrees % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

/// Berapa darjah perlu diputar supaya menghadap kiblat: positif = ke kanan (ikut jam), negatif = ke
/// kiri. Sentiasa laluan terpendek (−180…180).
double qiblaTurnDegrees({required double qibla, required double heading}) =>
    normalizeDeltaDegrees(qibla - heading);

/// Sin/cos untuk lukisan (ujian tidak bergantung Flutter).
(double sin, double cos) qiblaUnit(double degrees) {
  final r = degrees * math.pi / 180;
  return (math.sin(r), math.cos(r));
}

/// Mata angin 8-arah untuk [degrees]: indeks 0 = U, 1 = TL, 2 = T, … (lihat label di UI).
int compassOctant(double degrees) {
  final d = ((degrees % 360) + 360) % 360;
  return ((d + 22.5) ~/ 45) % 8;
}

/// Pengesan "menghadap kiblat" dengan histeresis: masuk apabila dalam [enterDeg], keluar hanya apabila
/// lebih daripada [exitDeg]. Tanpa ini penanda berkelip hijau/merah pada sempadan kerana bacaan sensor
/// sentiasa bergetar satu-dua darjah.
class QiblaAlignment {
  QiblaAlignment({this.enterDeg = 3, this.exitDeg = 6});

  final double enterDeg;
  final double exitDeg;
  bool _aligned = false;

  bool get aligned => _aligned;

  /// Kemas kini dengan [turnDegrees] (lihat [qiblaTurnDegrees]); kembalikan keadaan baharu.
  bool update(double turnDegrees) {
    final a = turnDegrees.abs();
    _aligned = _aligned ? a <= exitDeg : a <= enterDeg;
    return _aligned;
  }

  void reset() => _aligned = false;
}

/// Penapis lulus-rendah pada sudut bulat: bacaan magnetometer bergetar; paparan mesti licin tanpa
/// melompat apabila melintasi 359°→0°. [step] menggerakkan nilai terpapar ke arah sasaran melalui
/// laluan terpendek, lebih pantas apabila jauh dan hampir diam apabila sudah dekat.
class HeadingSmoother {
  HeadingSmoother({this.responsiveness = 14, this.deadbandDeg = 0.25});

  /// Pemalar masa kebalikan (per saat): lebih besar = lebih pantas menjejak.
  final double responsiveness;

  /// Perbezaan di bawah ini diabaikan supaya jarum tidak menggeletar ketika telefon diam.
  final double deadbandDeg;

  double? _shown;

  double? get value => _shown;

  /// Gerakkan ke arah [target] selama [dtSeconds]; kembalikan nilai terpapar (0–360).
  double step(double target, double dtSeconds) {
    final shown = _shown;
    if (shown == null) {
      _shown = _wrap(target);
      return _shown!;
    }
    final delta = normalizeDeltaDegrees(target - shown);
    if (delta.abs() < deadbandDeg) return shown;
    final k = 1 - math.exp(-responsiveness * dtSeconds.clamp(0, 0.1));
    _shown = _wrap(shown + delta * k);
    return _shown!;
  }

  void reset() => _shown = null;

  static double _wrap(double d) => ((d % 360) + 360) % 360;
}
