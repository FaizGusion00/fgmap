import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/along_route/data/along_route_search.dart';
import 'package:fgmap/features/along_route/domain/along_route_category.dart';
import 'package:fgmap/features/along_route/presentation/along_route_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

List<GeoPoint> _line(double km, {double lat = 0}) {
  final n = (km * 10).round();
  return [for (var i = 0; i <= n; i++) GeoPoint(lat, i * (km / 111.32) / n)];
}

/// Menjawab pertanyaan gabungan (semua kategori) dan merekod setiap panggilan.
class _Overpass {
  final calls = <String>[];

  ResponseBody respond(RequestOptions o) {
    final q = o.data as String;
    calls.add(q.contains('charging_station') ? 'all' : 'single');
    return StubAdapter.json({
      'elements': [
        {
          'type': 'node',
          'id': 1,
          'lat': 0.0,
          'lon': 0.1,
          'tags': {'name': 'Petronas', 'amenity': 'fuel'},
        },
        {
          'type': 'node',
          'id': 2,
          'lat': 0.0,
          'lon': 0.2,
          'tags': {'name': 'R&R Tapah', 'highway': 'services'},
        },
      ],
    });
  }
}

void main() {
  late _Overpass net;
  late ProviderContainer container;

  setUp(() {
    net = _Overpass();
    final dio = Dio()..httpClientAdapter = StubAdapter(net.respond);
    container = ProviderContainer(
      overrides: [
        alongRouteSearchProvider.overrideWithValue(
          AlongRouteSearch(dio, const ['https://o.test/api']),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  AlongRouteController ctl() =>
      container.read(alongRouteControllerProvider.notifier);
  AlongRouteState st() => container.read(alongRouteControllerProvider);

  test('kunci laluan membezakan laluan alternatif', () {
    expect(
      AlongRouteController.routeKeyOf(_line(50)),
      isNot(AlongRouteController.routeKeyOf(_line(50, lat: 0.01))),
    );
    expect(
      AlongRouteController.routeKeyOf(_line(50)),
      AlongRouteController.routeKeyOf(_line(50)),
    );
  });

  test('satu permintaan memuat SEMUA kategori', () async {
    await ctl().loadForRoute(
      sampleOption(points: _line(50)),
      category: AlongRouteCategory.restArea,
    );
    expect(st().pois.single.name, 'R&R Tapah');
    expect(st().loading, isFalse);
    await pumpEventQueue();
    expect(net.calls, ['all']);
  });

  test('menukar kategori selepas dimuat: serta-merta, tiada rangkaian', () async {
    await ctl().loadForRoute(
      sampleOption(points: _line(50)),
      category: AlongRouteCategory.restArea,
    );
    net.calls.clear();

    final f = ctl().selectCategory(AlongRouteCategory.fuel);
    // Keadaan sudah betul sebelum future selesai: tiada keadaan memuat.
    expect(st().category, AlongRouteCategory.fuel);
    expect(st().loading, isFalse);
    expect(st().pois.single.name, 'Petronas');
    await f;

    // EV/surau/tandas juga serta-merta (kosong di sini), bukan permintaan baharu.
    await ctl().selectCategory(AlongRouteCategory.evCharging);
    expect(st().loading, isFalse);
    expect(st().pois, isEmpty);
    await ctl().selectCategory(AlongRouteCategory.restArea);
    expect(st().pois.single.name, 'R&R Tapah');
    await pumpEventQueue();
    expect(net.calls, isEmpty);
  });

  test(
    'cip diketuk semasa carian gabungan berjalan: kongsi permintaan yang sama',
    () async {
      final first = ctl().loadForRoute(
        sampleOption(points: _line(50)),
        category: AlongRouteCategory.restArea,
      );
      final second = ctl().selectCategory(AlongRouteCategory.fuel);
      expect(st().loading, isTrue);
      expect(
        st().pois,
        isEmpty,
        reason: 'jangan tunjuk R&R di bawah cip Minyak',
      );
      await Future.wait([first, second]);
      expect(st().category, AlongRouteCategory.fuel);
      expect(st().pois.single.name, 'Petronas');
      expect(net.calls, ['all']);
    },
  );

  test('laluan lain: cache laluan sebelumnya tidak dipakai', () async {
    await ctl().loadForRoute(
      sampleOption(points: _line(50)),
      category: AlongRouteCategory.restArea,
    );
    await pumpEventQueue();
    net.calls.clear();
    await ctl().loadForRoute(
      sampleOption(points: _line(50, lat: 0.02)),
      category: AlongRouteCategory.restArea,
    );
    expect(net.calls.first, 'all');
  });

  test('laluan yang sama dipilih semula: dari cache', () async {
    final route = sampleOption(points: _line(50));
    await ctl().loadForRoute(route, category: AlongRouteCategory.restArea);
    await pumpEventQueue();
    net.calls.clear();
    await ctl().loadForRoute(route, category: AlongRouteCategory.restArea);
    expect(st().pois.single.name, 'R&R Tapah');
    expect(net.calls, isEmpty);
  });

  test('clear() menetapkan semula dan cache laluan lama tidak bocor', () async {
    final route = sampleOption(points: _line(50));
    await ctl().loadForRoute(route, category: AlongRouteCategory.restArea);
    ctl().clear();
    expect(st().pois, isEmpty);
    expect(st().loading, isFalse);
    await pumpEventQueue();
  });

  test(
    'cache cakera buang entri tertua, bukan tarikh yang regex gagal baca',
    () async {
      String body(String at) =>
          jsonEncode({'at': at, 'cats': <String, Object>{}});
      SharedPreferences.setMockInitialValues({
        '${alongRouteCachePrefix}old': body('2020-01-01T00:00:00.000'),
        '${alongRouteCachePrefix}a': body('2022-01-01T00:00:00.000'),
        '${alongRouteCachePrefix}b': body('2023-01-01T00:00:00.000'),
        '${alongRouteCachePrefix}c': body('2024-01-01T00:00:00.000'),
        '${alongRouteCachePrefix}d': body('2025-01-01T00:00:00.000'),
        // Jarak selepas titik bertindih: regex `"at":"` gagal, JSON tidak.
        '${alongRouteCachePrefix}spaced':
            '{"at": "2026-11-01T00:00:00.000", "cats": {}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio()..httpClientAdapter = StubAdapter(net.respond);
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          alongRouteSearchProvider.overrideWithValue(
            AlongRouteSearch(dio, const ['https://o.test/api']),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c
          .read(alongRouteControllerProvider.notifier)
          .loadForRoute(
            sampleOption(points: _line(50)),
            category: AlongRouteCategory.restArea,
          );
      await pumpEventQueue();

      expect(prefs.getString('${alongRouteCachePrefix}old'), isNull);
      expect(prefs.getString('${alongRouteCachePrefix}spaced'), isNotNull);
    },
  );

  test('ralat rangkaian: keadaan ralat, boleh cuba semula', () async {
    var fail = true;
    final dio = Dio()
      ..httpClientAdapter = StubAdapter((o) {
        if (fail) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        return net.respond(o);
      });
    final c = ProviderContainer(
      overrides: [
        alongRouteSearchProvider.overrideWithValue(
          AlongRouteSearch(dio, const ['https://o.test/api']),
        ),
      ],
    );
    addTearDown(c.dispose);
    final n = c.read(alongRouteControllerProvider.notifier);
    await n.loadForRoute(
      sampleOption(points: _line(50)),
      category: AlongRouteCategory.restArea,
    );
    expect(c.read(alongRouteControllerProvider).error, 'unavailable');
    fail = false;
    await n.selectCategory(AlongRouteCategory.restArea);
    expect(c.read(alongRouteControllerProvider).error, isNull);
    expect(c.read(alongRouteControllerProvider).pois, isNotEmpty);
  });
}
