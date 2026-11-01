import 'route_option.dart';
import 'route_scoring.dart';
import 'toll.dart';

/// Kehendak pengguna apabila memilih antara pilihan laluan (cth. arahan AI "paling selamat").
enum RoutePreference {
  recommended,
  fastest,
  shortest,
  noTolls,
  noHighways,
  cheapest,
  safest,
}

/// Sebab ringkas pilihan dibuat, supaya jawapan boleh menerangkannya dengan jujur.
enum RouteChoiceReason {
  /// Pilihan "Disyorkan" app (skor masa, belokan dan jalan).
  recommended,
  fastest,
  shortest,
  tollFree,

  /// Pengguna mahu tanpa tol tetapi semua pilihan bertol: yang paling sedikit tol dipilih.
  fewestTolls,
  noHighways,
  cheapest,

  /// Wakil "selamat": jalan utama, kurang belokan/pusingan-U, tiada feri. BUKAN data kemalangan.
  safest,
}

class RouteChoice {
  const RouteChoice(this.index, this.reason);

  final int index;
  final RouteChoiceReason reason;
}

/// Kos bahan api kasar (RM/km) untuk "paling murah" apabila app tidak memberi kadar lain:
/// ~7 L/100 km × RON95 bersubsidi RM2.05/L.
const defaultFuelRmPerKm = 0.14;

/// Pilih pilihan laluan yang paling sesuai dengan [pref]. [tolls] ialah anggaran tol mengikut
/// [routeKey] (boleh kosong). Tidak pernah gagal: tanpa padanan, kembali kepada pilihan pertama
/// (yang app sudah susun sebagai "Disyorkan").
RouteChoice chooseRoute(
  List<RouteOption> options,
  RoutePreference pref, {
  Map<String, TollEstimate> tolls = const {},
  double fuelRmPerKm = defaultFuelRmPerKm,
}) {
  if (options.isEmpty) {
    return const RouteChoice(0, RouteChoiceReason.recommended);
  }
  int best(
    double Function(RouteOption o) cost, {
    bool Function(RouteOption)? where,
  }) {
    var index = -1;
    var bestCost = double.infinity;
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      if (where != null && !where(o)) continue;
      final c = cost(o);
      if (c < bestCost) {
        bestCost = c;
        index = i;
      }
    }
    return index;
  }

  switch (pref) {
    case RoutePreference.recommended:
      return const RouteChoice(0, RouteChoiceReason.recommended);
    case RoutePreference.fastest:
      return RouteChoice(
        best((o) => o.durationS.toDouble()),
        RouteChoiceReason.fastest,
      );
    case RoutePreference.shortest:
      return RouteChoice(
        best((o) => o.distanceM.toDouble()),
        RouteChoiceReason.shortest,
      );
    case RoutePreference.noTolls:
      final free = best(
        (o) => o.durationS.toDouble(),
        where: (o) => !o.hasTolls,
      );
      if (free >= 0) return RouteChoice(free, RouteChoiceReason.tollFree);
      return RouteChoice(
        best((o) => o.tollLengthM.toDouble()),
        RouteChoiceReason.fewestTolls,
      );
    case RoutePreference.noHighways:
      final local = best(
        (o) => o.durationS.toDouble(),
        where: (o) => !o.hasHighway || o.label == RouteLabel.noHighways,
      );
      if (local >= 0) return RouteChoice(local, RouteChoiceReason.noHighways);
      return const RouteChoice(0, RouteChoiceReason.recommended);
    case RoutePreference.cheapest:
      return RouteChoice(
        best((o) => estimatedTripCostRm(o, tolls[routeKey(o)], fuelRmPerKm)),
        RouteChoiceReason.cheapest,
      );
    case RoutePreference.safest:
      final fastest = options
          .map((o) => o.durationS)
          .reduce((a, b) => a < b ? a : b);
      // Jangan pilih lencongan yang jauh lebih lama atas nama "selamat".
      final limit = fastest * 1.2;
      final index = best(safetyScore, where: (o) => o.durationS <= limit);
      return RouteChoice(index < 0 ? 0 : index, RouteChoiceReason.safest);
  }
}

/// Anggaran kos perjalanan (RM): tol yang diketahui + bahan api. Tol yang belum diketahui pada laluan
/// bertol dikira kasar daripada panjang jalan bertol (~RM0.10/km, purata kadar lebuh raya tertutup).
double estimatedTripCostRm(
  RouteOption o,
  TollEstimate? toll,
  double fuelRmPerKm,
) {
  final fuel = o.distanceM / 1000 * fuelRmPerKm;
  if (!o.hasTolls) return fuel;
  if (toll != null && toll.isExact) return fuel + toll.knownRm;
  final rough = o.tollLengthM / 1000 * 0.10;
  final known = toll?.knownRm ?? 0;
  return fuel + (known > rough ? known : rough);
}

/// Skor "selamat" (lebih rendah lebih baik). Wakil jujur tanpa data kemalangan: mengutamakan jalan
/// utama ([RouteOption.roadPenalty] daripada kelas jalan sebenar), sedikit belokan dan pusingan-U,
/// tiada feri atau jalan bersekatan masa. Berat lebih tegas daripada [routeScore].
double safetyScore(RouteOption o) {
  var s = o.durationS.toDouble();
  s += o.durationS * o.roadPenalty * 2;
  s += turnCountOf(o) * 20;
  s += uTurnCountOf(o) * 300;
  if (o.hasFerry) s += 3600;
  if (o.hasTimeRestrictions) s += 900;
  return s;
}
