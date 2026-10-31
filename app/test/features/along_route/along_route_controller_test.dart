import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/along_route/data/along_route_search.dart';
import 'package:fgmap/features/along_route/domain/along_route_category.dart';
import 'package:fgmap/features/along_route/presentation/along_route_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

List<GeoPoint> _line(double km, {double lat = 0}) {
  final n = (km * 10).round();
  return [for (var i = 0; i <= n; i++) GeoPoint(lat, i * (km / 111.32) / n)];
}

/// Menjawab ikut jenis pertanyaan (R&R vs minyak) dan merekod setiap panggilan.
class _Overpass {
  final calls = <String>[];

  ResponseBody respond(RequestOptions o) {
    final q = o.data as String;
    final fuel = q.contains('"amenity"="fuel"');
    calls.add(fuel ? 'fuel' : 'rr');
    return StubAdapter.json({
      'elements': [
        {
          'type': 'node',
          'id': fuel ? 1 : 2,
          'lat': 0.0,
          'lon': 0.1,
          'tags': {'name': fuel ? 'Petronas' : 'R&R Tapah'},
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

  test('R&R dimuat, kemudian minyak dipra-muat senyap-senyap', () async {
    await ctl().loadForRoute(
      sampleOption(points: _line(50)),
      category: AlongRouteCategory.restArea,
    );
    expect(st().pois.single.name, 'R&R Tapah');
    expect(st().loading, isFalse);
    await pumpEventQueue();
    expect(net.calls, ['rr', 'fuel']);
  });

  test('menukar ke kategori yang sudah dimuat/pra-muat: serta-merta, '
      'tiada rangkaian', () async {
    await ctl().loadForRoute(
      sampleOption(points: _line(50)),
      category: AlongRouteCategory.restArea,
    );
    await pumpEventQueue();
    net.calls.clear();

    final f = ctl().selectCategory(AlongRouteCategory.fuel);
    // Keadaan sudah betul sebelum future selesai: tiada keadaan memuat.
    expect(st().category, AlongRouteCategory.fuel);
    expect(st().loading, isFalse);
    expect(st().pois.single.name, 'Petronas');
    await f;

    await ctl().selectCategory(AlongRouteCategory.restArea);
    expect(st().pois.single.name, 'R&R Tapah');
    await pumpEventQueue();
    expect(net.calls, isEmpty);
  });

  test(
    'kategori belum dimuat: senarai lama dikosongkan semasa memuat',
    () async {
      await ctl().loadForRoute(
        sampleOption(points: _line(50)),
        category: AlongRouteCategory.restArea,
      );
      await pumpEventQueue();
      final f = ctl().selectCategory(AlongRouteCategory.mosque);
      expect(st().loading, isTrue);
      expect(
        st().pois,
        isEmpty,
        reason: 'jangan tunjuk R&R di bawah cip Surau',
      );
      await f;
      expect(st().loading, isFalse);
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
    expect(net.calls.first, 'rr');
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
