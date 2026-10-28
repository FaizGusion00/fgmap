import 'dart:async';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/data/location_sources.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/navigation/data/trip_record.dart';
import 'package:fgmap/features/navigation/data/trip_store.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import 'nav_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rekod perjalanan pergi dan balik dengan destinasi dan kemajuan', () {
    final option = lShapedRoute(legM: 500);
    final query = RouteQuery(
      origin: option.points.first,
      destination: option.points.last,
      destinationLabel: 'KLIA',
      vehicle: RouteVehicle.motorcycle,
      avoidTolls: true,
    );
    final saved = NavigationTrip(
      savedAt: DateTime.utc(2026, 5, 1),
      route: option,
      query: query,
      alongM: 250,
      language: VoiceLanguage.en,
      position: option.points[4],
      bearing: 90,
      speedMps: 12,
    );
    final back = decodeTrip(encodeTrip(saved));
    expect(back, isA<NavigationTrip>());
    final nav = back! as NavigationTrip;
    expect(nav.query.destinationLabel, 'KLIA');
    expect(nav.query.vehicle, RouteVehicle.motorcycle);
    expect(nav.query.avoidTolls, isTrue);
    expect(nav.alongM, 250);
    expect(nav.route.points.length, option.points.length);
    expect(nav.language, VoiceLanguage.en);
  });

  test('cruise yang sudah lama berhenti tidak dipulihkan', () {
    final stale = CruiseTrip(
      savedAt: DateTime.utc(2026, 1, 1),
      position: const GeoPoint(3, 101),
      bearing: 10,
      speedMps: 0,
    );
    expect(stale.restorable(DateTime.utc(2026, 1, 1, 0, 1)), isFalse);
    final moving = CruiseTrip(
      savedAt: DateTime.utc(2026, 1, 1),
      position: const GeoPoint(3, 101),
      bearing: 10,
      speedMps: 12,
    );
    expect(moving.restorable(DateTime.utc(2026, 1, 1, 0, 2)), isTrue);
  });

  test('pulihkan sebelum sebarang fix: destinasi dan manuver ada, bukan peta kosong', () async {
    final option = lShapedRoute(legM: 2000);
    final navRoute = NavRoute(option);
    final query = RouteQuery(
      origin: option.points.first,
      destination: const GeoPoint(3, 101.05),
      destinationLabel: 'Destinasi',
      avoidTolls: true,
    );
    final record = NavigationTrip(
      savedAt: DateTime.utc(2026, 4, 2),
      route: option,
      query: query,
      alongM: 400,
      language: VoiceLanguage.ms,
      position: navRoute.pointAt(400),
      bearing: 90,
      speedMps: 11,
    );
    SharedPreferences.setMockInitialValues({TripStore.key: encodeTrip(record)!});
    final prefs = await SharedPreferences.getInstance();
    final clock = FakeClock(DateTime.utc(2026, 4, 2, 1));
    final location = FakeLocationService();
    final planner = FakeRoutePlanner((_) async => [option]);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        navClockProvider.overrideWithValue(clock.call),
        reportsClockProvider.overrideWithValue(clock.call),
        voiceGuideProvider.overrideWithValue(FakeVoice()),
        screenAwakeProvider.overrideWithValue(FakeAwake()),
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        routePlannerProvider.overrideWithValue(planner),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(navigationControllerProvider);
    expect(state.isActive, isTrue);
    expect(state.phase, NavPhase.active);
    expect(state.query!.destinationLabel, 'Destinasi');
    expect(state.query!.avoidTolls, isTrue);
    expect(state.progress, isNotNull);
    expect(state.progress!.alongM, closeTo(400, 1));
    expect(state.progress!.next, isNotNull);
    expect(state.route!.points, isNotEmpty);

    final off = destinationPoint(navRoute.pointAt(400), 0, 500);
    for (var i = 0; i < 4; i++) {
      clock.now = DateTime.utc(2026, 4, 2, 1, 0, i);
      location.navigationController.add(
        LocationFix(
          point: off,
          headingDegrees: 0,
          accuracyMeters: 8,
          speedMps: 12,
          timestamp: clock.now,
        ),
      );
      await pumpEventQueue();
    }
    await pumpEventQueue();
    expect(container.read(navigationControllerProvider).isActive, isTrue);
    expect(planner.queries, isNotEmpty);
    final reroute = planner.queries.single;
    expect(reroute.destination, query.destination);
    expect(reroute.destinationLabel, 'Destinasi');
    expect(reroute.urgent, isTrue);
    expect(reroute.alternates, 0);
    expect(reroute.avoidTolls, isTrue);
  });

  test('latar belakang: GPS kekal, wakelock skrin dilepaskan; tamat memadam rekod', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final clock = FakeClock();
    final voice = FakeVoice();
    final awake = FakeAwake();
    final option = lShapedRoute();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        navClockProvider.overrideWithValue(clock.call),
        reportsClockProvider.overrideWithValue(clock.call),
        voiceGuideProvider.overrideWithValue(voice),
        screenAwakeProvider.overrideWithValue(awake),
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        routePlannerProvider.overrideWithValue(FakeRoutePlanner((_) async => [option])),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
      ],
    );
    addTearDown(container.dispose);
    final source = _HoldSource();
    final ok = await container.read(navigationControllerProvider.notifier).start(
      option,
      RouteQuery(
        origin: option.points.first,
        destination: option.points.last,
        destinationLabel: 'Rumah',
      ),
      uiLanguage: VoiceLanguage.ms,
      source: source,
    );
    expect(ok, isTrue);
    await pumpEventQueue();
    expect(prefs.getString(TripStore.key), isNotNull);
    expect(source.listeners, 1);

    container.read(navigationControllerProvider.notifier).noteBackground(true);
    await pumpEventQueue();
    expect(awake.enabled, isFalse);
    expect(source.listeners, 1);
    expect(container.read(navigationControllerProvider).isActive, isTrue);

    await container.read(navigationControllerProvider.notifier).stop();
    expect(prefs.getString(TripStore.key), isNull);
    expect(source.listeners, 0);
    expect(container.read(navigationControllerProvider).isActive, isFalse);
  });
}

class _HoldSource implements NavLocationSource {
  _HoldSource() {
    _controller = StreamController<LocationFix>.broadcast(
      onListen: () => listeners++,
      onCancel: () => listeners--,
    );
  }

  late final StreamController<LocationFix> _controller;
  int listeners = 0;

  @override
  bool get isSimulated => false;

  @override
  Stream<LocationFix> fixes() => _controller.stream;
}
