import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/network/connectivity_probe.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/local_assistant/data/tool_executor.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
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

  test('currentLocation guna GPS, bukan geokod nama tempat', () async {
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(
          FakeLocationService(
            accessValue: LocationAccess.granted,
            fix: const LocationFix(point: GeoPoint(3.15, 101.7)),
          ),
        ),
        reverseGeocoderProvider.overrideWithValue(
          _FakeReverse(
            const Place(
              name: 'Near KL',
              subtitle: 'Kuala Lumpur',
              point: GeoPoint(3.15, 101.7),
            ),
          ),
        ),
        geocoderProvider.overrideWithValue(
          _FakeGeocoder([
            const Place(
              name: 'Batu Arang Heritage Town',
              subtitle: 'nonsense',
              point: GeoPoint(3.3, 101.5),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(assistantToolExecutorProvider)
        .currentLocation();
    expect(result['ok'], isTrue);
    expect(result['lat'], closeTo(3.15, 0.001));
    expect(result['lng'], closeTo(101.7, 0.001));
    expect(result['place'], contains('Near KL'));
    expect(result['source'], 'gps');
  });

  test('currentLocation tanpa GPS: no_location', () async {
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(
          FakeLocationService(accessValue: LocationAccess.deniedForever),
        ),
      ],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(assistantToolExecutorProvider)
        .currentLocation();
    expect(result['ok'], isFalse);
    expect(result['error'], 'no_location');
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

  group('ralat jujur (bukan semuanya "luar talian")', () {
    ProviderContainer build({
      required Geocoder geocoder,
      bool online = true,
      RoutePreviewController Function()? preview,
    }) {
      final c = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(
            FakeLocationService(
              accessValue: LocationAccess.granted,
              fix: const LocationFix(point: GeoPoint(3.15, 101.7)),
            ),
          ),
          geocoderProvider.overrideWithValue(geocoder),
          onlineProbeProvider.overrideWithValue(() async => online),
          if (preview != null)
            routePreviewControllerProvider.overrideWith(preview),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    DioException http(int status) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
      ),
      type: DioExceptionType.badResponse,
    );

    test('Photon 429 semasa ONLINE = sibuk, bukan luar talian', () async {
      final c = build(geocoder: _ThrowingGeocoder(http(429)));
      final r = await c.read(assistantToolExecutorProvider).planRoute('klcc');
      expect(r['ok'], isFalse);
      expect(r['error'], 'busy');
    });

    test('Photon 503 semasa ONLINE = perkhidmatan tidak menjawab', () async {
      final c = build(geocoder: _ThrowingGeocoder(http(503)));
      final r = await c.read(assistantToolExecutorProvider).planRoute('klcc');
      expect(r['error'], 'service_down');
    });

    test(
      'tamat masa semasa ONLINE = lambat; sebenar-benar luar talian = offline',
      () async {
        final online = build(
          geocoder: _ThrowingGeocoder(TimeoutException('x')),
        );
        expect(
          (await online
              .read(assistantToolExecutorProvider)
              .planRoute('klcc'))['error'],
          'slow',
        );
        final off = build(
          geocoder: _ThrowingGeocoder(
            const SocketException('Failed host lookup'),
          ),
          online: false,
        );
        expect(
          (await off
              .read(assistantToolExecutorProvider)
              .planRoute('klcc'))['error'],
          'offline',
        );
      },
    );

    test('ralat sementara diulang sekali sebelum mengalah', () async {
      final g = _FlakyGeocoder(
        failures: 1,
        place: const Place(
          name: 'KLCC',
          subtitle: 'KL',
          point: GeoPoint(3.1579, 101.7116),
        ),
      );
      final c = build(geocoder: g, preview: () => _FakeRoutePreview());
      final r = await c.read(assistantToolExecutorProvider).planRoute('klcc');
      expect(r['ok'], isTrue);
      expect(g.calls, 2);
    });

    test(
      'luar talian + tiada padanan = offline_not_found (sebut pek peta)',
      () async {
        final c = build(geocoder: _FakeGeocoder(const []), online: false);
        final r = await c
            .read(assistantToolExecutorProvider)
            .planRoute('masjid xyz');
        expect(r['error'], 'offline_not_found');
        expect(r['query'], 'masjid xyz');
      },
    );

    test(
      'ejaan dirapatkan dicuba berturutan: attaufiqiah -> at taufiqiah',
      () async {
        final g = _VariantGeocoder(
          match: 'masjid at taufiqiah',
          place: const Place(
            name: 'Masjid At-Taufiqiah',
            subtitle: 'Kuala Terengganu',
            point: GeoPoint(5.33, 103.14),
          ),
        );
        final c = build(geocoder: g, preview: () => _FakeRoutePreview());
        final r = await c
            .read(assistantToolExecutorProvider)
            .planRoute('masjid attaufiqiah');
        expect(r['ok'], isTrue);
        expect(r['destination'], 'Masjid At-Taufiqiah');
        expect(g.queries, ['masjid attaufiqiah', 'masjid at taufiqiah']);
      },
    );

    test('kegagalan laluan dipetakan mengikut jenis', () {
      RoutePreviewState failed(RoutingFailureKind k) => RouteFailed(
        query: const RouteQuery(
          origin: GeoPoint(3.1, 101.6),
          destination: GeoPoint(3.2, 101.7),
        ),
        kind: k,
      );
      expect(
        routeFailureCode(failed(RoutingFailureKind.noRoute)),
        'no_drivable_route',
      );
      expect(routeFailureCode(failed(RoutingFailureKind.rateLimited)), 'busy');
      expect(
        routeFailureCode(failed(RoutingFailureKind.unavailable)),
        'service_down',
      );
      expect(
        routeFailureCode(failed(RoutingFailureKind.offlineRequired)),
        'offline_pack_needed',
      );
      expect(
        routeFailureCode(failed(RoutingFailureKind.network), online: true),
        'slow',
      );
      expect(
        routeFailureCode(failed(RoutingFailureKind.network), online: false),
        'offline',
      );
      expect(routeFailureCode(const RouteIdle()), 'route_timeout');
    });
  });
}

class _FakeGeocoder implements Geocoder {
  _FakeGeocoder(this.places);
  final List<Place> places;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async =>
      places;
}

class _FakeReverse implements ReverseGeocoder {
  _FakeReverse(this.place);
  final Place? place;

  @override
  Future<Place?> reverse(GeoPoint point, {cancel}) async => place;
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

class _ThrowingGeocoder implements Geocoder {
  _ThrowingGeocoder(this.error);
  final Object error;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async =>
      throw error;
}

class _FlakyGeocoder implements Geocoder {
  _FlakyGeocoder({required this.failures, required this.place});
  final int failures;
  final Place place;
  int calls = 0;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async {
    calls++;
    if (calls <= failures) throw TimeoutException('sementara');
    return [place];
  }
}

class _VariantGeocoder implements Geocoder {
  _VariantGeocoder({required this.match, required this.place});
  final String match;
  final Place place;
  final List<String> queries = [];

  @override
  Future<List<Place>> search(String query, {GeoPoint? near, cancel}) async {
    queries.add(query);
    return query == match ? [place] : const [];
  }
}
