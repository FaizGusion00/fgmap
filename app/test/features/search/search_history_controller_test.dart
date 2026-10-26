import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/search_history_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Place _place(String name, double latitude) => Place(
  name: name,
  subtitle: 'Malaysia',
  point: GeoPoint(latitude, 101.7),
  category: 'city',
);

void main() {
  late SharedPreferences preferences;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
  });

  test('history persists newest places, deduplicates and clears', () async {
    final history = container.read(searchHistoryControllerProvider.notifier);
    await history.record(_place('First', 3.1));
    await history.record(_place('Second', 3.2));
    await history.record(_place('First renamed', 3.1));

    expect(
      container
          .read(searchHistoryControllerProvider)
          .map((place) => place.name),
      ['First renamed', 'Second'],
    );

    final restored = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(restored.dispose);
    expect(
      restored.read(searchHistoryControllerProvider).map((place) => place.name),
      ['First renamed', 'Second'],
    );

    await restored.read(searchHistoryControllerProvider.notifier).clear();
    expect(restored.read(searchHistoryControllerProvider), isEmpty);
    expect(preferences.getStringList('search.history.v1'), isEmpty);
  });

  test('history is capped at ten places', () async {
    final history = container.read(searchHistoryControllerProvider.notifier);
    for (var i = 0; i < 12; i++) {
      await history.record(_place('Place $i', 3 + i / 100));
    }

    final places = container.read(searchHistoryControllerProvider);
    expect(places, hasLength(10));
    expect(places.first.name, 'Place 11');
    expect(places.last.name, 'Place 2');
  });
}
