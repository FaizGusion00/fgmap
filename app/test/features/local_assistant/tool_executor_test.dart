import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/local_assistant/data/tool_executor.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  test('search_place memulangkan lat/lng daripada geocoder', () async {
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            accessValue: LocationAccess.granted,
            fix: const LocationFix(point: GeoPoint(3.15, 101.7)),
          ),
        ),
        geocoderProvider.overrideWithValue(
          _FakeGeocoder([
            const Place(
              name: 'Masjid Negara',
              subtitle: 'Kuala Lumpur',
              point: GeoPoint(3.1419, 101.6865),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final result = await container.read(assistantToolExecutorProvider).run(
      'search_place',
      {'query': 'Masjid Negara'},
    );
    expect(result['ok'], isTrue);
    final places = result['places'] as List;
    expect(places, isNotEmpty);
    expect((places.first as Map)['name'], 'Masjid Negara');
    expect((places.first as Map)['lat'], closeTo(3.1419, 0.001));
  });

  test('plan_route memilih pilihan tanpa tol bila diminta', () async {
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            accessValue: LocationAccess.granted,
            fix: const LocationFix(point: GeoPoint(3.15, 101.7)),
          ),
        ),
        geocoderProvider.overrideWithValue(
          _FakeGeocoder([
            const Place(
              name: 'KLCC',
              subtitle: 'KL',
              point: GeoPoint(3.1579, 101.7116),
            ),
          ]),
        ),
        routePreviewControllerProvider.overrideWith(() => _FakeRoutePreview()),
      ],
    );
    addTearDown(container.dispose);
    final result = await container.read(assistantToolExecutorProvider).run(
      'plan_route',
      {'query': 'KLCC', 'avoid_tolls': true},
    );
    expect(result['ok'], isTrue);
    expect(result['has_tolls'], isFalse);
    expect(result['label'], RouteLabel.noTolls.name);
    final preview = container.read(routePreviewControllerProvider);
    expect(preview, isA<RouteReady>());
    expect((preview as RouteReady).selected.label, RouteLabel.noTolls);
  });

  test('alat asing ditolak', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final result = await container
        .read(assistantToolExecutorProvider)
        .run('drop_tables', {});
    expect(result['ok'], isFalse);
    expect(result['error'], 'unknown_tool');
  });
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder(this.places);
  final List<Place> places;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async =>
      places;
}

class _FakeRoutePreview extends RoutePreviewController {
  @override
  RoutePreviewState build() => const RouteIdle();

  @override
  Future<void> planTo(
    GeoPoint destination, {
    String? destinationLabel,
    double? radiusM,
    List<GeoPoint> via = const [],
  }) async {
    state = RouteReady(
      query: RouteQuery(
        origin: const GeoPoint(3.15, 101.7),
        destination: destination,
        destinationLabel: destinationLabel,
      ),
      options: [
        RouteOption(
          distanceM: 12000,
          durationS: 900,
          hasTolls: true,
          points: [const GeoPoint(3.15, 101.7), destination],
          label: RouteLabel.fastest,
        ),
        RouteOption(
          distanceM: 14000,
          durationS: 1100,
          hasTolls: false,
          points: [const GeoPoint(3.15, 101.7), destination],
          label: RouteLabel.noTolls,
        ),
      ],
    );
  }
}
