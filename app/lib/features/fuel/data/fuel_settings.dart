import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../route_preview/domain/route_option.dart';
import '../domain/fuel.dart';
import 'fuel_price_service.dart';

/// Tetapan kos bahan api. [manualPrice] (RM/L) mengatasi harga daripada data.gov.my: perlu kerana
/// harga RON95 berbeza mengikut kelayakan subsidi, jadi pengguna menetapkan harga yang benar-benar dibayar.
@immutable
class FuelSettings {
  const FuelSettings({
    this.type = FuelType.ron95,
    this.carLitersPer100Km = defaultConsumptionCar,
    this.motorcycleLitersPer100Km = defaultConsumptionMotorcycle,
    this.manualPrice,
  });

  final FuelType type;
  final double carLitersPer100Km;
  final double motorcycleLitersPer100Km;
  final double? manualPrice;

  double litersPer100Km(RouteVehicle vehicle) =>
      vehicle == RouteVehicle.motorcycle
      ? motorcycleLitersPer100Km
      : carLitersPer100Km;

  FuelSettings copyWith({
    FuelType? type,
    double? carLitersPer100Km,
    double? motorcycleLitersPer100Km,
    double? manualPrice,
    bool clearManualPrice = false,
  }) => FuelSettings(
    type: type ?? this.type,
    carLitersPer100Km: carLitersPer100Km ?? this.carLitersPer100Km,
    motorcycleLitersPer100Km:
        motorcycleLitersPer100Km ?? this.motorcycleLitersPer100Km,
    manualPrice: clearManualPrice ? null : (manualPrice ?? this.manualPrice),
  );

  @override
  bool operator ==(Object other) =>
      other is FuelSettings &&
      other.type == type &&
      other.carLitersPer100Km == carLitersPer100Km &&
      other.motorcycleLitersPer100Km == motorcycleLitersPer100Km &&
      other.manualPrice == manualPrice;

  @override
  int get hashCode => Object.hash(
    type,
    carLitersPer100Km,
    motorcycleLitersPer100Km,
    manualPrice,
  );
}

const _typeKey = 'fuel.type';
const _carKey = 'fuel.lper100.car';
const _motoKey = 'fuel.lper100.moto';
const _priceKey = 'fuel.price.manual';

/// Had munasabah supaya input salah (cth. 0 atau 500) tidak menghasilkan anggaran mengarut.
const minConsumption = 1.0;
const maxConsumption = 40.0;
const minManualPrice = 0.5;
const maxManualPrice = 20.0;

class FuelSettingsController extends Notifier<FuelSettings> {
  @override
  FuelSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    double? valid(double? v, double lo, double hi) =>
        v != null && v.isFinite && v >= lo && v <= hi ? v : null;
    return FuelSettings(
      type: FuelType.values.firstWhere(
        (t) => t.name == prefs.getString(_typeKey),
        orElse: () => FuelType.ron95,
      ),
      carLitersPer100Km:
          valid(prefs.getDouble(_carKey), minConsumption, maxConsumption) ??
          defaultConsumptionCar,
      motorcycleLitersPer100Km:
          valid(prefs.getDouble(_motoKey), minConsumption, maxConsumption) ??
          defaultConsumptionMotorcycle,
      manualPrice: valid(
        prefs.getDouble(_priceKey),
        minManualPrice,
        maxManualPrice,
      ),
    );
  }

  Future<void> setType(FuelType type) async {
    state = state.copyWith(type: type);
    await ref.read(sharedPreferencesProvider).setString(_typeKey, type.name);
  }

  Future<void> setConsumption(RouteVehicle vehicle, double value) async {
    final v = value.clamp(minConsumption, maxConsumption).toDouble();
    final prefs = ref.read(sharedPreferencesProvider);
    if (vehicle == RouteVehicle.motorcycle) {
      state = state.copyWith(motorcycleLitersPer100Km: v);
      await prefs.setDouble(_motoKey, v);
    } else {
      state = state.copyWith(carLitersPer100Km: v);
      await prefs.setDouble(_carKey, v);
    }
  }

  /// Harga ditetapkan sendiri (RM/L); null memadamnya dan kembali ke harga data.gov.my. Nilai di luar
  /// julat diabaikan.
  Future<void> setManualPrice(double? price) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (price == null) {
      state = state.copyWith(clearManualPrice: true);
      await prefs.remove(_priceKey);
      return;
    }
    if (!price.isFinite || price < minManualPrice || price > maxManualPrice) {
      return;
    }
    state = state.copyWith(manualPrice: price);
    await prefs.setDouble(_priceKey, price);
  }
}

final fuelSettingsProvider =
    NotifierProvider<FuelSettingsController, FuelSettings>(
      FuelSettingsController.new,
    );

/// Harga yang digunakan untuk anggaran: harga pengguna jika ada, jika tidak harga data.gov.my bagi
/// jenis bahan api yang dipilih; null jika tiada satu pun (maka tiada anggaran dipaparkan).
final effectiveFuelPriceProvider = Provider<double?>((ref) {
  final settings = ref.watch(fuelSettingsProvider);
  if (settings.manualPrice != null) return settings.manualPrice;
  final prices = ref.watch(fuelPricesProvider).value;
  return prices?.priceOf(settings.type);
});
