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
    final sat = layers.indexWhere((l) => l['id'] == satelliteLayerId);
    // Di bawah imej hanya latar dan isian air/tanah (untuk luar talian), tiada jalan atau label.
    expect(sat, greaterThan(0));
    for (final l in layers.take(sat).skip(1)) {
      expect(l['type'], 'fill');
      expect(const {
        'water',
        'landcover',
        'landuse',
        'park',
      }, contains(l['source-layer']));
    }
    expect(
      layers.take(sat).where((l) => l['source-layer'] == 'water'),
      isNotEmpty,
    );
    final src = (style['sources'] as Map)[satelliteSourceId] as Map;
    expect(src['type'], 'raster');
    expect((src['tiles'] as List).single, contains('World_Imagery'));
    expect(src['attribution'], contains('Powered by'));
    expect(src['attribution'], contains('Esri'));
    expect(AppConfig.satelliteTilesUrl, startsWith('https://'));
  });

  test(
    'di atas imej: tiada isian/bangunan/relief; jalan lut sinar; label kekal',
    () {
      final layers = (hybrid()['layers'] as List).cast<Map<String, dynamic>>();
      // Lapisan z19 ialah raster kedua tepat di atas imej asas; semuanya selepas itu ialah vektor.
      final hi = layers.indexWhere((l) => l['id'] == satelliteHiLayerId);
      final rest = layers.skip(hi + 1);
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
            (l['layout'] as Map?)?['text-field'] != null &&
            !'${l['id']}'.contains('shield') &&
            !((l['layout'] as Map?)?['icon-image'] != null &&
                (l['layout'] as Map?)?['symbol-placement'] == 'line'),
      );
      expect(labels.length, greaterThan(10));
      for (final l in labels) {
        expect((l['paint'] as Map)['text-color'], SatelliteStyle.labelColor);
      }
      // Lapisan FGMaps (laluan, anak panah) diletak di bawah label pertama oleh peta.
      expect(rest.firstWhere((l) => l['type'] == 'symbol'), isNotNull);
    },
  );

  test(
    'lapisan imej asli z19: tersembunyi lalai, hanya tahap 19, di atas imej asas',
    () {
      final style = hybrid();
      final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
      final sat = layers.indexWhere((l) => l['id'] == satelliteLayerId);
      final hi = layers.indexWhere((l) => l['id'] == satelliteHiLayerId);
      expect(hi, sat + 1);
      expect(layers[hi]['type'], 'raster');
      expect(layers[hi]['source'], satelliteHiSourceId);
      // Tersembunyi sehingga peta mengesahkan imej z19 wujud (jubin kelabu di tempat lain).
      expect((layers[hi]['layout'] as Map)['visibility'], 'none');
      final src = (style['sources'] as Map)[satelliteHiSourceId] as Map;
      expect(src['type'], 'raster');
      // 128: tahap 19 diminta mulai zum peta 17 (pemanduan biasa 16.2-18.2); asas kekal 256.
      expect(src['tileSize'], SatelliteStyle.hiTileSize);
      expect(SatelliteStyle.hiTileSize, 128);
      final baseSrc = (style['sources'] as Map)[satelliteSourceId] as Map;
      expect(baseSrc['tileSize'], 256);
      expect(src['minzoom'], SatelliteStyle.hiMaxZoom);
      expect(src['maxzoom'], SatelliteStyle.hiMaxZoom);
      // Jubin sama dengan lapisan asas; asas kekal z18 yang selamat di mana-mana.
      final base = (style['sources'] as Map)[satelliteSourceId] as Map;
      expect(src['tiles'], base['tiles']);
      expect(base['maxzoom'], SatelliteStyle.maxZoom);
      expect(SatelliteStyle.hiMaxZoom, SatelliteStyle.maxZoom + 1);
    },
  );

  test(
    'kejelasan: kontras dan ketepuan sederhana pada kedua-dua lapisan imej',
    () {
      final layers = (hybrid()['layers'] as List).cast<Map<String, dynamic>>();
      for (final id in [satelliteLayerId, satelliteHiLayerId]) {
        final paint = layers.firstWhere((l) => l['id'] == id)['paint'] as Map;
        expect(paint['raster-contrast'], SatelliteStyle.rasterContrast);
        expect(paint['raster-saturation'], SatelliteStyle.rasterSaturation);
      }
      // Sederhana: terlalu banyak memecahkan warna hijau dan bumbung.
      expect(SatelliteStyle.rasterContrast, inInclusiveRange(0.0, 0.25));
      expect(SatelliteStyle.rasterSaturation, inInclusiveRange(0.0, 0.2));
    },
  );

  test('kunci gaya satelit memakai awalan yang dikenali peta', () {
    expect('${satelliteStyleKeyPrefix}online:1:2', startsWith('satellite:'));
  });

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
