import 'dart:convert';

import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/saved_places/data/saved_places_controller.dart';
import 'package:fgmap/features/saved_places/domain/saved_place.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/domain/place_json.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lotus = Place(
  name: "Lotus's Puncak Alam",
  subtitle: 'Persiaran Puncak Alam',
  point: GeoPoint(3.2262, 101.4278),
  category: 'supermarket',
  osmKey: 'shop',
  osmType: 'W',
  osmId: 42,
  extentDiagonalM: 180,
  countryCode: 'MY',
);
const _klcc = Place(
  name: 'KLCC',
  subtitle: 'Kuala Lumpur',
  point: GeoPoint(3.1579, 101.7116),
);

Future<(ProviderContainer, SharedPreferences)> _make([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return (c, prefs);
}

void main() {
  group('placeToJson/placeFromJson', () {
    test('bulatan penuh termasuk medan OSM', () {
      final back = placeFromJson(jsonDecode(jsonEncode(placeToJson(_lotus))));
      expect(back, _lotus);
      expect(back!.osmKey, 'shop');
      expect(back.osmType, 'W');
      expect(back.osmId, 42);
      expect(back.extentDiagonalM, 180);
      expect(back.countryCode, 'MY');
      expect(back.routingRadiusM, 60.0, reason: '180/2 = 90 dihadkan 60');
    });

    test(
      'bentuk lama (tanpa medan OSM) kekal sah dan tidak menambah kunci',
      () {
        final json = placeToJson(_klcc);
        expect(
          json.keys,
          containsAll(['name', 'subtitle', 'lat', 'lng', 'category']),
        );
        expect(json.containsKey('osmKey'), isFalse);
        expect(placeFromJson(json), _klcc);
        expect(
          placeFromJson({
            'name': 'Lama',
            'subtitle': '',
            'lat': 3.0,
            'lng': 101.0,
            'category': null,
          })!.osmType,
          isNull,
        );
      },
    );

    test(
      'rosak atau di luar julat -> null; jenis OSM tidak dikenali dibuang',
      () {
        expect(placeFromJson('bukan peta'), isNull);
        expect(
          placeFromJson({'name': 'x', 'subtitle': '', 'lat': 200, 'lng': 0}),
          isNull,
        );
        final odd = placeFromJson({
          'name': 'x',
          'subtitle': '',
          'lat': 1.0,
          'lng': 1.0,
          'osmType': 'Z',
          'extent': -5,
        })!;
        expect(odd.osmType, isNull);
        expect(odd.extentDiagonalM, isNull);
      },
    );
  });

  group('SavedPlacesController', () {
    test('mula kosong; tetapkan Rumah dan Kerja (satu setiap satu)', () async {
      final (c, prefs) = await _make();
      final n = c.read(savedPlacesControllerProvider.notifier);
      expect(c.read(savedPlacesControllerProvider), isEmpty);

      await n.setHome(_lotus);
      await n.setWork(_klcc);
      expect(n.home!.place, _lotus);
      expect(n.work!.place, _klcc);

      await n.setHome(_klcc);
      expect(n.home!.place, _klcc);
      expect(
        c
            .read(savedPlacesControllerProvider)
            .where((s) => s.kind == SavedKind.home),
        hasLength(1),
      );
      expect(prefs.getString('saved.v1'), isNotNull);
    });

    test(
      'disimpan dan dibaca semula (termasuk metadata OSM untuk radius)',
      () async {
        final (c, prefs) = await _make();
        await c.read(savedPlacesControllerProvider.notifier).setHome(_lotus);
        final c2 = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(c2.dispose);
        final home = c2.read(savedPlacesControllerProvider.notifier).home!;
        expect(home.place.routingRadiusM, 60.0);
        expect(home.place.osmType, 'W');
      },
    );

    test('kegemaran: toggle tambah/buang, tiada pendua', () async {
      final (c, _) = await _make();
      final n = c.read(savedPlacesControllerProvider.notifier);
      expect(await n.toggleFavorite(_klcc), isTrue);
      expect(n.isFavorite(_klcc), isTrue);
      expect(await n.toggleFavorite(_klcc), isFalse);
      expect(n.isFavorite(_klcc), isFalse);
      await n.toggleFavorite(_klcc);
      await n.toggleFavorite(
        const Place(
          name: 'KLCC (salinan)',
          subtitle: '',
          point: GeoPoint(3.1579, 101.7116),
        ),
      );
      // Koordinat sama = tempat sama: togol kedua membuangnya.
      expect(n.favorites, isEmpty);
    });

    test('had 30 kegemaran; Rumah/Kerja tidak pernah dibuang', () async {
      final (c, _) = await _make();
      final n = c.read(savedPlacesControllerProvider.notifier);
      await n.setHome(_lotus);
      for (var i = 0; i < 35; i++) {
        await n.toggleFavorite(
          Place(name: 'T$i', subtitle: '', point: GeoPoint(3 + i * 0.01, 101)),
        );
      }
      expect(n.favorites, hasLength(SavedPlacesController.maxFavorites));
      expect(n.home, isNotNull);
      // Yang terbaru kekal, yang paling lama dibuang.
      expect(n.favorites.first.place.name, 'T34');
      expect(n.favorites.any((s) => s.place.name == 'T0'), isFalse);
    });

    test('remove dan clear', () async {
      final (c, _) = await _make();
      final n = c.read(savedPlacesControllerProvider.notifier);
      await n.setHome(_lotus);
      await n.setWork(_klcc);
      await n.remove(SavedPlace.homeId);
      expect(n.home, isNull);
      expect(n.work, isNotNull);
      await n.clear();
      expect(c.read(savedPlacesControllerProvider), isEmpty);
    });

    test('data rosak, versi lain, atau entri tidak sah diabaikan', () async {
      for (final raw in [
        '{bukan json',
        '[]',
        jsonEncode({'v': 99, 'items': []}),
        jsonEncode({'v': 1, 'items': 'x'}),
      ]) {
        final (c, _) = await _make({'saved.v1': raw});
        expect(c.read(savedPlacesControllerProvider), isEmpty, reason: raw);
      }
      final (c, _) = await _make({
        'saved.v1': jsonEncode({
          'v': 1,
          'items': [
            {'id': 'home', 'kind': 'home', 'place': placeToJson(_lotus)},
            {'id': 'home', 'kind': 'home', 'place': placeToJson(_klcc)},
            {'id': 'x', 'kind': 'tidak-wujud', 'place': placeToJson(_klcc)},
            {'id': 'y', 'kind': 'work', 'place': 'rosak'},
          ],
        }),
      });
      final items = c.read(savedPlacesControllerProvider);
      expect(items, hasLength(1));
      expect(items.single.place, _lotus);
    });
  });
}
