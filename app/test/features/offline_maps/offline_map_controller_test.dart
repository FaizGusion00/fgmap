import 'dart:io';
import 'dart:typed_data';

import 'package:fgmap/features/offline_maps/data/offline_engine_host.dart';
import 'package:fgmap/features/offline_maps/data/offline_map_store.dart';
import 'package:fgmap/features/offline_maps/domain/offline_models.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_map_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pack_server.dart';

class _Engine implements OfflineEngine {
  final List<String> log = [];

  @override
  Future<void> open(String tarPath) async => log.add('open');

  @override
  Future<String> route(String requestJson) async => '{}';

  @override
  Future<void> close() async => log.add('close');
}

void main() {
  late Directory dir;
  late OfflineMapStore store;
  late _Engine engine;
  late FakePack pack;
  late PackServer server;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fg_ctrl_');
    store = OfflineMapStore(Directory('${dir.path}/maps'));
    engine = _Engine();
    pack = FakePack.create();
    server = await PackServer.start(pack);
  });

  tearDown(() async {
    await server.close();
    await dir.delete(recursive: true);
  });

  ProviderContainer container({String? manifestUrl}) {
    final c = ProviderContainer(
      overrides: [
        offlineMapStoreProvider.overrideWithValue(store),
        offlineEngineProvider.overrideWithValue(engine),
        offlineManifestUrlProvider.overrideWithValue(
          manifestUrl ?? server.manifestUrl,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Menunggu `refresh()` awal (microtask + rangkaian) selesai.
  Future<OfflineMapState> settled(ProviderContainer c) async {
    c.read(offlineMapControllerProvider);
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final s = c.read(offlineMapControllerProvider);
      if (!s.busy && (!s.configured || s.latest != null || i > 20)) return s;
    }
    fail(
      'controller tidak menjadi tenang: ${c.read(offlineMapControllerProvider).op}',
    );
  }

  test(
    'tidak dikonfigurasi: tiada rangkaian dan tidak boleh muat turun',
    () async {
      final c = container(manifestUrl: '');
      final s = await settled(c);
      expect(s.configured, isFalse);
      expect(s.canDownload, isFalse);
      expect(server.manifestRequests, 0);

      await c.read(offlineMapControllerProvider.notifier).refresh();
      expect(server.manifestRequests, 0);
    },
  );

  test(
    'dikonfigurasi, belum dipasang: manifest terkini diketahui dan boleh muat turun',
    () async {
      final s = await settled(container());
      expect(s.configured, isTrue);
      expect(s.installed, isNull);
      expect(s.latest!.version, '20261026');
      expect(s.canDownload, isTrue);
      expect(s.updateAvailable, isFalse);
    },
  );

  test('muat turun penuh: kemajuan menaik dan berakhir terpasang', () async {
    final c = container();
    await settled(c);

    final seen = <OfflineMapState>[];
    c.listen(offlineMapControllerProvider, (_, next) => seen.add(next));
    await c.read(offlineMapControllerProvider.notifier).download();

    final ops = seen.map((s) => s.op).toList();
    expect(
      ops,
      containsAllInOrder([
        OfflineOp.checking,
        OfflineOp.downloading,
        OfflineOp.verifying,
        OfflineOp.installing,
        OfflineOp.idle,
      ]),
    );
    final progress = seen
        .where((s) => s.progress != null)
        .map((s) => s.progress!)
        .toList();
    expect(progress, isNotEmpty);
    expect(progress, orderedEquals(List.of(progress)..sort()));
    expect(progress.last, 1.0);

    final done = c.read(offlineMapControllerProvider);
    expect(done.installed!.version, '20261026');
    expect(done.error, isNull);
    expect(done.canDownload, isFalse, reason: 'sudah terkini');
    expect(File(done.installed!.tarPath).readAsBytesSync(), pack.raw);
  });

  test('pek sedia ada dikesan semasa mula (tanpa muat turun)', () async {
    final c1 = container();
    await settled(c1);
    await c1.read(offlineMapControllerProvider.notifier).download();

    final c2 = container();
    final s = await settled(c2);
    expect(s.installed!.version, '20261026');
    expect(s.canDownload, isFalse);
  });

  test('kemas kini: pek lebih baharu ditandakan dan diganti', () async {
    final c = container();
    await settled(c);
    await c.read(offlineMapControllerProvider.notifier).download();

    server.pack = FakePack.create(version: '20261101', seed: 11);
    await c.read(offlineMapControllerProvider.notifier).refresh();
    var s = c.read(offlineMapControllerProvider);
    expect(s.updateAvailable, isTrue);
    expect(s.canDownload, isTrue);

    await c.read(offlineMapControllerProvider.notifier).download();
    s = c.read(offlineMapControllerProvider);
    expect(s.installed!.version, '20261101');
    expect(s.updateAvailable, isFalse);
  });

  test(
    'pek di hos LEBIH LAMA daripada yang dipasang bukan "kemas kini"',
    () async {
      server.pack = FakePack.create(version: '20261101', seed: 11);
      final c = container();
      await settled(c);
      await c.read(offlineMapControllerProvider.notifier).download();

      server.pack = FakePack.create(version: '20261026');
      await c.read(offlineMapControllerProvider.notifier).refresh();
      final s = c.read(offlineMapControllerProvider);
      expect(s.updateAvailable, isFalse);
      expect(s.canDownload, isFalse);
    },
  );

  test(
    'semakan manifest gagal secara senyap: tiada ralat dan pek sedia ada kekal',
    () async {
      final c = container();
      await settled(c);
      await c.read(offlineMapControllerProvider.notifier).download();

      server.manifestStatus = 503;
      await c.read(offlineMapControllerProvider.notifier).refresh();
      final s = c.read(offlineMapControllerProvider);
      expect(
        s.error,
        isNull,
        reason: 'pengguna tanpa internet masih boleh menggunakan pek sedia ada',
      );
      expect(s.installed, isNotNull);
      expect(s.busy, isFalse);
    },
  );

  group('kegagalan muat turun dilaporkan dan tidak merosakkan keadaan', () {
    test('checksum', () async {
      final c = container();
      await settled(c);
      server.overrideBody = Uint8List.fromList([...pack.gz]..[10] ^= 0xff);
      await c.read(offlineMapControllerProvider.notifier).download();
      final s = c.read(offlineMapControllerProvider);
      expect(s.error, OfflineMapFailure.checksum);
      expect(s.op, OfflineOp.idle);
      expect(s.installed, isNull);
      expect(s.canDownload, isTrue, reason: 'boleh cuba lagi');
    });

    test('rangkaian terputus', () async {
      final c = container();
      await settled(c);
      server.dropAfterBytes = pack.gz.length ~/ 2;
      await c.read(offlineMapControllerProvider.notifier).download();
      expect(
        c.read(offlineMapControllerProvider).error,
        OfflineMapFailure.network,
      );
    });

    test('versi enjin tidak serasi', () async {
      final c = container();
      await settled(c);
      server.manifestOverride = pack.manifestJson(valhalla: '3.5.1');
      await c.read(offlineMapControllerProvider.notifier).download();
      expect(
        c.read(offlineMapControllerProvider).error,
        OfflineMapFailure.incompatible,
      );
    });

    test(
      'ralat dibuang bila percubaan seterusnya bermula dan berjaya',
      () async {
        final c = container();
        await settled(c);
        server.dropAfterBytes = pack.gz.length ~/ 2;
        await c.read(offlineMapControllerProvider.notifier).download();
        expect(c.read(offlineMapControllerProvider).error, isNotNull);

        await c.read(offlineMapControllerProvider.notifier).download();
        final s = c.read(offlineMapControllerProvider);
        expect(s.error, isNull);
        expect(s.installed, isNotNull);
      },
    );
  });

  test(
    'batal: tiada ralat dipaparkan, kembali idle, boleh disambung',
    () async {
      server.chunkDelay = const Duration(milliseconds: 20);
      final c = container();
      await settled(c);
      final notifier = c.read(offlineMapControllerProvider.notifier);

      final future = notifier.download();
      for (
        var i = 0;
        i < 200 &&
            c.read(offlineMapControllerProvider).op != OfflineOp.downloading;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      notifier.cancel();
      await future;

      final s = c.read(offlineMapControllerProvider);
      expect(s.error, isNull);
      expect(s.op, OfflineOp.idle);
      expect(s.installed, isNull);
    },
  );

  test('download() berganda serentak: hanya satu muat turun', () async {
    server.chunkDelay = const Duration(milliseconds: 5);
    final c = container();
    await settled(c);
    final notifier = c.read(offlineMapControllerProvider.notifier);

    await Future.wait([
      notifier.download(),
      notifier.download(),
      notifier.download(),
    ]);

    expect(server.packRequests, 1);
    expect(c.read(offlineMapControllerProvider).installed, isNotNull);
  });

  test('padam: enjin ditutup, fail dan muat turun separa dibuang', () async {
    final c = container();
    await settled(c);
    await c.read(offlineMapControllerProvider.notifier).download();
    await c
        .read(offlineEngineHostProvider)
        .route('{}'); // enjin dibuka terhadap pek
    engine.log.clear();

    await c.read(offlineMapControllerProvider.notifier).delete();

    expect(engine.log, ['close']);
    expect(c.read(offlineMapControllerProvider).installed, isNull);
    expect(await store.readInstalled(), isNull);
    expect(File('${store.dir.path}/valhalla_tiles.tar').existsSync(), isFalse);
    expect(
      c.read(offlineMapControllerProvider).canDownload,
      isTrue,
      reason: 'boleh dimuat turun semula',
    );
  });
}
