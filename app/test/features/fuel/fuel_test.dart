import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/fuel/data/fuel_price_service.dart';
import 'package:fgmap/features/fuel/data/fuel_settings.dart';
import 'package:fgmap/features/fuel/domain/fuel.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

final _now = DateTime(2026, 10, 26, 10);

Map<String, Object?> _row(
  String date, {
  Object? ron95 = 2.05,
  Object? ron97 = 3.18,
  Object? diesel = 2.15,
  String? series = 'level',
}) => {
  'date': date,
  'ron95': ron95,
  'ron97': ron97,
  'diesel': diesel,
  'series_type': ?series,
};

void main() {
  group('parseFuelPrices', () {
    test(
      'rekod terbaharu bersiri "level" menang; perubahan mingguan diabaikan',
      () {
        final parsed = parseFuelPrices([
          _row('2026-10-15', ron95: 2.00),
          _row('2026-10-22', ron95: 2.05),
          _row('2026-10-22', ron95: 0.05, series: 'change_weekly'),
        ], now: _now)!;
        expect(parsed.priceOf(FuelType.ron95), 2.05);
        expect(parsed.priceOf(FuelType.ron97), 3.18);
        expect(parsed.priceOf(FuelType.diesel), 2.15);
        expect(parsed.effectiveDate, '2026-10-22');
        expect(parsed.fetchedAt, _now);
      },
    );

    test('sarang dalam data / row_data dan nombor sebagai rentetan', () {
      final parsed = parseFuelPrices({
        'data': [
          {'row_data': _row('2026-10-22', ron95: '2.05')},
        ],
      }, now: _now)!;
      expect(parsed.priceOf(FuelType.ron95), 2.05);
    });

    test(
      'nilai tidak masuk akal atau bukan nombor diabaikan; semua tidak sah -> null',
      () {
        final partial = parseFuelPrices([
          _row('2026-10-22', ron95: 0, ron97: 'x', diesel: 99),
        ], now: _now);
        expect(partial, isNull);

        final one = parseFuelPrices([
          _row('2026-10-22', ron95: -1, ron97: 3.18, diesel: null),
        ], now: _now)!;
        expect(one.prices.keys, [FuelType.ron97]);
      },
    );

    test('bentuk rosak: null (tidak pernah melempar)', () {
      for (final bad in [
        null,
        'teks',
        42,
        <Object?>[],
        {'a': 1},
        [1, 2],
      ]) {
        expect(parseFuelPrices(bad, now: _now), isNull, reason: '$bad');
      }
    });
  });

  group('estimateFuelCostRm', () {
    test('jarak x penggunaan x harga', () {
      // 100 km, 8 L/100 km, RM2.05 seliter = RM16.40.
      expect(
        estimateFuelCostRm(
          distanceM: 100000,
          litersPer100Km: 8,
          pricePerLiter: 2.05,
        ),
        closeTo(16.4, 1e-9),
      );
    });

    test('tanpa harga atau input tidak sah: null, bukan 0', () {
      expect(
        estimateFuelCostRm(
          distanceM: 1000,
          litersPer100Km: 8,
          pricePerLiter: null,
        ),
        isNull,
      );
      expect(
        estimateFuelCostRm(
          distanceM: 1000,
          litersPer100Km: 0,
          pricePerLiter: 2,
        ),
        isNull,
      );
      expect(
        estimateFuelCostRm(
          distanceM: 1000,
          litersPer100Km: 8,
          pricePerLiter: 0,
        ),
        isNull,
      );
      expect(
        estimateFuelCostRm(distanceM: -1, litersPer100Km: 8, pricePerLiter: 2),
        isNull,
      );
      expect(
        estimateFuelCostRm(
          distanceM: 1000,
          litersPer100Km: double.nan,
          pricePerLiter: 2,
        ),
        isNull,
      );
    });

    test('penggunaan lalai: kereta 8.0, motosikal 3.5', () {
      expect(defaultConsumptionFor(RouteVehicle.car), 8.0);
      expect(defaultConsumptionFor(RouteVehicle.motorcycle), 3.5);
    });
  });

  group('FuelPriceService', () {
    late SharedPreferences prefs;
    var clock = _now;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      clock = _now;
    });

    FuelPriceService service(StubAdapter adapter) => FuelPriceService(
      Dio()..httpClientAdapter = adapter,
      prefs,
      clock: () => clock,
    );

    StubAdapter ok() =>
        StubAdapter((_) => StubAdapter.json([_row('2026-10-22')]));

    test('mengambil, menyimpan cache; dalam 24 jam tiada rangkaian', () async {
      final adapter = ok();
      final svc = service(adapter);
      final first = await svc.load();
      expect(first!.priceOf(FuelType.ron95), 2.05);
      expect(adapter.lastRequest!.uri.host, 'api.data.gov.my');
      expect(adapter.lastRequest!.uri.queryParameters['id'], 'fuelprice');

      adapter.lastRequest = null;
      clock = _now.add(const Duration(hours: 23));
      final second = await svc.load();
      expect(second!.priceOf(FuelType.ron95), 2.05);
      expect(adapter.lastRequest, isNull);
    });

    test('lebih 24 jam: ambil semula', () async {
      final adapter = ok();
      final svc = service(adapter);
      await svc.load();
      adapter.lastRequest = null;
      clock = _now.add(const Duration(hours: 25));
      await svc.load();
      expect(adapter.lastRequest, isNotNull);
    });

    test(
      'rangkaian gagal: cache lama (<= 30 hari) digunakan; lebih lama -> null',
      () async {
        await service(ok()).load();
        final failing = StubAdapter((_) => StubAdapter.text('x', status: 503));

        clock = _now.add(const Duration(days: 10));
        expect((await service(failing).load())!.priceOf(FuelType.ron95), 2.05);

        clock = _now.add(const Duration(days: 31));
        expect(await service(failing).load(), isNull);
      },
    );

    test('tiada cache dan gagal: null (tiada harga direka)', () async {
      final failing = StubAdapter((_) => StubAdapter.text('x', status: 500));
      expect(await service(failing).load(), isNull);
    });

    test('respons rosak atau tidak dijangka: cache dikekalkan', () async {
      await service(ok()).load();
      clock = _now.add(const Duration(days: 2));
      final bad = StubAdapter(
        (_) => StubAdapter.text(
          '{bukan json',
          status: 200,
          contentType: 'application/json',
        ),
      );
      expect((await service(bad).load())!.priceOf(FuelType.ron95), 2.05);
      final shape = StubAdapter((_) => StubAdapter.json({'x': 1}));
      expect((await service(shape).load())!.priceOf(FuelType.ron95), 2.05);
    });

    test('cache rosak diabaikan', () async {
      await prefs.setString('fuel.prices.v1', '{rosak');
      expect((await service(ok()).load())!.priceOf(FuelType.ron97), 3.18);
    });
  });

  group('FuelSettings', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer container({FuelPrices? prices}) {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fuelPricesProvider.overrideWith((ref) async => prices),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('lalai: RON95, kereta 8.0, motosikal 3.5, tiada harga sendiri', () {
      final s = container().read(fuelSettingsProvider);
      expect(s.type, FuelType.ron95);
      expect(s.litersPer100Km(RouteVehicle.car), 8.0);
      expect(s.litersPer100Km(RouteVehicle.motorcycle), 3.5);
      expect(s.manualPrice, isNull);
    });

    test('tetapan disimpan, dihadkan dan dipulihkan', () async {
      final c = container();
      final n = c.read(fuelSettingsProvider.notifier);
      await n.setType(FuelType.diesel);
      await n.setConsumption(RouteVehicle.car, 6.5);
      await n.setConsumption(RouteVehicle.motorcycle, 500);
      await n.setManualPrice(1.99);
      expect(
        c.read(fuelSettingsProvider).motorcycleLitersPer100Km,
        maxConsumption,
      );

      final reloaded = container().read(fuelSettingsProvider);
      expect(reloaded.type, FuelType.diesel);
      expect(reloaded.carLitersPer100Km, 6.5);
      expect(reloaded.manualPrice, 1.99);
    });

    test('harga sendiri di luar julat diabaikan; null memadamnya', () async {
      final c = container();
      final n = c.read(fuelSettingsProvider.notifier);
      await n.setManualPrice(1.99);
      await n.setManualPrice(0.1);
      await n.setManualPrice(50);
      await n.setManualPrice(double.nan);
      expect(c.read(fuelSettingsProvider).manualPrice, 1.99);
      await n.setManualPrice(null);
      expect(c.read(fuelSettingsProvider).manualPrice, isNull);
      expect(prefs.containsKey('fuel.price.manual'), isFalse);
    });

    test('nilai tersimpan tidak sah dilangkau ke lalai', () async {
      await prefs.setDouble('fuel.lper100.car', 0);
      await prefs.setDouble('fuel.price.manual', 999);
      await prefs.setString('fuel.type', 'plutonium');
      final s = container().read(fuelSettingsProvider);
      expect(s.carLitersPer100Km, 8.0);
      expect(s.manualPrice, isNull);
      expect(s.type, FuelType.ron95);
    });

    test('harga berkesan: sendiri > data.gov.my > tiada', () async {
      final prices = FuelPrices(
        prices: const {FuelType.ron95: 2.05, FuelType.diesel: 2.15},
        fetchedAt: _now,
      );
      final c = container(prices: prices);
      await c.read(fuelPricesProvider.future);
      expect(c.read(effectiveFuelPriceProvider), 2.05);

      await c.read(fuelSettingsProvider.notifier).setType(FuelType.diesel);
      expect(c.read(effectiveFuelPriceProvider), 2.15);

      await c.read(fuelSettingsProvider.notifier).setManualPrice(1.99);
      expect(c.read(effectiveFuelPriceProvider), 1.99);

      await prefs.clear();
      final none = container();
      await none.read(fuelPricesProvider.future);
      expect(none.read(effectiveFuelPriceProvider), isNull);
      await none.read(fuelSettingsProvider.notifier).setType(FuelType.ron97);
      expect(none.read(effectiveFuelPriceProvider), isNull);
    });
  });
}
