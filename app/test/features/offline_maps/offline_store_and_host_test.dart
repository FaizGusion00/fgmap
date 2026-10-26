import 'dart:async';
import 'dart:io';

import 'package:fgmap/features/offline_maps/data/offline_engine_host.dart';
import 'package:fgmap/features/offline_maps/data/offline_map_store.dart';
import 'package:fgmap_valhalla/fgmap_valhalla.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingEngine implements OfflineEngine {
  final List<String> log = [];
  Completer<void>? openGate;
  Object? closeError;

  @override
  Future<void> open(String tarPath) async {
    log.add('open:${tarPath.split('/').last}');
    await openGate?.future;
  }

  @override
  Future<String> route(String requestJson) async {
    log.add('route');
    return '{}';
  }

  @override
  Future<void> close() async {
    log.add('close');
    if (closeError != null) throw closeError!;
  }
}

Future<void> _install(
  OfflineMapStore store,
  Directory dir, {
  String version = '20261026',
  int size = 8,
}) async {
  await store.ensureDir();
  final tmp = File('${dir.path}/t.tmp')..writeAsBytesSync(List.filled(size, 1));
  await store.install(tmp, version: version, sizeBytes: size);
}

void main() {
  late Directory dir;
  late OfflineMapStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fg_store_');
    store = OfflineMapStore(Directory('${dir.path}/maps'));
  });
  tearDown(() => dir.delete(recursive: true));

  group('OfflineMapStore', () {
    test('direktori belum wujud -> tiada pek', () async {
      expect(await store.readInstalled(), isNull);
    });

    test('install kemudian readInstalled', () async {
      await _install(store, store.dir, version: '20261026', size: 16);
      final installed = (await store.readInstalled())!;
      expect(installed.version, '20261026');
      expect(installed.sizeBytes, 16);
      expect(File(installed.tarPath).lengthSync(), 16);
    });

    test('install menggantikan pek lama', () async {
      await _install(store, store.dir, version: '20261001', size: 8);
      await _install(store, store.dir, version: '20261026', size: 12);
      final installed = (await store.readInstalled())!;
      expect(installed.version, '20261026');
      expect(File(installed.tarPath).lengthSync(), 12);
    });

    test('fail dipotong (saiz tidak sepadan metadata) -> tiada pek', () async {
      await _install(store, store.dir, size: 100);
      File(
        '${store.dir.path}/valhalla_tiles.tar',
      ).writeAsBytesSync(List.filled(40, 1));
      expect(await store.readInstalled(), isNull);
    });

    test('metadata hilang atau rosak -> tiada pek', () async {
      await _install(store, store.dir);
      File('${store.dir.path}/installed.json').writeAsStringSync('{bukan json');
      expect(await store.readInstalled(), isNull);

      File(
        '${store.dir.path}/installed.json',
      ).writeAsStringSync('{"version": 5}');
      expect(await store.readInstalled(), isNull);

      File('${store.dir.path}/installed.json').deleteSync();
      expect(await store.readInstalled(), isNull);
    });

    test('deleteInstalled membuang pek dan metadata', () async {
      await _install(store, store.dir);
      await store.deleteInstalled();
      expect(await store.readInstalled(), isNull);
      expect(
        File('${store.dir.path}/valhalla_tiles.tar').existsSync(),
        isFalse,
      );
      await store.deleteInstalled(); // idempotent
    });

    test(
      'muat turun separa: hanya digunakan semula untuk versi dan sha256 yang SAMA',
      () async {
        await store.ensureDir();
        store.partFile.writeAsBytesSync(List.filled(50, 9));
        await store.markPartial('20261026', 'a' * 64);

        expect(await store.partialBytesFor('20261026', 'a' * 64), 50);
        expect(store.partFile.existsSync(), isTrue);

        // Pek lain (versi atau sha berbeza): fail separa mesti dibuang, bukan disambung.
        expect(await store.partialBytesFor('20261101', 'a' * 64), 0);
        expect(store.partFile.existsSync(), isFalse);
      },
    );

    test('fail separa tanpa metadata dibuang', () async {
      await store.ensureDir();
      store.partFile.writeAsBytesSync(List.filled(50, 9));
      expect(await store.partialBytesFor('20261026', 'a' * 64), 0);
      expect(store.partFile.existsSync(), isFalse);
    });
  });

  group('OfflineEngineHost', () {
    late _RecordingEngine engine;
    late OfflineEngineHost host;

    setUp(() {
      engine = _RecordingEngine();
      host = OfflineEngineHost(engine, store);
    });

    test(
      'tiada pek -> OfflineEngineUnavailable dan enjin tidak disentuh',
      () async {
        await expectLater(
          host.route('{}'),
          throwsA(isA<OfflineEngineUnavailable>()),
        );
        expect(engine.log, isEmpty);
      },
    );

    test('dibuka sekali dan digunakan semula', () async {
      await _install(store, store.dir);
      await host.route('{}');
      await host.route('{}');
      expect(engine.log, ['open:valhalla_tiles.tar', 'route', 'route']);
    });

    test('dibuka semula bila pek diganti dengan versi lain', () async {
      await _install(store, store.dir, version: '20261001', size: 8);
      await host.route('{}');
      await _install(store, store.dir, version: '20261026', size: 9);
      await host.route('{}');
      expect(engine.log.where((e) => e.startsWith('open')).length, 2);
    });

    test(
      'withEngineClosed menutup enjin DAHULU sebelum tindakan, dan route berikutnya membukanya semula',
      () async {
        await _install(store, store.dir);
        await host.route('{}');
        final order = <String>[];
        await host.withEngineClosed(() async {
          order.add('action:${engine.log.last}'); // close sudah berlaku
        });
        expect(order, ['action:close']);
        await host.route('{}');
        expect(engine.log, [
          'open:valhalla_tiles.tar',
          'route',
          'close',
          'open:valhalla_tiles.tar',
          'route',
        ]);
      },
    );

    test('withEngineClosed tanpa enjin dibuka tidak memanggil close', () async {
      await host.withEngineClosed(() async {});
      expect(engine.log, isEmpty);
    });

    test(
      'operasi disiri: route semasa pembukaan tidak berlumba dengan withEngineClosed',
      () async {
        await _install(store, store.dir);
        engine.openGate = Completer<void>();

        final route = host.route('{}');
        final replace = host.withEngineClosed(
          () async => engine.log.add('replaced'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(engine.log, [
          'open:valhalla_tiles.tar',
        ], reason: 'penggantian menunggu route selesai');

        engine.openGate!.complete();
        await Future.wait([route, replace]);
        expect(engine.log, [
          'open:valhalla_tiles.tar',
          'route',
          'close',
          'replaced',
        ]);
      },
    );

    test('satu kegagalan tidak memutuskan baris gilir', () async {
      await _install(store, store.dir);
      final failing = OfflineEngineHost(_FailingOnce(), store);
      await expectLater(
        failing.route('{}'),
        throwsA(isA<ValhallaEngineException>()),
      );
      expect(await failing.route('{}'), '{}');
    });

    test('ralat semasa menutup enjin tidak menghalang penggantian', () async {
      await _install(store, store.dir);
      await host.route('{}');
      engine.closeError = const ValhallaEngineException('internal', 'x');
      var ran = false;
      await host.withEngineClosed(() async => ran = true);
      expect(ran, isTrue);
    });
  });
}

class _FailingOnce implements OfflineEngine {
  var _failed = false;

  @override
  Future<void> open(String tarPath) async {
    if (!_failed) {
      _failed = true;
      throw const ValhallaEngineException('open_failed', 'first time');
    }
  }

  @override
  Future<String> route(String requestJson) async => '{}';

  @override
  Future<void> close() async {}
}
