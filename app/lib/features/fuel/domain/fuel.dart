import 'package:flutter/foundation.dart';

import '../../route_preview/domain/route_option.dart';

enum FuelType { ron95, ron97, diesel }

/// Harga petrol/diesel (RM seliter) pada satu masa, daripada data.gov.my.
@immutable
class FuelPrices {
  const FuelPrices({
    required this.prices,
    required this.fetchedAt,
    this.effectiveDate,
  });

  final Map<FuelType, double> prices;

  /// Bila app mengambil data (untuk menentukan tempoh cache).
  final DateTime fetchedAt;

  /// Tarikh harga berkuat kuasa mengikut sumber (rentetan `YYYY-MM-DD`), jika ada.
  final String? effectiveDate;

  double? priceOf(FuelType type) => prices[type];
}

/// Penggunaan bahan api lalai (L/100 km) apabila pengguna belum menetapkan. Anggaran umum untuk kereta
/// penumpang dan motosikal kecil; pengguna disarankan menetapkan nilai kenderaannya sendiri.
const defaultConsumptionCar = 8.0;
const defaultConsumptionMotorcycle = 3.5;

double defaultConsumptionFor(RouteVehicle vehicle) =>
    vehicle == RouteVehicle.motorcycle
    ? defaultConsumptionMotorcycle
    : defaultConsumptionCar;

/// Anggaran kos bahan api (RM) untuk [distanceM] meter pada [litersPer100Km] dan [pricePerLiter].
/// Null jika harga atau penggunaan tidak sah (tidak pernah mereka nilai).
double? estimateFuelCostRm({
  required int distanceM,
  required double litersPer100Km,
  required double? pricePerLiter,
}) {
  if (pricePerLiter == null ||
      !pricePerLiter.isFinite ||
      pricePerLiter <= 0 ||
      !litersPer100Km.isFinite ||
      litersPer100Km <= 0 ||
      distanceM < 0) {
    return null;
  }
  return distanceM / 1000 * litersPer100Km / 100 * pricePerLiter;
}

/// Menghurai respons API katalog data.gov.my untuk `fuelprice`.
///
/// Bentuk dijangka: senarai rekod (atau objek dengan `data`/`row_data`) yang membawa `date` serta
/// `ron95`, `ron97`, `diesel`, dan `series_type`. Hanya rekod `series_type == "level"` (harga, bukan
/// perubahan mingguan) atau tanpa `series_type` digunakan; rekod terbaharu mengikut `date` menang.
/// Nilai bukan nombor, sifar atau tidak masuk akal (di luar RM0.50-RM20 seliter) diabaikan.
/// Respons rosak -> null (pemanggil kekal menggunakan cache atau harga pengguna).
FuelPrices? parseFuelPrices(Object? decoded, {required DateTime now}) {
  final rows = <Map<String, dynamic>>[];
  void collect(Object? node) {
    if (node is List) {
      for (final e in node) {
        collect(e);
      }
    } else if (node is Map<String, dynamic>) {
      if (node.containsKey('ron95') ||
          node.containsKey('ron97') ||
          node.containsKey('diesel')) {
        rows.add(node);
      } else {
        for (final key in const ['data', 'row_data']) {
          if (node.containsKey(key)) collect(node[key]);
        }
      }
    }
  }

  collect(decoded);

  Map<String, dynamic>? best;
  for (final row in rows) {
    final series = row['series_type'];
    if (series != null && series != 'level') continue;
    final date = row['date'];
    final bestDate = best?['date'];
    if (best == null ||
        (date is String &&
            (bestDate is! String || date.compareTo(bestDate) > 0))) {
      best = row;
    }
  }
  if (best == null) return null;

  double? read(String key) {
    final v = best![key];
    final n = v is num
        ? v.toDouble()
        : (v is String ? double.tryParse(v) : null);
    return n != null && n.isFinite && n >= 0.5 && n <= 20 ? n : null;
  }

  final prices = <FuelType, double>{
    FuelType.ron95: ?read('ron95'),
    FuelType.ron97: ?read('ron97'),
    FuelType.diesel: ?read('diesel'),
  };
  if (prices.isEmpty) return null;
  final date = best['date'];
  return FuelPrices(
    prices: prices,
    fetchedAt: now,
    effectiveDate: date is String ? date : null,
  );
}
