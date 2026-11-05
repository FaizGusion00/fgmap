import 'dart:convert';
import 'dart:io';

import 'package:fgmap/core/config/app_config.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/map/data/map_layer.dart';
import 'package:fgmap/features/map/domain/satellite_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Peta "Satelit" (hibrid) seperti Google Maps: imej satelit + jalan dan label.
void main() {
  final liberty = File('assets/map/liberty.json').readAsStringSync();

  Map<String, dynamic> hybrid() =>
      jsonDecode(
            SatelliteStyle.apply(
              liberty,
              tilesUrl: AppConfig.satelliteTilesUrl,
            )!,
          )
          as Map<String, dynamic>;

  test('imej satelit di bawah semua lapisan vektor, dengan atribusi Esri', () {
    final style = hybrid();
    final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
    expect(layers.first['type'], 'background');
    expect(layers[1]['id'], satelliteLayerId);
    final src = (style['sources'] as Map)[satelliteSourceId] as Map;
    expect(src['type'], 'raster');
    expect((src['tiles'] as List).single, contains('World_Imagery'));
    expect(src['attribution'], contains('Powered by'));
    expect(src['attribution'], contains('Esri'));
    expect(AppConfig.satelliteTilesUrl, startsWith('https://'));
  });

  test(
    'tanah, air, bangunan dan relief dibuang; jalan lut sinar; label kekal',
    () {
      final layers = (hybrid()['layers'] as List).cast<Map<String, dynamic>>();
      final rest = layers.skip(2);
      expect(
        rest.where(
          (l) => [
            'fill',
            'fill-extrusion',
            'background',
            'raster',
          ].contains(l['type']),
        ),
        isEmpty,
      );
      final roads = rest.where(
        (l) => l['type'] == 'line' && l['source-layer'] == 'transportation',
      );
      expect(roads.length, greaterThan(10));
      for (final r in roads) {
        expect(r['id'], isNot(contains('casing')));
        expect((r['paint'] as Map)['line-opacity'], SatelliteStyle.roadOpacity);
      }
      final labels = rest.where(
        (l) =>
            l['type'] == 'symbol' &&
            (l['layout'] as Map?)?['text-field'] != null,
      );
      expect(labels.length, greaterThan(10));
      for (final l in labels) {
        expect((l['paint'] as Map)['text-color'], SatelliteStyle.labelColor);
      }
      // Lapisan FGMaps (laluan, anak panah) diletak di bawah label pertama oleh peta.
      expect(rest.firstWhere((l) => l['type'] == 'symbol'), isNotNull);
    },
  );

  test('gaya rosak atau bukan OpenMapTiles: null (peta biasa digunakan)', () {
    expect(SatelliteStyle.apply('x', tilesUrl: 'https://t/{z}'), isNull);
    expect(
      SatelliteStyle.apply(
        '{"layers":[{"id":"a","type":"line"}],"sources":{}}',
        tilesUrl: 'https://t/{z}',
      ),
      isNull,
    );
  });

  test('pilihan jenis peta disimpan; lalai = Lalai', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(mapLayerProvider), MapLayer.standard);
    await c.read(mapLayerProvider.notifier).set(MapLayer.satellite);
    expect(c.read(mapLayerProvider), MapLayer.satellite);
    expect(prefs.getString(mapLayerPrefsKey), 'satellite');
    expect(MapLayer.fromName('bogus'), MapLayer.standard);
  });
}
