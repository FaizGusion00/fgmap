import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/nearby_search.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/place_search_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Nearby implements NearbySearch {
  int calls = 0;
  bool fail = true;

  @override
  Future<List<Place>> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    calls++;
    if (fail) throw const GeocodeFailure(GeocodeFailureKind.unavailable);
    return [
      Place(name: fallbackName, subtitle: '', point: center, category: 'fuel'),
    ];
  }
}

void main() {
  const center = GeoPoint(3.229, 101.426);

  test(
    'gagal -> failed bertanda nearby; retry mengulang kategori sama; cache',
    () async {
      final nearby = _Nearby();
      final container = ProviderContainer(
        overrides: [nearbySearchProvider.overrideWithValue(nearby)],
      );
      addTearDown(container.dispose);
      container.listen(placeSearchControllerProvider, (_, _) {});
      final controller = container.read(placeSearchControllerProvider.notifier);

      controller.searchNearby(
        NearbyCategory.fuel,
        center: center,
        label: 'Fuel',
        fallbackName: 'Fuel',
      );
      expect(
        container.read(placeSearchControllerProvider).status,
        SearchStatus.loading,
      );
      await Future<void>.delayed(Duration.zero);
      var state = container.read(placeSearchControllerProvider);
      expect(state.status, SearchStatus.failed);
      expect(state.failure, GeocodeFailureKind.unavailable);
      expect(state.nearby, NearbyCategory.fuel);

      nearby.fail = false;
      controller.retry();
      await Future<void>.delayed(Duration.zero);
      state = container.read(placeSearchControllerProvider);
      expect(state.status, SearchStatus.results);
      expect(state.origin, center);
      expect(nearby.calls, 2);

      // Ketukan sama dalam ~1 km: dari cache, tiada permintaan baharu.
      controller.searchNearby(
        NearbyCategory.fuel,
        center: const GeoPoint(3.2291, 101.4261),
        label: 'Fuel',
        fallbackName: 'Fuel',
      );
      expect(
        container.read(placeSearchControllerProvider).status,
        SearchStatus.results,
      );
      expect(nearby.calls, 2);
    },
  );
}
