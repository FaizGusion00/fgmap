import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/theme_controller.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/reports/data/reports_repository.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:fgmap/features/saved_places/data/saved_places_controller.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/search_history_controller.dart';
import 'package:fgmap/features/settings/data/data_eraser.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fgmap/features/music/data/radio_favorites.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lotus = Place(
  name: 'Lotus',
  subtitle: 'Puncak Alam',
  point: GeoPoint(3.2262, 101.4278),
);

void main() {
  late SharedPreferences prefs;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reportsRepositoryProvider.overrideWithValue(
          LocalReportsRepository(null),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('lokasi matahari dikaburkan', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('coarsen: 0.1 darjah (~11 km)', () {
      expect(
        SunLocationController.coarsen(const GeoPoint(3.1579, 101.7116)),
        const GeoPoint(3.2, 101.7),
      );
    });

    test('update menyimpan nilai kabur, bukan kedudukan tepat', () async {
      final c = container();
      c
          .read(sunLocationProvider.notifier)
          .update(const GeoPoint(5.4141, 100.3288));
      expect(c.read(sunLocationProvider), const GeoPoint(5.4, 100.3));
      expect(prefs.getDouble('theme.sunLat'), 5.4);
      expect(prefs.getDouble('theme.sunLng'), 100.3);
    });

    test(
      'nilai tepat daripada versi lama dikaburkan dan ditulis ganti',
      () async {
        await prefs.setDouble('theme.sunLat', 3.157901);
        await prefs.setDouble('theme.sunLng', 101.711602);
        final c = container();
        expect(c.read(sunLocationProvider), const GeoPoint(3.2, 101.7));
        await Future<void>.delayed(Duration.zero);
        expect(prefs.getDouble('theme.sunLat'), 3.2);
        expect(prefs.getDouble('theme.sunLng'), 101.7);
      },
    );

    test('ralat waktu matahari akibat pengaburan kecil (beberapa minit)', () {
      // Perbezaan tepat vs kabur pada ~11 km: waktu terbit/terbenam berubah sangat sedikit.
      const a = GeoPoint(3.1579, 101.7116);
      final b = SunLocationController.coarsen(a);
      expect(distanceMeters(a, b), lessThan(8000));
    });
  });

  group('padam semua data saya', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'nearby.v1.index': '["nearby.v1.fuel.323.10143"]',
        'nearby.v1.fuel.323.10143': '{"at":"2026-10-26T10:00:00"}',
        'theme.sunLat': 3.2,
        'theme.sunLng': 101.7,
        // Tetapan bukan data peribadi: kekal.
        'theme.mode': 'dark',
        'nav.voice': true,
        'onboarding.v1': true,
      });
      prefs = await SharedPreferences.getInstance();
    });

    test('eraseNearbyCache hanya membuang kunci nearby.v1.*', () async {
      await eraseNearbyCache(prefs);
      expect(prefs.getKeys().where((k) => k.startsWith('nearby.')), isEmpty);
      expect(prefs.getString('theme.mode'), 'dark');
    });

    testWidgets('semua data peribadi dipadam; tetapan dan sambutan kekal', (
      tester,
    ) async {
      // Disediakan melalui widget kerana eraseAllUserData menerima WidgetRef.
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reportsRepositoryProvider.overrideWithValue(
              LocalReportsRepository(null),
            ),
          ],
          child: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const SizedBox();
            },
          ),
        ),
      );
      await ref.read(searchHistoryControllerProvider.notifier).record(_lotus);
      await ref.read(savedPlacesControllerProvider.notifier).setHome(_lotus);
      expect(ref.read(searchHistoryControllerProvider), isNotEmpty);
      await prefs.setBool('azan.enabled', true);
      await prefs.setDouble('azan.lat', 3.14);
      await prefs.setDouble('azan.lng', 101.69);
      await prefs.setInt('azan.scheduledAt', 1);
      await prefs.setString('azan.official.v1', '[]');
      await prefs.setString('azan.scheduledSig', 'x');
      await ref
          .read(radioFavoritesProvider.notifier)
          .toggle(
            Track(
              id: 'r1',
              source: TrackSource.radio,
              title: 'Sinar FM',
              streamUri: Uri.parse('https://example.test/live'),
            ),
          );
      expect(ref.read(radioFavoritesProvider), isNotEmpty);

      await eraseAllUserData(ref);

      expect(ref.read(radioFavoritesProvider), isEmpty);
      expect(prefs.containsKey('music.radio.favorites.v1'), isFalse);
      expect(prefs.containsKey('music.radio.failed.v1'), isFalse);

      expect(ref.read(searchHistoryControllerProvider), isEmpty);
      expect(ref.read(savedPlacesControllerProvider), isEmpty);
      expect(prefs.getKeys().where((k) => k.startsWith('nearby.')), isEmpty);
      expect(prefs.containsKey('theme.sunLat'), isFalse);
      expect(prefs.containsKey('theme.sunLng'), isFalse);
      // Kedudukan waktu azan (dikaburkan) juga dipadam; tetapan azan kekal.
      expect(prefs.containsKey('azan.lat'), isFalse);
      expect(prefs.containsKey('azan.lng'), isFalse);
      expect(prefs.containsKey('azan.scheduledAt'), isFalse);
      expect(prefs.containsKey('azan.official.v1'), isFalse);
      expect(prefs.containsKey('azan.scheduledSig'), isFalse);
      expect(prefs.getBool('azan.enabled'), isTrue);
      expect(ref.read(sunLocationProvider), const GeoPoint(3.139, 101.687));
      // Kekal.
      expect(prefs.getString('theme.mode'), 'dark');
      expect(prefs.getBool('onboarding.v1'), isTrue);
    });
  });
}
