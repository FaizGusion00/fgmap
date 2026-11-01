import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fgmap/features/offline_maps/data/offline_engine_host.dart';
import 'package:fgmap/features/offline_maps/data/offline_map_installer.dart';
import 'package:fgmap/features/offline_maps/data/offline_map_store.dart';
import 'package:fgmap/features/offline_maps/domain/offline_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pack_server.dart';

class _Engine implements OfflineEngine {
  final List<String> log = [];

  @override
  Future<void> open(String tarPath) async => log.add('open');

  @override
  Future<String> route(String requestJson) async => '{}';

  @override
  Future<String> traceAttributes(String requestJson) async => '{}';

  @override
  Future<void> close() async => log.add('close');
}

Future<OfflineMapException> _expectFailure(
  Future<Object?> Function() action,
) async {
  try {
    await action();
  } on OfflineMapException catch (e) {
    return e;
  }
  fail('dijangka OfflineMapException');
}

void main() {
  late Directory dir;
  late OfflineMapStore store;
  late _Engine engine;
  late OfflineEngineHost host;
  late OfflineMapInstaller installer;
  late FakePack pack;
  late PackServer server;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fg_installer_');
    store = OfflineMapStore(Directory('${dir.path}/maps'));
    engine = _Engine();
    host = OfflineEngineHost(engine, store);
    installer = OfflineMapInstaller(dio: Dio(), store: store, host: host);
    pack = FakePack.create();
    server = await PackServer.start(pack);
  });

  tearDown(() async {
    await server.close();
    await dir.delete(recursive: true);
  });

  Future<InstalledMap> install({
    CancelToken? cancel,
    List<(InstallPhase, int, int)>? progress,
    InstallProgress? onProgress,
  }) async {
    final manifest = await installer.fetchManifest(server.manifestUrl);
    return installer.install(
      manifestUrl: server.manifestUrl,
      manifest: manifest,
      cancel: cancel ?? CancelToken(),
      onProgress: (phase, received, total) {
        progress?.add((phase, received, total));
        onProgress?.call(phase, received, total);
      },
    );
  }

  group('indeks carian offline', () {
    test('dipasang bersama pek laluan dan dilaporkan', () async {
      server.places = FakePack.create(rawSize: 60000, seed: 11);
      final m = await install();
      expect(m.placesVersion, pack.version);
      expect(m.placesPath, isNotNull);
      expect(await File(m.placesPath!).length(), 60000);
      expect((await store.readInstalled())!.placesVersion, pack.version);
    });

    test(
      'pek laluan versi sama sudah ada: hanya indeks dimuat turun',
      () async {
        await install();
        expect(server.packRequests, 1);
        server.places = FakePack.create(rawSize: 60000, seed: 11);
        final m = await install();
        expect(
          server.packRequests,
          1,
          reason: 'pek laluan tidak dimuat semula',
        );
        expect(server.placesRequests, 1);
        expect(m.placesVersion, pack.version);
      },
    );

    test(
      'indeks rosak: pek laluan tetap dipasang, carian kekal dalam talian',
      () async {
        server.places = FakePack.create(rawSize: 60000, seed: 11);
        server.placesOverrideBody = Uint8List.fromList(List.filled(100, 1));
        final m = await install();
        expect(m.version, pack.version);
        expect(m.placesVersion, isNull);
        expect(await store.readInstalled(), isNotNull);
      },
    );

    test(
      'manifest dengan entri indeks tidak sah: diabaikan, pek laluan sah',
      () {
        final json = pack.manifestJson()
          ..['places'] = {'file': '../x', 'sizeBytes': 1};
        final m = OfflineManifest.fromJson(json);
        expect(m.places, isNull);
        expect(m.version, pack.version);
      },
    );
  });

  group('paparan peta offline (PMTiles)', () {
    test('dipasang bersama pek laluan, dilaporkan dan dibaca semula', () async {
      server.basemap = FakePack.create(rawSize: 90000, seed: 21);
      final m = await install();
      expect(m.basemapVersion, pack.version);
      expect(m.basemapPath, endsWith('basemap-${pack.version}.pmtiles'));
      expect(await File(m.basemapPath!).readAsBytes(), server.basemap!.raw);
      final again = (await store.readInstalled())!;
      expect(again.basemapVersion, pack.version);
      expect(again.basemapSizeBytes, 90000);
      expect(
        File('${store.dir.path}/basemap.part').existsSync(),
        isFalse,
        reason: 'fail separa dibuang selepas dipasang',
      );
    });

    test(
      'pek laluan versi sama sudah ada: hanya paparan peta dimuat turun',
      () async {
        await install();
        server.basemap = FakePack.create(rawSize: 90000, seed: 21);
        final m = await install();
        expect(
          server.packRequests,
          1,
          reason: 'pek laluan tidak dimuat semula',
        );
        expect(server.basemapRequests, 1);
        expect(m.basemapVersion, pack.version);
      },
    );

    test('versi sama dipasang: tiada muat turun semula', () async {
      server.basemap = FakePack.create(rawSize: 90000, seed: 21);
      await install();
      await install();
      expect(server.basemapRequests, 1);
    });

    test(
      'fail rosak: pek laluan tetap dipasang, paparan peta kekal dalam talian',
      () async {
        server.basemap = FakePack.create(rawSize: 90000, seed: 21);
        server.basemapOverrideBody = Uint8List.fromList(List.filled(90000, 7));
        final m = await install();
        expect(m.version, pack.version);
        expect(m.basemapVersion, isNull);
        expect(File('${store.dir.path}/basemap.part').existsSync(), isFalse);
        expect(await store.readInstalled(), isNotNull);
      },
    );

    test(
      'sambungan terputus: bait diterima dikekalkan dan disambung dengan Range',
      () async {
        final bm = FakePack.create(rawSize: 200000, seed: 21);
        server.basemap = bm;
        server.basemapDropAfterBytes = 40000;
        final first = await install();
        expect(
          first.version,
          pack.version,
          reason: 'pek laluan tidak terjejas',
        );
        expect(first.basemapVersion, isNull);
        final part = File('${store.dir.path}/basemap.part');
        expect(part.existsSync(), isTrue);
        final partial = part.lengthSync();
        expect(partial, greaterThan(0));
        expect(partial, lessThan(200000));

        final second = await install();
        expect(server.basemapRangeHeaders.last, 'bytes=$partial-');
        expect(second.basemapVersion, pack.version);
        expect(await File(second.basemapPath!).readAsBytes(), bm.raw);
      },
    );

    test('versi baharu menggantikan fail lama', () async {
      server.basemap = FakePack.create(rawSize: 50000, seed: 21);
      final v1 = await install();
      final oldPath = v1.basemapPath!;
      server.pack = FakePack.create(version: '20261102', seed: 9);
      server.basemap = FakePack.create(rawSize: 60000, seed: 22);
      final v2 = await install();
      expect(v2.basemapVersion, '20261102');
      expect(File(oldPath).existsSync(), isFalse);
      expect(await File(v2.basemapPath!).length(), 60000);
    });

    test(
      'dibatalkan: dilempar semula, bukan ditelan sebagai kegagalan paparan peta',
      () async {
        server.basemap = FakePack.create(rawSize: 400000, seed: 21);
        server.chunkDelay = const Duration(milliseconds: 10);
        final token = CancelToken();
        final e = await _expectFailure(
          () => install(
            cancel: token,
            onProgress: (phase, received, total) {
              if (total == 400000 &&
                  phase == InstallPhase.downloading &&
                  received > 30000 &&
                  !token.isCancelled) {
                token.cancel('test');
              }
            },
          ),
        );
        expect(e.kind, OfflineMapFailure.cancelled);
        expect(File('${store.dir.path}/basemap.part').existsSync(), isTrue);
      },
    );

    test('padam: fail paparan peta dan aset gaya dibuang', () async {
      server.basemap = FakePack.create(rawSize: 50000, seed: 21);
      final m = await install();
      await store.styleAssetsDir.create(recursive: true);
      await store.deleteInstalled();
      expect(File(m.basemapPath!).existsSync(), isFalse);
      expect(store.styleAssetsDir.existsSync(), isFalse);
      expect(await store.readInstalled(), isNull);
    });

    test(
      'fail dipotong pada cakera: tidak dilaporkan sebagai dipasang',
      () async {
        server.basemap = FakePack.create(rawSize: 50000, seed: 21);
        final m = await install();
        await File(m.basemapPath!).writeAsBytes(List.filled(10, 0));
        final again = (await store.readInstalled())!;
        expect(again.basemapVersion, isNull);
        expect(again.version, pack.version);
      },
    );

    test(
      'manifest: entri tidak sah diabaikan; jumlah muat turun merangkumi paparan peta',
      () {
        final good = pack.manifestJson()
          ..['basemap'] = {
            'file': 'basemap-20261026.pmtiles',
            'sizeBytes': 500,
            'sha256': 'a' * 64,
            'maxZoom': 14,
            'schema': 1,
          };
        final m = OfflineManifest.fromJson(good);
        expect(m.basemap!.maxZoom, 14);
        expect(m.totalDownloadBytes, pack.gz.length + 500);

        for (final bad in <Map<String, Object?>>[
          {
            'file': '../x.pmtiles',
            'sizeBytes': 5,
            'sha256': 'a' * 64,
            'maxZoom': 14,
            'schema': 1,
          },
          {
            'file': 'x.tar.gz',
            'sizeBytes': 5,
            'sha256': 'a' * 64,
            'maxZoom': 14,
            'schema': 1,
          },
          {
            'file': 'x.pmtiles',
            'sizeBytes': 0,
            'sha256': 'a' * 64,
            'maxZoom': 14,
            'schema': 1,
          },
          {
            'file': 'x.pmtiles',
            'sizeBytes': 5,
            'sha256': 'zz',
            'maxZoom': 14,
            'schema': 1,
          },
          {
            'file': 'x.pmtiles',
            'sizeBytes': 5,
            'sha256': 'a' * 64,
            'maxZoom': 99,
            'schema': 1,
          },
          {
            'file': 'x.pmtiles',
            'sizeBytes': 5,
            'sha256': 'a' * 64,
            'maxZoom': 14,
            'schema': 2,
          },
        ]) {
          final parsed = OfflineManifest.fromJson(
            pack.manifestJson()..['basemap'] = bad,
          );
          expect(parsed.basemap, isNull, reason: '$bad');
          expect(parsed.version, pack.version);
        }
      },
    );
  });

  group('fetchManifest', () {
    test('manifest sah', () async {
      final m = await installer.fetchManifest(server.manifestUrl);
      expect(m.version, '20261026');
      expect(m.sizeBytes, pack.gz.length);
    });

    test('URL kosong -> notConfigured, tiada rangkaian', () async {
      final e = await _expectFailure(() => installer.fetchManifest(''));
      expect(e.kind, OfflineMapFailure.notConfigured);
      expect(server.manifestRequests, 0);
    });

    test('versi Valhalla tidak serasi -> incompatible', () async {
      server.manifestOverride = pack.manifestJson(valhalla: '3.5.1');
      final e = await _expectFailure(
        () => installer.fetchManifest(server.manifestUrl),
      );
      expect(e.kind, OfflineMapFailure.incompatible);
    });

    test('manifest dengan nama fail berbahaya -> manifestInvalid', () async {
      server.manifestOverride = pack.manifestJson()
        ..['file'] = '../../etc/passwd';
      final e = await _expectFailure(
        () => installer.fetchManifest(server.manifestUrl),
      );
      expect(e.kind, OfflineMapFailure.manifestInvalid);
    });

    test('badan bukan JSON (cth. halaman portal) -> manifestInvalid', () async {
      server.manifestRaw = '<html>captive portal</html>';
      final e = await _expectFailure(
        () => installer.fetchManifest(server.manifestUrl),
      );
      expect(e.kind, OfflineMapFailure.manifestInvalid);
    });

    test('404 -> network', () async {
      server.manifestStatus = 404;
      final e = await _expectFailure(
        () => installer.fetchManifest(server.manifestUrl),
      );
      expect(e.kind, OfflineMapFailure.network);
    });

    test('pelayan tidak dapat dicapai -> network', () async {
      final url = server.manifestUrl;
      await server.close();
      final e = await _expectFailure(() => installer.fetchManifest(url));
      expect(e.kind, OfflineMapFailure.network);
    });
  });

  group('install', () {
    test(
      'muat turun, sahkan, ekstrak dan pasang: kandungan sama bait demi bait',
      () async {
        final progress = <(InstallPhase, int, int)>[];
        final installed = await install(progress: progress);

        expect(installed.version, '20261026');
        expect(installed.sizeBytes, pack.raw.length);
        expect(File(installed.tarPath).readAsBytesSync(), pack.raw);

        // Fasa berurutan dan kemajuan muat turun berakhir pada jumlah penuh.
        final phases = progress.map((p) => p.$1).toSet();
        expect(phases, {
          InstallPhase.downloading,
          InstallPhase.verifying,
          InstallPhase.installing,
        });
        final downloads = progress
            .where((p) => p.$1 == InstallPhase.downloading)
            .toList();
        expect(downloads.last.$2, pack.gz.length);
        expect(
          downloads.map((p) => p.$2).toList(),
          orderedEquals(List.of(downloads.map((p) => p.$2))..sort()),
          reason: 'kemajuan tidak boleh berundur',
        );

        // Tiada fail sementara tertinggal.
        expect(store.partFile.existsSync(), isFalse);
        expect(store.tmpTar.existsSync(), isFalse);
        expect(await store.readInstalled(), isNotNull);
      },
    );

    test('mengganti pek lama: enjin yang sedang dibuka ditutup DAHULU', () async {
      await install();
      await host.route('{}'); // enjin kini membuka pek lama
      engine.log.clear();
      final newer = FakePack.create(version: '20261101', seed: 99);
      server.pack = newer;

      await install();

      expect(
        engine.log,
        ['close'],
        reason:
            'ditutup sebelum fail dimmap diganti; dibuka semula hanya bila perlu',
      );
      final installed = (await store.readInstalled())!;
      expect(installed.version, '20261101');
      expect(File(installed.tarPath).readAsBytesSync(), newer.raw);
    });

    test('gagal di tengah tidak merosakkan pek yang sedang aktif', () async {
      final first = await install();
      final before = File(first.tarPath).readAsBytesSync();

      final newer = FakePack.create(version: '20261101', seed: 5);
      server
        ..pack = newer
        ..overrideBody = Uint8List.fromList(List.of(newer.gz)..[100] ^= 0xff);

      final e = await _expectFailure(install);
      expect(e.kind, OfflineMapFailure.checksum);

      final still = (await store.readInstalled())!;
      expect(still.version, '20261026', reason: 'pek lama kekal sah');
      expect(File(still.tarPath).readAsBytesSync(), before);
    });

    test('bait rosak (saiz sama) -> checksum, fail separa dibuang', () async {
      final corrupted = List.of(pack.gz)..[pack.gz.length ~/ 2] ^= 0x55;
      server.overrideBody = Uint8List.fromList(corrupted);

      final e = await _expectFailure(install);
      expect(e.kind, OfflineMapFailure.checksum);
      expect(store.partFile.existsSync(), isFalse);
      expect(await store.readInstalled(), isNull);
    });

    test(
      'pelayan menghantar lebih daripada saiz manifest -> checksum',
      () async {
        server.overrideBody = Uint8List.fromList([...pack.gz, 1, 2, 3]);
        final e = await _expectFailure(install);
        expect(e.kind, OfflineMapFailure.checksum);
        expect(store.partFile.existsSync(), isFalse);
      },
    );

    test('404 pada pek -> network', () async {
      server.packStatus = 404;
      final e = await _expectFailure(install);
      expect(e.kind, OfflineMapFailure.network);
    });

    test('hasil ekstrak tidak sepadan dengan manifest -> checksum', () async {
      // Pek termampat sah (sha256 betul) tetapi manifest menyatakan sha256 hasil ekstrak yang salah.
      server.manifestOverride = pack.manifestJson()
        ..['extractedSha256'] = 'c' * 64;
      final e = await _expectFailure(install);
      expect(e.kind, OfflineMapFailure.checksum);
      expect(await store.readInstalled(), isNull);
      expect(store.tmpTar.existsSync(), isFalse);
    });

    test(
      'gzip rosak yang sha256-nya sepadan (pek terbit rosak) -> gagal bersih, tiada pek separuh',
      () async {
        final badGz = Uint8List.fromList(List.filled(1000, 0x41)); // bukan gzip
        final badPack = FakePack.create();
        server.overrideBody = badGz;
        server.manifestOverride = badPack.manifestJson()
          ..['sizeBytes'] = badGz.length
          ..['sha256'] = sha256.convert(badGz).toString();

        final failure = await _expectFailureAny(install);
        expect(failure, isNotNull);
        expect(await store.readInstalled(), isNull);
      },
    );

    test(
      'dibatalkan semasa muat turun -> cancelled; fail separa dikekalkan untuk disambung',
      () async {
        server.chunkDelay = const Duration(milliseconds: 15);
        final cancel = CancelToken();
        final e = await _expectFailure(
          () => install(
            cancel: cancel,
            onProgress: (phase, received, total) {
              if (phase == InstallPhase.downloading &&
                  received >= pack.gz.length ~/ 4 &&
                  !cancel.isCancelled) {
                cancel.cancel('test');
              }
            },
          ),
        );
        expect(e.kind, OfflineMapFailure.cancelled);
        expect(store.partFile.existsSync(), isTrue);
        expect(store.partFile.lengthSync(), lessThan(pack.gz.length));
        expect(await store.readInstalled(), isNull);
      },
    );

    test(
      'terputus kemudian disambung dengan Range: hanya baki dimuat turun',
      () async {
        server.dropAfterBytes = pack.gz.length ~/ 3;
        final e = await _expectFailure(install);
        expect(e.kind, OfflineMapFailure.network);
        final partial = store.partFile.lengthSync();
        expect(partial, greaterThan(0));
        expect(partial, lessThan(pack.gz.length));

        server.rangeHeaders.clear();
        final installed = await install();

        expect(server.rangeHeaders, [
          'bytes=$partial-',
        ], reason: 'menyambung, bukan bermula semula');
        expect(File(installed.tarPath).readAsBytesSync(), pack.raw);
      },
    );

    test(
      'pelayan mengabaikan Range (200) -> bermula semula dari awal, hasil tetap betul',
      () async {
        server.dropAfterBytes = pack.gz.length ~/ 3;
        await _expectFailure(install);
        expect(store.partFile.lengthSync(), greaterThan(0));

        server.ignoreRange = true;
        final installed = await install();
        expect(File(installed.tarPath).readAsBytesSync(), pack.raw);
      },
    );

    test('fail separa milik pek lain tidak disambung', () async {
      server.dropAfterBytes = pack.gz.length ~/ 3;
      await _expectFailure(install);

      final newer = FakePack.create(version: '20261101', seed: 3);
      server.pack = newer;
      server.rangeHeaders.clear();
      final installed = await install();

      expect(server.rangeHeaders, [
        null,
      ], reason: 'tiada Range kerana fail separa lama dibuang');
      expect(File(installed.tarPath).readAsBytesSync(), newer.raw);
    });

    test('fail separa yang sudah lengkap tidak dimuat turun semula', () async {
      server.chunkDelay = Duration.zero;
      await store.ensureDir();
      store.partFile.writeAsBytesSync(pack.gz);
      await store.markPartial(
        pack.version,
        pack.manifestJson()['sha256']! as String,
      );

      final installed = await install();
      expect(server.packRequests, 0);
      expect(File(installed.tarPath).readAsBytesSync(), pack.raw);
    });
  });
}

Future<Object?> _expectFailureAny(Future<Object?> Function() action) async {
  try {
    await action();
  } on Object catch (e) {
    return e;
  }
  fail('dijangka kegagalan');
}
