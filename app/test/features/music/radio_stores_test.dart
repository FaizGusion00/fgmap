import 'dart:convert';

import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/music/data/radio_favorites.dart';
import 'package:fgmap/features/music/data/radio_health.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_test_support.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> init([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Track station(String id) =>
      track(id, source: TrackSource.radio, title: 'Stesen $id');

  group('RadioFavorites', () {
    test(
      'toggle menyimpan; bekas baharu membaca semula; toggle lagi membuang',
      () async {
        await init();
        final c = make();
        final fav = c.read(radioFavoritesProvider.notifier);
        await fav.toggle(station('a'));
        await fav.toggle(station('b'));
        expect(c.read(radioFavoritesProvider).map((t) => t.id), ['b', 'a']);

        final again = make();
        expect(again.read(radioFavoritesProvider).map((t) => t.id), ['b', 'a']);
        expect(
          again.read(radioFavoritesProvider.notifier).isFavorite(station('a')),
          isTrue,
        );

        await again.read(radioFavoritesProvider.notifier).toggle(station('a'));
        expect(again.read(radioFavoritesProvider).map((t) => t.id), ['b']);
        expect(make().read(radioFavoritesProvider).map((t) => t.id), ['b']);
      },
    );

    test('hanya stesen radio; lagu Audius diabaikan', () async {
      await init();
      final c = make();
      await c.read(radioFavoritesProvider.notifier).toggle(track('lagu'));
      expect(c.read(radioFavoritesProvider), isEmpty);
      expect(prefs.containsKey(radioFavoritesKey), isFalse);
    });

    test(
      'dihadkan kepada $maxRadioFavorites; yang terbaharu dikekalkan',
      () async {
        await init();
        final c = make();
        final fav = c.read(radioFavoritesProvider.notifier);
        for (var i = 0; i < maxRadioFavorites + 5; i++) {
          await fav.toggle(station('s$i'));
        }
        final list = c.read(radioFavoritesProvider);
        expect(list, hasLength(maxRadioFavorites));
        expect(list.first.id, 's${maxRadioFavorites + 4}');
      },
    );

    test('JSON rosak atau bentuk salah -> kosong, tidak melontar', () async {
      await init({radioFavoritesKey: '{bukan senarai'});
      expect(make().read(radioFavoritesProvider), isEmpty);
      await init({
        radioFavoritesKey: jsonEncode({'a': 1}),
      });
      expect(make().read(radioFavoritesProvider), isEmpty);
      await init({
        radioFavoritesKey: jsonEncode([
          {
            'source': 'audius',
            'id': 'x',
            'title': 'Bukan radio',
            'streamUri': 'https://e.test/x',
          },
          'sampah',
          station('ok').toJson(),
        ]),
      });
      expect(make().read(radioFavoritesProvider).map((t) => t.id), ['ok']);
    });

    test('clear memadam dari memori dan SharedPreferences', () async {
      await init();
      final c = make();
      final fav = c.read(radioFavoritesProvider.notifier);
      await fav.toggle(station('a'));
      await fav.clear();
      expect(c.read(radioFavoritesProvider), isEmpty);
      expect(prefs.containsKey(radioFavoritesKey), isFalse);
    });
  });

  group('RadioHealth', () {
    test('markFailed disimpan, isFailed benar, markOk melupakan', () async {
      await init();
      final c = make();
      final health = c.read(radioHealthProvider.notifier);
      expect(health.isFailed(station('a')), isFalse);
      await health.markFailed(station('a'));
      expect(health.isFailed(station('a')), isTrue);
      expect(
        make().read(radioHealthProvider.notifier).isFailed(station('a')),
        isTrue,
      );

      await health.markOk(station('a'));
      expect(health.isFailed(station('a')), isFalse);
      expect(make().read(radioHealthProvider), isEmpty);
    });

    test(
      'kegagalan lebih 24 jam dibuang semasa muat; yang baru kekal',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await init({
          radioHealthKey: jsonEncode({
            station('lama').key: now - const Duration(hours: 25).inMilliseconds,
            station('baru').key: now - const Duration(hours: 1).inMilliseconds,
          }),
        });
        final health = make().read(radioHealthProvider.notifier);
        expect(health.isFailed(station('lama')), isFalse);
        expect(health.isFailed(station('baru')), isTrue);
      },
    );

    test(
      'markFailed berulang dalam seminit tidak menulis semula; lagu bukan radio diabaikan',
      () async {
        await init();
        final c = make();
        final health = c.read(radioHealthProvider.notifier);
        await health.markFailed(station('a'));
        final first = c.read(radioHealthProvider)[station('a').key];
        await health.markFailed(station('a'));
        expect(c.read(radioHealthProvider)[station('a').key], first);
        await health.markFailed(track('lagu'));
        expect(c.read(radioHealthProvider), hasLength(1));
      },
    );

    test('data rosak -> kosong', () async {
      await init({radioHealthKey: 'bukan json'});
      expect(make().read(radioHealthProvider), isEmpty);
    });
  });
}
