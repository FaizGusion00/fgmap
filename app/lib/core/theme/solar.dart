import 'dart:math' as math;

/// Waktu matahari terbit dan terbenam (instan UTC) bagi satu hari.
class SolarTimes {
  const SolarTimes({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;
}

/// Kiraan matahari terbit/terbenam tanpa rangkaian (persamaan terbit matahari, ketepatan beberapa
/// minit, mencukupi untuk menukar tema). [year]/[month]/[day] ialah tarikh dinding tempatan;
/// keputusan ialah instan UTC, jadi dibanding terus dengan `DateTime.now()`.
///
/// Null di kawasan kutub apabila matahari tidak terbit atau tidak terbenam pada hari itu.
SolarTimes? solarTimes({
  required int year,
  required int month,
  required int day,
  required double lat,
  required double lng,
}) {
  const rad = math.pi / 180;
  // Hari Julian pada tengah hari UTC tarikh itu.
  final jd =
      DateTime.utc(year, month, day, 12).millisecondsSinceEpoch / 86400000.0 +
      2440587.5;
  final n = (jd - 2451545.0 + 0.0008).floorToDouble();
  final jStar = n - lng / 360;
  final m = (357.5291 + 0.98560028 * jStar) % 360;
  final mRad = m * rad;
  final c =
      1.9148 * math.sin(mRad) +
      0.0200 * math.sin(2 * mRad) +
      0.0003 * math.sin(3 * mRad);
  final lambda = (m + c + 180 + 102.9372) % 360;
  final lambdaRad = lambda * rad;
  final transit =
      2451545.0 +
      jStar +
      0.0053 * math.sin(mRad) -
      0.0069 * math.sin(2 * lambdaRad);
  final sinDec = math.sin(lambdaRad) * math.sin(23.4397 * rad);
  final dec = math.asin(sinDec);
  final cosH =
      (math.sin(-0.833 * rad) - math.sin(lat * rad) * sinDec) /
      (math.cos(lat * rad) * math.cos(dec));
  if (cosH > 1 || cosH < -1) return null;
  final h = math.acos(cosH) / rad;
  DateTime fromJd(double j) => DateTime.fromMillisecondsSinceEpoch(
    ((j - 2440587.5) * 86400000).round(),
    isUtc: true,
  );
  return SolarTimes(
    sunrise: fromJd(transit - h / 360),
    sunset: fromJd(transit + h / 360),
  );
}

/// Keadaan "malam" pada [now] dan bila ia berubah seterusnya.
class SunPhase {
  const SunPhase({required this.isNight, required this.nextChange});

  final bool isNight;
  final DateTime nextChange;
}

/// Menentukan sama ada [now] ialah malam di [lat]/[lng], dan bila peralihan seterusnya.
/// Di kawasan kutub (tiada terbit/terbenam) kembali ke isyarat jam 06:00-18:00 tempatan.
SunPhase sunPhaseAt(DateTime now, {required double lat, required double lng}) {
  final instant = now.toUtc();
  SolarTimes? at(int dayOffset) {
    final d = DateTime(now.year, now.month, now.day + dayOffset);
    return solarTimes(
      year: d.year,
      month: d.month,
      day: d.day,
      lat: lat,
      lng: lng,
    );
  }

  final today = at(0);
  final tomorrow = at(1);
  if (today == null || tomorrow == null) {
    final hour = now.hour;
    final night = hour < 6 || hour >= 18;
    final next = night
        ? DateTime(now.year, now.month, now.day + (hour >= 18 ? 1 : 0), 6)
        : DateTime(now.year, now.month, now.day, 18);
    return SunPhase(isNight: night, nextChange: next);
  }
  if (instant.isBefore(today.sunrise)) {
    return SunPhase(isNight: true, nextChange: today.sunrise.toLocal());
  }
  if (instant.isBefore(today.sunset)) {
    return SunPhase(isNight: false, nextChange: today.sunset.toLocal());
  }
  return SunPhase(isNight: true, nextChange: tomorrow.sunrise.toLocal());
}
