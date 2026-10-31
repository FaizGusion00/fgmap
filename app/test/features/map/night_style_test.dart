import 'dart:convert';
import 'dart:math' as math;

import 'package:fgmap/features/map/domain/night_style.dart';
import 'package:flutter_test/flutter_test.dart';

// Gaya SINTETIK yang meniru struktur OpenMapTiles/OpenFreeMap Liberty (source-layer, id jalan dan
// ungkapan MapLibre). Bukan salinan gaya sebenar: container pembangunan tidak boleh mencapai
// tiles.openfreemap.org.
Map<String, Object?> _style({
  String glyphs = 'https://tiles.example/fonts/{fontstack}/{range}.pbf',
}) => {
  'version': 8,
  'name': 'Liberty (sintetik)',
  'sprite': 'https://tiles.example/sprites/ofm',
  'glyphs': glyphs,
  'sources': {
    'openmaptiles': {'type': 'vector', 'url': 'https://tiles.example/planet'},
  },
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#f8f4f0'},
    },
    {
      'id': 'water',
      'type': 'fill',
      'source-layer': 'water',
      'paint': {'fill-color': 'hsl(205,56%,73%)'},
    },
    {
      'id': 'landcover_wood',
      'type': 'fill',
      'source-layer': 'landcover',
      'filter': ['==', 'class', 'wood'],
      'paint': {'fill-color': '#cfe8c2'},
    },
    {
      'id': 'park',
      'type': 'fill',
      'source-layer': 'park',
      'paint': {'fill-color': '#d8e8c8'},
    },
    {
      'id': 'landuse_residential',
      'type': 'fill',
      'source-layer': 'landuse',
      'filter': ['==', 'class', 'residential'],
      'paint': {'fill-color': '#ece8e0'},
    },
    {
      'id': 'building',
      'type': 'fill',
      'source-layer': 'building',
      'paint': {'fill-color': '#e0dcd4', 'fill-outline-color': '#ccc'},
    },
    {
      'id': 'building-3d',
      'type': 'fill-extrusion',
      'source-layer': 'building',
      'paint': {'fill-extrusion-color': '#e0dcd4'},
    },
    {
      'id': 'road_motorway_casing',
      'type': 'line',
      'source-layer': 'transportation',
      'filter': ['==', 'class', 'motorway'],
      'paint': {
        'line-color': '#e9ac77',
        'line-width': {
          'stops': [
            [5, 0.4],
            [14, 8],
          ],
        },
      },
    },
    {
      'id': 'road_motorway',
      'type': 'line',
      'source-layer': 'transportation',
      'filter': ['==', 'class', 'motorway'],
      'paint': {
        'line-color': '#fc8',
        'line-width': [
          'interpolate',
          ['exponential', 1.2],
          ['zoom'],
          5,
          0.5,
          14,
          6,
        ],
      },
    },
    {
      'id': 'road_primary',
      'type': 'line',
      'source-layer': 'transportation',
      'filter': ['==', 'class', 'primary'],
      'paint': {'line-color': '#fea', 'line-width': 4},
    },
    {
      'id': 'road_secondary_tertiary',
      'type': 'line',
      'source-layer': 'transportation',
      'filter': ['in', 'class', 'secondary', 'tertiary'],
      'paint': {'line-color': '#fff', 'line-width': 3},
    },
    {
      'id': 'road_minor',
      'type': 'line',
      'source-layer': 'transportation',
      'filter': ['in', 'class', 'minor', 'service'],
      'paint': {'line-color': '#fff', 'line-width': 2},
    },
    {
      'id': 'road_path',
      'type': 'line',
      'source-layer': 'transportation',
      'filter': ['in', 'class', 'path', 'track'],
      'paint': {'line-color': '#cba', 'line-width': 1},
    },
    {
      'id': 'railway',
      'type': 'line',
      'source-layer': 'transportation',
      'filter': ['==', 'class', 'rail'],
      'paint': {'line-color': '#bbb'},
    },
    {
      'id': 'boundary_state',
      'type': 'line',
      'source-layer': 'boundary',
      'paint': {'line-color': '#9e9cab'},
    },
    {
      'id': 'highway-name-major',
      'type': 'symbol',
      'source-layer': 'transportation_name',
      'layout': {
        'text-field': '{name:latin}',
        'text-size': [
          'interpolate',
          ['linear'],
          ['zoom'],
          13,
          10,
          20,
          16,
        ],
      },
      'paint': {'text-color': '#333', 'text-halo-color': '#fff'},
    },
    {
      'id': 'label_city',
      'type': 'symbol',
      'source-layer': 'place',
      'layout': {'text-field': '{name:latin}', 'text-size': 14},
      'paint': {'text-color': '#000'},
    },
    {
      'id': 'water_name',
      'type': 'symbol',
      'source-layer': 'water_name',
      'layout': {'text-field': '{name:latin}', 'text-size': 12},
      'paint': {'text-color': 'rgb(157,169,177)'},
    },
    {
      'id': 'poi_r20',
      'type': 'symbol',
      'source-layer': 'poi',
      'layout': {
        'text-field': '{name:latin}',
        'icon-image': 'x',
        'text-size': 11,
      },
      'paint': {'text-color': '#666'},
    },
    {
      'id': 'icon_only',
      'type': 'symbol',
      'source-layer': 'poi',
      'layout': {'icon-image': 'y'},
    },
  ],
};

Map<String, dynamic> _apply([Map<String, Object?>? style]) {
  final out = NightStyle.apply(jsonEncode(style ?? _style()));
  expect(out, isNotNull);
  return jsonDecode(out!) as Map<String, dynamic>;
}

Map<String, dynamic> _layer(Map<String, dynamic> s, String id) =>
    (s['layers'] as List).cast<Map<String, dynamic>>().firstWhere(
      (l) => l['id'] == id,
    );

int _argb(String hex) => 0xFF000000 | int.parse(hex.substring(1), radix: 16);

double _luminance(int argb) {
  double c(int v) {
    final x = v / 255;
    return x <= 0.03928
        ? x / 12.92
        : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * c((argb >> 16) & 0xFF) +
      0.7152 * c((argb >> 8) & 0xFF) +
      0.0722 * c(argb & 0xFF);
}

double _contrast(int a, int b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('NightStyle.apply', () {
    test('latar, air, bangunan dan tanah diwarnakan malam', () {
      final s = _apply();
      expect(_layer(s, 'background')['paint']['background-color'], '#13213a');
      expect(_layer(s, 'water')['paint']['fill-color'], '#0a3961');
      expect(_layer(s, 'building')['paint']['fill-color'], '#233857');
      expect(
        _layer(s, 'building-3d')['paint']['fill-extrusion-color'],
        '#233857',
      );
      expect(_layer(s, 'landcover_wood')['paint']['fill-color'], '#15343b');
      expect(_layer(s, 'park')['paint']['fill-color'], '#173a42');
      expect(
        _layer(s, 'landuse_residential')['paint']['fill-color'],
        '#172843',
      );
    });

    test('jalan mengikut kelas; casing gelap', () {
      final s = _apply();
      String color(String id) => _layer(s, id)['paint']['line-color'] as String;
      expect(color('road_motorway'), '#f6b445');
      expect(color('road_primary'), '#e4edfa');
      expect(color('road_secondary_tertiary'), '#c3d3eb');
      expect(color('road_minor'), '#8ca2c4');
      expect(color('road_path'), '#7088a8');
      expect(color('railway'), '#6a82a5');
      expect(color('road_motorway_casing'), '#0c172b');
      expect(color('boundary_state'), '#5a7398');
    });

    test('lebar jalan diskala untuk nombor, stops dan interpolate', () {
      final s = _apply();
      expect(
        _layer(s, 'road_primary')['paint']['line-width'],
        closeTo(4 * 1.2, 1e-9),
      );
      final stops =
          _layer(s, 'road_motorway_casing')['paint']['line-width']['stops']
              as List;
      expect(stops[0][0], 5);
      expect(stops[0][1], closeTo(0.4 * 1.2, 1e-9));
      expect(stops[1][1], closeTo(8 * 1.2, 1e-9));
      final interp = _layer(s, 'road_motorway')['paint']['line-width'] as List;
      expect(interp.sublist(0, 4), [
        'interpolate',
        ['exponential', 1.2],
        ['zoom'],
        5,
      ]);
      expect(interp[4], closeTo(0.5 * 1.2, 1e-9));
      expect(interp[5], 14);
      expect(interp[6], closeTo(6 * 1.2, 1e-9));
    });

    test('label: warna terang, halo gelap, saiz diskala', () {
      final s = _apply();
      final road = _layer(s, 'highway-name-major');
      expect(road['paint']['text-color'], '#d2dff2');
      expect(road['paint']['text-halo-color'], '#0c172b');
      expect(road['paint']['text-halo-width'], greaterThanOrEqualTo(1.5));
      final size = road['layout']['text-size'] as List;
      expect(size[4], closeTo(10 * 1.1, 1e-9));
      expect(size[6], closeTo(16 * 1.1, 1e-9));
      expect(_layer(s, 'label_city')['paint']['text-color'], '#f6f9ff');
      expect(
        _layer(s, 'label_city')['layout']['text-size'],
        closeTo(14 * 1.1, 1e-9),
      );
      expect(_layer(s, 'water_name')['paint']['text-color'], '#8fc2f2');
      expect(_layer(s, 'poi_r20')['paint']['text-color'], '#b6c8e2');
    });

    test('lapisan ikon tanpa teks tidak diubah', () {
      final s = _apply();
      expect(_layer(s, 'icon_only')['paint'], isEmpty);
    });

    test('struktur lain dikekalkan (sumber, sprite, glyph)', () {
      final s = _apply();
      expect(s['sprite'], 'https://tiles.example/sprites/ofm');
      expect(
        s['sources']['openmaptiles']['url'],
        'https://tiles.example/planet',
      );
    });

    test('gaya tidak dikenali -> null (sandaran ke URL)', () {
      expect(NightStyle.apply('bukan json'), isNull);
      expect(NightStyle.apply('[]'), isNull);
      expect(NightStyle.apply('{"layers": []}'), isNull);
      expect(
        NightStyle.apply('{"layers": [{"id":"x","type":"raster"}]}'),
        isNull,
      );
    });

    test('glyph/sprite/sumber relatif -> null', () {
      expect(
        NightStyle.apply(
          jsonEncode(_style(glyphs: 'fonts/{fontstack}/{range}.pbf')),
        ),
        isNull,
      );
      final relSource = _style();
      (relSource['sources'] as Map)['openmaptiles'] = {
        'type': 'vector',
        'url': 'planet.json',
      };
      expect(NightStyle.apply(jsonEncode(relSource)), isNull);
    });
  });

  group('kontras palet malam', () {
    const bg = NightPalette.background;

    test(
      'jalan kelas utama sekurang-kurangnya 3:1 pada latar, kecil >= 3:1',
      () {
        for (final entry in {
          'motorway': NightPalette.motorway,
          'trunk': NightPalette.trunk,
          'primary': NightPalette.primary,
          'secondary': NightPalette.secondary,
          'tertiary': NightPalette.tertiary,
          'minor': NightPalette.minor,
          'service': NightPalette.service,
          'path': NightPalette.path,
        }.entries) {
          expect(
            _contrast(entry.value, bg),
            greaterThanOrEqualTo(3.0),
            reason: entry.key,
          );
        }
      },
    );

    test('label sekurang-kurangnya 4.5:1 pada latar, tanah dan bangunan', () {
      for (final label in [
        NightPalette.label,
        NightPalette.roadLabel,
        NightPalette.placeLabel,
        NightPalette.waterLabel,
        NightPalette.poiLabel,
      ]) {
        for (final ground in [
          NightPalette.background,
          NightPalette.green,
          NightPalette.wood,
          NightPalette.building,
          NightPalette.water,
          NightPalette.residential,
        ]) {
          expect(
            _contrast(label, ground),
            greaterThanOrEqualTo(4.5),
            reason:
                '${label.toRadixString(16)} pada ${ground.toRadixString(16)}',
          );
        }
      }
    });

    test(
      'jalan lebih terang daripada casing dan jalan menonjol berbanding bangunan',
      () {
        expect(
          _contrast(NightPalette.minor, NightPalette.roadCasing),
          greaterThan(4),
        );
        expect(
          _contrast(NightPalette.minor, NightPalette.building),
          greaterThanOrEqualTo(3.0),
        );
      },
    );

    test('warna laluan app (biru) kekal kelihatan di atas jalan malam', () {
      // Garisan laluan mod gelap: lihat FgPalette.dark.routeMain; di sini hanya jarak daripada latar peta.
      expect(_contrast(_argb('#4f8bff'), bg), greaterThanOrEqualTo(3.0));
    });
  });

  group('scaleNumeric', () {
    test('nombor, null dan ungkapan tidak dikenali', () {
      expect(NightStyle.scaleNumeric(2, 1.5), 3);
      expect(NightStyle.scaleNumeric(null, 2), isNull);
      expect(NightStyle.scaleNumeric(['get', 'x'], 2), ['get', 'x']);
      expect(NightStyle.scaleNumeric('abc', 2), 'abc');
    });

    test('step', () {
      expect(
        NightStyle.scaleNumeric([
          'step',
          ['zoom'],
          2,
          10,
          4,
        ], 2),
        [
          'step',
          ['zoom'],
          4,
          10,
          8,
        ],
      );
    });
  });
}
