import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/log.dart';
import '../domain/fuel.dart';

/// Katalog data terbuka Kerajaan Malaysia (data.gov.my): harga petrol dan diesel mingguan. Percuma,
/// tanpa kunci, had 4 permintaan seminit; app membuat sekali sehari paling banyak. Lesen CC BY 4.0:
/// atribusi dipaparkan di Tentang.
const fuelPriceUrl =
    'https://api.data.gov.my/data-catalogue?id=fuelprice&sort=-date&limit=12';

const _cacheKey = 'fuel.prices.v1';

/// Tempoh cache dianggap segar; harga berubah mingguan, jadi sehari lebih daripada cukup.
const fuelPriceFreshFor = Duration(hours: 24);

/// Cache lama masih digunakan jika rangkaian gagal, sehingga ini.
const fuelPriceMaxStale = Duration(days: 30);

/// Mengambil harga bahan api. Cache dalam SharedPreferences; kegagalan rangkaian jatuh ke cache lama
/// (sehingga 30 hari), dan tanpa cache pulangkan null: app tidak pernah mereka harga.
class FuelPriceService {
  FuelPriceService(this._dio, this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  Future<FuelPrices?> load() async {
    final now = _clock();
    final cached = _readCache();
    if (cached != null &&
        now.difference(cached.fetchedAt) < fuelPriceFreshFor) {
      return cached;
    }
    try {
      final response = await _dio.get<Object>(
        fuelPriceUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final text = responseText(response.data);
      final parsed = text == null
          ? null
          : parseFuelPrices(jsonDecode(text), now: now);
      if (parsed != null) {
        unawaited(_prefs.setString(_cacheKey, jsonEncode(_toJson(parsed))));
        return parsed;
      }
    } on DioException catch (e) {
      logDiag('Harga minyak tidak dapat diambil: ${e.type.name}');
    } on FormatException {
      logDiag('Harga minyak: respons bukan JSON');
    }
    if (cached != null &&
        now.difference(cached.fetchedAt) < fuelPriceMaxStale) {
      return cached;
    }
    return null;
  }

  FuelPrices? _readCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final at = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
      final map = json['prices'];
      if (at == null || map is! Map<String, dynamic>) return null;
      final prices = <FuelType, double>{};
      for (final type in FuelType.values) {
        final v = map[type.name];
        if (v is num && v > 0) prices[type] = v.toDouble();
      }
      if (prices.isEmpty) return null;
      return FuelPrices(
        prices: prices,
        fetchedAt: at,
        effectiveDate: json['date'] as String?,
      );
    } on Object {
      return null;
    }
  }

  static Map<String, Object?> _toJson(FuelPrices p) => {
    'fetchedAt': p.fetchedAt.toIso8601String(),
    'date': p.effectiveDate,
    'prices': {for (final e in p.prices.entries) e.key.name: e.value},
  };
}

/// Harga bahan api terkini (dari cache segar, rangkaian atau cache lama); null jika tiada langsung.
final fuelPricesProvider = FutureProvider<FuelPrices?>((ref) async {
  final service = FuelPriceService(
    ref.watch(dioProvider),
    ref.watch(sharedPreferencesProvider),
  );
  return service.load();
});
