import 'dart:convert';
import 'dart:io';

import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/features/map/domain/local_basemap_style.dart';
import 'package:fgmap/features/offline_maps/data/local_basemap.dart';
import 'package:fgmap/features/offline_maps/data/offline_engine_host.dart';
import 'package:fgmap/features/offline_maps/data/offline_map_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late OfflineMapStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fg_basemap_');
    store = OfflineMapStore(Directory('${dir.path}/Offline Maps'));
    await store.ensureDir();
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> installFakeBasemap({String version = '20261101'}) async {
    final tar = File('${store.dir.path}/t.tmp')..writeAsBytesSync([1, 2, 3]);
    await store.install(tar, version: version, sizeBytes: 3);
    final part = File('${store.dir.path}/b.tmp')
      ..writeAsBytesSync(List.filled(64, 9));
    await store.installBasemap(part, version: version, sizeBytes: 64);
  }

  group('LocalBasemapAssets', () {
    test(
      'menyalin fon (nama dengan ruang), sprite; julat lain dijana kosong',
      () async {
        final target = await LocalBasemapAssets(
          rootBundle,
        ).ensure(store.styleAssetsDir);

        // Nama folder fon ialah nama susun fon sebenar yang diminta MapLibre (dengan ruang).
        for (final stack in LocalBasemapStyle.fontStacks) {
          final d = Directory('$target/fonts/$stack');
          expect(d.existsSync(), isTrue, reason: stack);
          expect(
            d.listSync().length,
            256,
            reason: 'setiap julat Unicode ada fail',
          );
          for (final range in LocalBasemapStyle.bundledGlyphRanges) {
            expect(
              File('${d.path}/$range.pbf').lengthSync(),
              greaterThan(1000),
            );
          }
          expect(
            File('${d.path}/19968-20223.pbf').readAsBytesSync(),
            LocalBasemapStyle.emptyGlyphRange(stack, '19968-20223'),
          );
        }
        for (final f in ['ofm.json', 'ofm.png', 'ofm@2x.json', 'ofm@2x.png']) {
          expect(File('$target/sprite/$f').existsSync(), isTrue, reason: f);
        }
        expect(File('$target/liberty.json').existsSync(), isFalse);
        expect(File('$target/LICENSE-map.txt').existsSync(), isFalse);
        expect(File('$target/.ready').existsSync(), isTrue);
      },
    );

    test(
      'panggilan kedua tidak menyalin semula; salinan separa dijana semula',
      () async {
        final assets = LocalBasemapAssets(rootBundle);
        final target = await assets.ensure(store.styleAssetsDir);
        final probe = File('$target/sprite/ofm.json');
        probe.writeAsStringSync('ditandai');
        await assets.ensure(store.styleAssetsDir);
        expect(probe.readAsStringSync(), 'ditandai', reason: 'tidak ditimpa');

        // Penanda hilang (cth. app dimatikan di tengah menyalin): semua dijana semula.
        File('$target/.ready').deleteSync();
        await assets.ensure(store.styleAssetsDir);
        expect(probe.readAsStringSync(), isNot('ditandai'));
        expect(File('$target/.ready').existsSync(), isTrue);
      },
    );

    test('panggilan serentak berkongsi satu kerja', () async {
      final assets = LocalBasemapAssets(rootBundle);
      final results = await Future.wait([
        assets.ensure(store.styleAssetsDir),
        assets.ensure(store.styleAssetsDir),
        assets.ensure(store.styleAssetsDir),
      ]);
      expect(results.toSet().length, 1);
      expect(File('${results.first}/.ready').existsSync(), isTrue);
    });
  });

  group('localBasemapProvider dan gaya peta', () {
    ProviderContainer container({bool withStore = true}) {
      final c = ProviderContainer(
        overrides: [
          if (withStore) offlineMapStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'tiada storan peta (ujian/persekitaran): null, gaya dalam talian',
      () async {
        final c = container(withStore: false);
        expect(await c.read(localBasemapProvider.future), isNull);
        final style = await c.read(mapStyleProvider(false).future);
        expect(style.isJson, isFalse);
      },
    );

    test('pek dipasang tanpa paparan peta: null, gaya dalam talian', () async {
      final tar = File('${store.dir.path}/t.tmp')..writeAsBytesSync([1, 2, 3]);
      await store.install(tar, version: '20261101', sizeBytes: 3);
      final c = container();
      expect(await c.read(localBasemapProvider.future), isNull);
      expect((await c.read(mapStyleProvider(false).future)).isJson, isFalse);
    });

    test(
      'paparan peta dipasang: gaya cerah dan malam dibina daripada fail tempatan',
      () async {
        await installFakeBasemap();
        final c = container();
        final bm = (await c.read(localBasemapProvider.future))!;
        expect(bm.version, '20261101');
        expect(bm.pmtilesPath, endsWith('basemap-20261101.pmtiles'));
        expect(Directory(bm.assetsDir).existsSync(), isTrue);

        final light = await c.read(mapStyleProvider(false).future);
        expect(light.key, 'local:20261101:light');
        expect(light.isJson, isTrue);
        final lj = jsonDecode(light.style) as Map<String, dynamic>;
        expect(
          ((lj['sources'] as Map)['openmaptiles'] as Map)['url'],
          startsWith('pmtiles://file:///'),
        );
        expect(lj['glyphs'], contains('Offline%20Maps'));

        final dark = await c.read(mapStyleProvider(true).future);
        expect(dark.key, 'local:20261101:night');
        expect(dark.style, isNot(light.style), reason: 'diwarnakan malam');
      },
    );

    test(
      'dipasang/dipadam: gaya dibina semula selepas localBasemapProvider dibatalkan',
      () async {
        final c = container();
        expect((await c.read(mapStyleProvider(false).future)).isJson, isFalse);

        await installFakeBasemap();
        c.invalidate(localBasemapProvider);
        expect(
          (await c.read(mapStyleProvider(false).future)).key,
          'local:20261101:light',
        );

        await store.deleteInstalled();
        c.invalidate(localBasemapProvider);
        expect((await c.read(mapStyleProvider(false).future)).isJson, isFalse);
      },
    );
  });
}
