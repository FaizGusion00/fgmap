import 'route_option.dart';

/// Jenis manuver Valhalla yang dikira sebagai belokan (sedikit/biasa/tajam ke kiri atau kanan).
/// Jenis lain (teruskan, lencongan, bulatan, ramp) dikira berasingan atau tidak langsung.
const _turnTypes = {9, 10, 11, 14, 15, 16};
const _uTurnTypes = {12, 13};

/// Bilangan belokan pada laluan (tanpa pusingan-U dan bulatan).
int turnCountOf(RouteOption route) =>
    route.maneuvers.where((m) => _turnTypes.contains(m.type)).length;

/// Bilangan pusingan-U.
int uTurnCountOf(RouteOption route) =>
    route.maneuvers.where((m) => _uTurnTypes.contains(m.type)).length;

/// Kelajuan purata (m/s) di bawah ini sepanjang sekurang-kurangnya [_slowStretchM] dianggap jalan kecil
/// atau sesak (bukan jalan utama); ia digunakan sebagai wakil kasar kerana Valhalla tidak mendedahkan
/// kelas jalan dalam arahan.
const _slowSpeedMps = 6.0;
const _slowStretchM = 500;

/// Skor laluan dalam "saat setara": semakin RENDAH semakin baik. Ini bukan anggaran masa sebenar.
///
/// Tujuan: laluan utama = yang terbaik dan paling selamat, bukan sekadar yang terpantas (Waze
/// menghantar pemandu melalui lorong kecil demi beberapa saat). Penalti, mengikut keutamaan:
///  - feri (+15 min) dan jalan bersekatan masa (+5 min): jadual/ketersediaan tidak pasti;
///  - pusingan-U (+90 s setiap satu): berisiko dan perlahan;
///  - belokan (+6 s setiap satu): lebih banyak belokan = lebih banyak peluang tersilap dan konflik;
///  - jalan panjang yang purata kelajuannya sangat rendah (+25% masanya): lorong kecil/sesak;
///  - jalan kecil mengikut kelas jalan sebenar ([RouteOption.roadPenalty]): "jalan kampung" yang
///    singkat tetapi sempit, berlubang dan tanpa lampu ialah pilihan buruk berbanding jalan utama
///    yang beberapa minit lebih lama. Ini yang membezakan laluan "proper" gaya Waze.
double routeScore(RouteOption route) {
  var score = route.durationS.toDouble();
  score += route.durationS * route.roadPenalty;
  score += turnCountOf(route) * 6;
  score += uTurnCountOf(route) * 90;
  if (route.hasFerry) score += 900;
  if (route.hasTimeRestrictions) score += 300;
  for (final m in route.maneuvers) {
    if (m.lengthM >= _slowStretchM &&
        m.timeS > 0 &&
        m.lengthM / m.timeS < _slowSpeedMps) {
      score += m.timeS * 0.25;
    }
  }
  return score;
}
