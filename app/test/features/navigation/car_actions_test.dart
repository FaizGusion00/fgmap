import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fgmap/core/config/app_config.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/data/map_layer.dart';
import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/features/navigation/data/navigation_settings.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/navigation/presentation/car_session_hub.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/saved_places/data/saved_places_controller.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/search_history_controller.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import 'nav_test_support.dart';

class _UrlLoader extends MapStyleLoader {
  _UrlLoader() : super(Dio(), null);

  @override
  Future<ResolvedMapStyle> resolve({required bool dark}) async =>
      const ResolvedMapStyle(
        AppConfig.mapStyleLight,
        'url:${AppConfig.mapStyleLight}',
      );
}

/// Ciri app telefon di skrin Android Auto, melalui saluran yang sama dengan hos kereta Kotlin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  const here = GeoPoint(3.1390, 101.6869);

  late ProviderContainer container;
  late FakeRoutePlanner planner;
  late FakeLocationService location;

  setUp(() async {
    // Bahasa peranti Melayu: teks kereta (label laluan, "Rumah") dalam BM.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = const Locale('ms');
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    location = FakeLocationService(fix: const LocationFix(point: here));
    planner = FakeRoutePlanner(
      (_) async => [
        sampleOption(
          durationS: 1500,
          distanceM: 18200,
          hasTolls: false,
          label: RouteLabel.recommended,
          points: [here, klcc],
        ),
        sampleOption(
          durationS: 1800,
          distanceM: 16000,
          hasTolls: false,
          label: RouteLabel.shortest,
          points: [here, batuCaves, klcc],
        ),
      ],
    );
    messenger.setMockMethodCallHandler(carSessionChannel, (_) async => null);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(location),
        mapStyleLoaderProvider.overrideWithValue(_UrlLoader()),
        routePlannerProvider.overrideWithValue(planner),
        routeOptionsPlannerProvider.overrideWithValue(planner),
        voiceGuideProvider.overrideWithValue(FakeVoice()),
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        screenAwakeProvider.overrideWithValue(FakeAwake()),
      ],
    );
    container.read(carSessionHubProvider);
  });

  tearDown(() {
    container.dispose();
    messenger.setMockMethodCallHandler(carSessionChannel, null);
  });

  Future<Object?> fromCar(String method, [Object? arguments]) async {
    final reply = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      carSessionChannel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      reply.complete,
    );
    return codec.decodeEnvelope((await reply.future)!);
  }

  test('Tempat: Rumah, Kerja, kegemaran dan terkini dengan jarak', () async {
    final saved = container.read(savedPlacesControllerProvider.notifier);
    await saved.setHome(
      const Place(name: 'Taman Melawati', subtitle: 'KL', point: klcc),
    );
    await saved.toggleFavorite(
      const Place(
        name: 'Batu Caves',
        subtitle: 'Gombak, Selangor',
        point: batuCaves,
      ),
    );
    await container
        .read(searchHistoryControllerProvider.notifier)
        .record(const Place(name: 'KLIA', subtitle: 'Sepang', point: klia));

    final hub = (await fromCar('places') as Map).cast<String, Object?>();
    final home = (hub['home'] as Map).cast<String, Object?>();
    expect(home['name'], 'Rumah');
    expect(home['meters'], greaterThan(0));
    expect(hub['work'], isNull);
    expect((hub['favorites'] as List).single['name'], 'Batu Caves');
    expect((hub['favorites'] as List).single['area'], 'Gombak');
    expect((hub['recents'] as List).single['name'], 'KLIA');
  });

  test(
    'pilihan laluan: masa, jarak, label dan garisan; Mula memulakan navigasi',
    () async {
      final rows =
          (await fromCar('preview', {
                    'name': 'KLCC',
                    'lat': klcc.lat,
                    'lng': klcc.lng,
                  })
                  as List)
              .cast<Map>();
      expect(rows, hasLength(2));
      expect(rows.first['durationS'], 1500);
      expect(rows.first['title'], 'Disyorkan');
      expect(rows.first['detail'], contains('Tiada tol'));
      expect(rows.last['points'], hasLength(3));

      container.listen(navigationControllerProvider, (_, _) {});
      expect(await fromCar('startPreview', {'index': 1}), isNull);
      final nav = container.read(navigationControllerProvider);
      expect(nav.isActive, isTrue);
      expect(nav.route?.option.distanceM, 16000);
      await container.read(navigationControllerProvider.notifier).stop();
    },
  );

  test('tiada laluan: kod no-route, bukan senarai kosong', () async {
    planner.handler = (_) async => const [];
    await expectLater(
      fromCar('preview', {'name': 'X', 'lat': 3.0, 'lng': 101.0}),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'no-route'),
      ),
    );
    expect(await fromCar('startPreview', {'index': 0}), 'no-route');
  });

  test('pilihan laluan tanpa GPS: kod no-location', () async {
    location
      ..fix = null
      ..accessValue = LocationAccess.askable;
    await expectLater(
      fromCar('preview', {'name': 'X', 'lat': 3.0, 'lng': 101.0}),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'no-location'),
      ),
    );
  });

  test('Lapor dari kereta: laporan dicipta di kedudukan semasa', () async {
    final types = (await fromCar('reportTypes') as List).cast<Map>();
    expect(types.map((t) => t['id']), contains('police'));
    expect(await fromCar('report', {'type': 'police'}), 'created');
    expect(container.read(reportsControllerProvider), hasLength(1));
    expect(await fromCar('report', {'type': 'police'}), 'confirmed');
    expect(await fromCar('report', {'type': 'bukan'}), 'failed');
  });

  test('Tetapan kereta mengubah tetapan telefon yang sama', () async {
    final before = (await fromCar('settings') as Map).cast<String, Object?>();
    expect(before['voice'], isTrue);
    expect(before['satellite'], isFalse);

    final after =
        (await fromCar('setSetting', {'key': 'voice', 'value': false}) as Map)
            .cast<String, Object?>();
    expect(after['voice'], isFalse);
    expect(container.read(navigationSettingsProvider).voiceEnabled, isFalse);

    await fromCar('setSetting', {'key': 'avoidTolls', 'value': true});
    expect(container.read(routeTollFilterProvider), RouteTollFilter.noTolls);
    await fromCar('setSetting', {'key': 'satellite', 'value': true});
    expect(container.read(mapLayerProvider), MapLayer.satellite);
  });

  test('status suara dihantar ke peta kereta (butang senyap)', () async {
    final sent = <MethodCall>[];
    messenger.setMockMethodCallHandler(carSessionChannel, (call) async {
      sent.add(call);
      return null;
    });
    await container
        .read(navigationSettingsProvider.notifier)
        .setVoiceEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final session = sent.lastWhere((c) => c.method == 'session').arguments;
    expect((session as Map)['voice'], isFalse);
  });
}
