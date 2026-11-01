import 'dart:convert';
import 'dart:io';

import 'package:fgmap/features/map/domain/local_basemap_style.dart';
import 'package:fgmap/features/map/domain/night_style.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gaya Liberty sebenar yang dibundel dalam app (aset), bukan gaya sintetik.
Map<String, dynamic> _template() =>
    jsonDecode(File('assets/map/liberty.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  const pmtiles =
      '/data/user/0/app/Application Support/offline_maps/basemap-1.pmtiles';
  const assets =
      '/data/user/0/app/Application Support/offline_maps/map_style/v1';

  String build() => LocalBasemapStyle.build(
    File('assets/map/liberty.json').readAsStringSync(),
    pmtilesPath: pmtiles,
    assetsDir: assets,
  )!;

  test('sumber, fon dan sprite semuanya fail tempatan (tiada URL rangkaian)', () {
    final style = jsonDecode(build()) as Map<String, dynamic>;
    final sources = style['sources'] as Map;
    expect(sources.keys, ['openmaptiles']);
    final url = (sources['openmaptiles'] as Map)['url'] as String;
    expect(url, startsWith('pmtiles://file:///'));
    // Ruang dalam "Application Support" (iOS) dikodkan, bukan dibiarkan mentah.
    expect(url, contains('Application%20Support'));
    expect(style['glyphs'], startsWith('file:///'));
    expect(style['glyphs'], endsWith('/fonts/{fontstack}/{range}.pbf'));
    expect(style['sprite'], startsWith('file:///'));
    expect(style['sprite'], endsWith('/sprite/ofm'));
    // Tiada satu pun URL http(s) dalam gaya yang dihantar kepada MapLibre.
    expect(build(), isNot(contains('http://')));
    expect(
      build().replaceAll('https://openmaptiles.org', ''),
      isNot(contains('https://')),
    );
  });

  test('lapisan raster Natural Earth dibuang; selebihnya kekal', () {
    final before = _template();
    final after = jsonDecode(build()) as Map<String, dynamic>;
    final beforeLayers = before['layers'] as List;
    final afterLayers = after['layers'] as List;
    expect(
      beforeLayers.where((l) => (l as Map)['source'] == 'ne2_shaded'),
      isNotEmpty,
      reason: 'syarat ujian: templat memang ada lapisan raster jauh',
    );
    expect(
      afterLayers.where((l) => (l as Map)['source'] == 'ne2_shaded'),
      isEmpty,
    );
    expect(afterLayers.length, lessThan(beforeLayers.length));
    expect(afterLayers.length, greaterThan(100));
    // Setiap lapisan yang menggunakan sumber, menggunakan sumber yang masih wujud.
    for (final l in afterLayers) {
      final src = (l as Map)['source'];
      if (src != null) expect(src, 'openmaptiles');
    }
  });

  test(
    'setiap susun fon dalam gaya dibundel (tidak ada fon yang tak dapat dimuat)',
    () {
      final used = <String>{};
      for (final l in (_template()['layers'] as List)) {
        final font = ((l as Map)['layout'] as Map?)?['text-font'];
        if (font is List) used.addAll(font.whereType<String>());
      }
      expect(used, isNotEmpty);
      expect(used.difference(LocalBasemapStyle.fontStacks.toSet()), isEmpty);
      for (final stack in LocalBasemapStyle.fontStacks) {
        for (final range in LocalBasemapStyle.bundledGlyphRanges) {
          final f = File(
            'assets/map/fonts/${stack.replaceAll(' ', '_')}/$range.pbf',
          );
          expect(f.existsSync(), isTrue, reason: f.path);
          expect(f.lengthSync(), greaterThan(1000));
        }
      }
    },
  );

  test('ikon sprite bernama (literal) yang dirujuk gaya wujud dalam sprite', () {
    final sprite =
        jsonDecode(File('assets/map/sprite/ofm.json').readAsStringSync())
            as Map;
    final icons = <String>{};
    for (final l in (jsonDecode(build())['layers'] as List)) {
      final v = ((l as Map)['layout'] as Map?)?['icon-image'];
      if (v is String) icons.add(v);
      // ["step", input, keluaran0, titik1, keluaran1, ...]: keluaran ialah nama ikon literal.
      if (v is List && v.first == 'step') {
        for (var i = 2; i < v.length; i += 2) {
          if (v[i] is String && (v[i] as String).isNotEmpty) {
            icons.add(v[i] as String);
          }
        }
      }
    }
    expect(icons, containsAll(['arrow', 'airport_11', 'circle_11_black']));
    for (final name in icons) {
      expect(sprite.containsKey(name), isTrue, reason: name);
    }
  });

  test('gaya malam dapat diwarnakan semula daripada gaya tempatan', () {
    final night = NightStyle.apply(build());
    expect(night, isNotNull, reason: 'file:// dan pmtiles:// mesti diterima');
    final decoded = jsonDecode(night!) as Map<String, dynamic>;
    final bg =
        (decoded['layers'] as List).firstWhere(
              (l) => (l as Map)['type'] == 'background',
            )
            as Map;
    expect(
      (bg['paint'] as Map)['background-color'],
      isNot('#f8f4f0'),
      reason: 'warna latar telah ditukar',
    );
    expect(night, contains('pmtiles://file:///'));
  });

  test('bukan gaya OpenMapTiles / JSON rosak -> null', () {
    expect(
      LocalBasemapStyle.build(
        '{rosak',
        pmtilesPath: pmtiles,
        assetsDir: assets,
      ),
      isNull,
    );
    expect(
      LocalBasemapStyle.build(
        '{"layers":[],"sources":{"lain":{"type":"vector"}}}',
        pmtilesPath: pmtiles,
        assetsDir: assets,
      ),
      isNull,
    );
    expect(
      LocalBasemapStyle.build('[]', pmtilesPath: pmtiles, assetsDir: assets),
      isNull,
    );
  });

  test(
    'julat glyph kosong ialah PBF sah: fontstack dengan nama + julat, tanpa glyph',
    () {
      final bytes = LocalBasemapStyle.emptyGlyphRange(
        'Noto Sans Regular',
        '19968-20223',
      );
      // glyphs { stacks(1) { name(1), range(2) } }
      expect(bytes[0], 0x0a);
      expect(bytes[1], bytes.length - 2);
      expect(bytes[2], 0x0a);
      final nameLen = bytes[3];
      expect(utf8.decode(bytes.sublist(4, 4 + nameLen)), 'Noto Sans Regular');
      expect(bytes[4 + nameLen], 0x12);
      final rangeLen = bytes[5 + nameLen];
      expect(
        utf8.decode(bytes.sublist(6 + nameLen, 6 + nameLen + rangeLen)),
        '19968-20223',
      );
      expect(bytes.length, 6 + nameLen + rangeLen);
    },
  );

  test(
    'semua 256 julat glyph dijana, bermula 0-255 dan berakhir 65280-65535',
    () {
      final all = LocalBasemapStyle.allGlyphRanges.toList();
      expect(all.length, 256);
      expect(all.first, '0-255');
      expect(all.last, '65280-65535');
    },
  );
}
