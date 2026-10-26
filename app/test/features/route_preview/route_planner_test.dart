import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/features/offline_maps/data/offline_engine_host.dart';
import 'package:fgmap/features/offline_maps/data/offline_map_store.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:fgmap_valhalla/fgmap_valhalla.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

const _query = RouteQuery(origin: klcc, destination: klia);
String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

Dio _dioWith(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;

Future<RoutingFailure> _failureOf(Future<Object?> Function() action) async {
  try {
    await action();
  } on RoutingFailure catch (f) {
    return f;
  }
  fail('dijangka RoutingFailure');
}

void main() {
  group('OnlineRoutePlanner', () {
    test('menghantar POST JSON ke URL dan menghurai respons sebenar', () async {
      final adapter = StubAdapter(
        (_) => StubAdapter.text(
          _fixture('valhalla_public_klcc_klia.json'),
          status: 200,
        ),
      );
      final planner = OnlineRoutePlanner(
        _dioWith(adapter),
        'https://valhalla.test/route',
      );

      final routes = await planner.plan(
        const RouteQuery(
          origin: klcc,
          destination: klia,
          headingDegrees: 90,
          avoidTolls: true,
        ),
      );

      expect(routes, hasLength(3));
      expect(routes.every((r) => r.source == RouteSource.online), isTrue);

      final req = adapter.lastRequest!;
      expect(req.method, 'POST');
      expect(req.uri.toString(), 'https://valhalla.test/route');
      expect(req.contentType, startsWith('application/json'));
      final body = adapter.lastBody! as Map<String, dynamic>;
      expect(body['costing'], 'auto');
      expect(body['costing_options'], {
        'auto': {'use_tolls': 0},
      });
      expect(((body['locations'] as List).first as Map)['heading'], 90);
    });

    final statusCases = {
      '400 error_code 442 (laut)': (
        400,
        '{"error_code":442,"error":"No path"}',
        RoutingFailureKind.noRoute,
      ),
      '400 error_code 171': (
        400,
        '{"error_code":171,"error":"No edges"}',
        RoutingFailureKind.noRoute,
      ),
      '400 kod tidak dikenali': (
        400,
        '{"error_code":110,"error":"x"}',
        RoutingFailureKind.invalidRequest,
      ),
      '429': (429, 'Too Many Requests', RoutingFailureKind.rateLimited),
      '429 dengan badan Valhalla': (
        429,
        '{"error_code":171}',
        RoutingFailureKind.rateLimited,
      ),
      '503': (503, '<html>', RoutingFailureKind.unavailable),
      '500': (500, '', RoutingFailureKind.unavailable),
      '504': (504, '', RoutingFailureKind.timeout),
      '403 (disekat oleh hos)': (
        403,
        'forbidden',
        RoutingFailureKind.unavailable,
      ),
      '404': (404, '', RoutingFailureKind.generic),
    };
    // Hos sebenar menghantar jenis kandungan berbeza; Dio menyahkod JSON secara automatik hanya untuk
    // application/json. Kedua-dua laluan MESTI memberi keputusan sama (bug sebenar ditangkap di sini).
    for (final contentType in [
      'application/json',
      'text/plain',
      'application/octet-stream',
    ]) {
      statusCases.forEach((name, c) {
        test('$name [$contentType]', () async {
          final adapter = StubAdapter(
            (_) =>
                StubAdapter.text(c.$2, status: c.$1, contentType: contentType),
          );
          final planner = OnlineRoutePlanner(
            _dioWith(adapter),
            'https://v.test/route',
          );
          expect((await _failureOf(() => planner.plan(_query))).kind, c.$3);
        });
      });
    }

    for (final contentType in ['application/json', 'text/plain']) {
      test('200 berjaya dihurai [$contentType]', () async {
        final adapter = StubAdapter(
          (_) => StubAdapter.text(
            _fixture('valhalla_public_klcc_klia.json'),
            status: 200,
            contentType: contentType,
          ),
        );
        final routes = await OnlineRoutePlanner(
          _dioWith(adapter),
          'https://v.test/route',
        ).plan(_query);
        expect(routes, hasLength(3));
      });
    }

    final transportCases = {
      DioExceptionType.connectionTimeout: RoutingFailureKind.network,
      DioExceptionType.connectionError: RoutingFailureKind.network,
      DioExceptionType.receiveTimeout: RoutingFailureKind.timeout,
      DioExceptionType.sendTimeout: RoutingFailureKind.timeout,
      DioExceptionType.unknown: RoutingFailureKind.generic,
    };
    transportCases.forEach((type, kind) {
      test('$type -> $kind', () async {
        final planner = OnlineRoutePlanner(
          _dioWith(FailingAdapter(type)),
          'https://v.test/route',
        );
        expect((await _failureOf(() => planner.plan(_query))).kind, kind);
      });
    });

    test(
      '200 dengan badan rosak -> generic, bukan pengecualian mentah',
      () async {
        final adapter = StubAdapter(
          (_) => StubAdapter.text('<html>captive portal</html>', status: 200),
        );
        final planner = OnlineRoutePlanner(
          _dioWith(adapter),
          'https://v.test/route',
        );
        expect(
          (await _failureOf(() => planner.plan(_query))).kind,
          RoutingFailureKind.generic,
        );
      },
    );
  });

  group('OfflineRoutePlanner', () {
    late Directory dir;
    late OfflineMapStore store;
    late _FakeEngine engine;
    late OfflineEngineHost host;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fg_planner_');
      store = OfflineMapStore(dir);
      engine = _FakeEngine();
      host = OfflineEngineHost(engine, store);
    });
    tearDown(() => dir.delete(recursive: true));

    Future<void> install() async {
      await store.ensureDir();
      final tmp = File('${dir.path}/x.tmp')..writeAsBytesSync([1, 2, 3, 4]);
      await store.install(tmp, version: '20261026', sizeBytes: 4);
    }

    test('tanpa pek dipasang -> offlineRequired, enjin tidak dibuka', () async {
      final failure = await _failureOf(
        () => OfflineRoutePlanner(host).plan(_query),
      );
      expect(failure.kind, RoutingFailureKind.offlineRequired);
      expect(engine.opened, isEmpty);
    });

    test(
      'pek dipasang: membuka enjin sekali dan menghurai respons sebagai offline',
      () async {
        await install();
        engine.response = _fixture('valhalla_klcc_klia.json');
        final planner = OfflineRoutePlanner(host);

        final first = await planner.plan(_query);
        await planner.plan(_query);

        expect(first, hasLength(2));
        expect(first.first.source, RouteSource.offline);
        expect(
          engine.opened,
          hasLength(1),
          reason: 'enjin dibuka secara malas dan digunakan semula',
        );
        final sent = jsonDecode(engine.requests.first) as Map<String, dynamic>;
        expect(sent['costing'], 'auto');
        expect(sent['directions_type'], 'maneuvers');
      },
    );

    test('ralat Valhalla dalam mesej enjin (171) -> noRoute', () async {
      await install();
      engine.routeError = const ValhallaEngineException(
        'route_failed',
        'ValhallaException\$Internal: {"error_code":171,"error":"No suitable edges near location"}',
      );
      final failure = await _failureOf(
        () => OfflineRoutePlanner(host).plan(_query),
      );
      expect(failure.kind, RoutingFailureKind.noRoute);
    });

    test('kegagalan enjin tanpa kod Valhalla -> offlineEngine', () async {
      await install();
      engine.routeError = const ValhallaEngineException(
        'route_failed',
        'SIGSEGV',
      );
      final failure = await _failureOf(
        () => OfflineRoutePlanner(host).plan(_query),
      );
      expect(failure.kind, RoutingFailureKind.offlineEngine);
    });

    test('gagal membuka enjin (tile rosak) -> offlineEngine', () async {
      await install();
      engine.openError = const ValhallaEngineException(
        'open_failed',
        'bad tile extract',
      );
      final failure = await _failureOf(
        () => OfflineRoutePlanner(host).plan(_query),
      );
      expect(failure.kind, RoutingFailureKind.offlineEngine);
    });

    test(
      'pek rosak (saiz tidak sepadan) dianggap tidak dipasang, enjin tidak dibuka',
      () async {
        await install();
        File(
          '${dir.path}/valhalla_tiles.tar',
        ).writeAsBytesSync([1, 2]); // dipotong
        final failure = await _failureOf(
          () => OfflineRoutePlanner(host).plan(_query),
        );
        expect(failure.kind, RoutingFailureKind.offlineRequired);
        expect(engine.opened, isEmpty);
      },
    );
  });

  group('HybridRoutePlanner', () {
    final onlineRoute = [sampleOption()];
    final offlineRoute = [sampleOption(source: RouteSource.offline)];

    HybridRoutePlanner hybrid(
      RoutePlanner online,
      RoutePlanner offline, [
      RoutingMode mode = RoutingMode.auto,
    ]) =>
        HybridRoutePlanner(online: online, offline: offline, mode: () => mode);

    test('auto: online berjaya -> offline tidak disentuh', () async {
      final online = RecordingPlanner.returns(onlineRoute);
      final offline = RecordingPlanner.returns(offlineRoute);
      final result = await hybrid(online, offline).plan(_query);
      expect(result.single.source, RouteSource.online);
      expect(offline.calls, 0);
    });

    for (final kind in [
      RoutingFailureKind.network,
      RoutingFailureKind.timeout,
      RoutingFailureKind.unavailable,
      RoutingFailureKind.rateLimited,
      RoutingFailureKind.generic,
    ]) {
      test(
        'auto: online gagal ($kind) + offline ada -> laluan offline',
        () async {
          final online = RecordingPlanner.fails(RoutingFailure(kind));
          final offline = RecordingPlanner.returns(offlineRoute);
          final result = await hybrid(online, offline).plan(_query);
          expect(result.single.source, RouteSource.offline);
          expect(online.calls, 1);
          expect(offline.calls, 1);
        },
      );
    }

    for (final kind in [
      RoutingFailureKind.noRoute,
      RoutingFailureKind.invalidRequest,
    ]) {
      test(
        'auto: online $kind ialah muktamad -> TIDAK jatuh ke offline',
        () async {
          final online = RecordingPlanner.fails(RoutingFailure(kind));
          final offline = RecordingPlanner.returns(offlineRoute);
          final failure = await _failureOf(
            () => hybrid(online, offline).plan(_query),
          );
          expect(failure.kind, kind);
          expect(offline.calls, 0);
        },
      );
    }

    final hintCases = {
      RoutingFailureKind.network: RoutingFailureKind.offlineRequired,
      RoutingFailureKind.timeout: RoutingFailureKind.offlineRequired,
      RoutingFailureKind.unavailable: RoutingFailureKind.offlineRequired,
      RoutingFailureKind.rateLimited: RoutingFailureKind.offlineRequired,
      // generic bukan masalah yang peta offline boleh selesaikan: kekal generic.
      RoutingFailureKind.generic: RoutingFailureKind.generic,
    };
    hintCases.forEach((onlineKind, expected) {
      test(
        'auto: online $onlineKind + tiada pek offline -> $expected',
        () async {
          final online = RecordingPlanner.fails(RoutingFailure(onlineKind));
          final offline = RecordingPlanner.fails(
            const RoutingFailure(RoutingFailureKind.offlineRequired),
          );
          final failure = await _failureOf(
            () => hybrid(online, offline).plan(_query),
          );
          expect(failure.kind, expected);
        },
      );
    });

    test(
      'auto: online gagal + enjin offline rosak -> kegagalan enjin dilaporkan (bukan disembunyikan)',
      () async {
        final online = RecordingPlanner.fails(
          const RoutingFailure(RoutingFailureKind.network),
        );
        final offline = RecordingPlanner.fails(
          const RoutingFailure(RoutingFailureKind.offlineEngine),
        );
        final failure = await _failureOf(
          () => hybrid(online, offline).plan(_query),
        );
        expect(failure.kind, RoutingFailureKind.offlineEngine);
      },
    );

    test('auto: online gagal + offline noRoute -> noRoute', () async {
      final online = RecordingPlanner.fails(
        const RoutingFailure(RoutingFailureKind.network),
      );
      final offline = RecordingPlanner.fails(
        const RoutingFailure(RoutingFailureKind.noRoute),
      );
      expect(
        (await _failureOf(() => hybrid(online, offline).plan(_query))).kind,
        RoutingFailureKind.noRoute,
      );
    });

    test('onlineOnly: tiada jatuh balik walaupun offline ada', () async {
      final online = RecordingPlanner.fails(
        const RoutingFailure(RoutingFailureKind.network),
      );
      final offline = RecordingPlanner.returns(offlineRoute);
      final failure = await _failureOf(
        () => hybrid(online, offline, RoutingMode.onlineOnly).plan(_query),
      );
      expect(failure.kind, RoutingFailureKind.network);
      expect(offline.calls, 0);
    });

    test('offlineOnly: online tidak disentuh', () async {
      final online = RecordingPlanner.returns(onlineRoute);
      final offline = RecordingPlanner.returns(offlineRoute);
      final result = await hybrid(
        online,
        offline,
        RoutingMode.offlineOnly,
      ).plan(_query);
      expect(result.single.source, RouteSource.offline);
      expect(online.calls, 0);
    });

    test('mod dibaca pada setiap permintaan (bertukar serta-merta)', () async {
      var mode = RoutingMode.auto;
      final online = RecordingPlanner.returns(onlineRoute);
      final offline = RecordingPlanner.returns(offlineRoute);
      final planner = HybridRoutePlanner(
        online: online,
        offline: offline,
        mode: () => mode,
      );

      expect((await planner.plan(_query)).single.source, RouteSource.online);
      mode = RoutingMode.offlineOnly;
      expect((await planner.plan(_query)).single.source, RouteSource.offline);
    });
  });
}

class _FakeEngine implements OfflineEngine {
  final List<String> opened = [];
  final List<String> requests = [];
  String response = '{}';
  ValhallaEngineException? openError;
  ValhallaEngineException? routeError;

  @override
  Future<void> open(String tarPath) async {
    if (openError != null) throw openError!;
    opened.add(tarPath);
  }

  @override
  Future<String> route(String requestJson) async {
    requests.add(requestJson);
    if (routeError != null) throw routeError!;
    return response;
  }

  @override
  Future<String> traceAttributes(String requestJson) async => '{}';

  @override
  Future<void> close() async {}
}
