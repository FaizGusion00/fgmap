import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/core/config/app_config.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/features/music/presentation/player_controller.dart';
import 'package:fgmap/features/navigation/presentation/car_session_hub.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../music/music_test_support.dart';

class _UrlLoader extends MapStyleLoader {
  _UrlLoader() : super(Dio(), null);

  @override
  Future<ResolvedMapStyle> resolve({required bool dark}) async =>
      const ResolvedMapStyle(
        AppConfig.mapStyleLight,
        'url:${AppConfig.mapStyleLight}',
      );
}

/// Hab sesi kereta tanpa skrin telefon: inilah keadaan bila FGMaps dibuka terus dari Android Auto,
/// atau app telefon di latar dengan skrin telefon padam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();

  late FakeLocationService location;
  late List<MethodCall> sent;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    location = FakeLocationService();
    sent = [];
    messenger.setMockMethodCallHandler(carSessionChannel, (call) async {
      sent.add(call);
      return null;
    });
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(location),
        mapStyleLoaderProvider.overrideWithValue(_UrlLoader()),
        // Skrin kereta kelihatan menghidupkan perkhidmatan muzik (bahagian media Android Auto).
        musicEngineProvider.overrideWithValue(FakeMusicEngine()),
        audioServiceStarterProvider.overrideWithValue(null),
      ],
    );
    container.read(carSessionHubProvider);
  });

  tearDown(() {
    container.dispose();
    messenger.setMockMethodCallHandler(carSessionChannel, null);
  });

  /// Panggilan daripada hos kereta (Kotlin) ke Dart; pulangkan jawapan atau lempar PlatformException.
  Future<Object?> fromCar(String method, [Object? arguments]) async {
    final reply = Completer<ByteData?>();
    await messenger.handlePlatformMessage(
      carSessionChannel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      reply.complete,
    );
    return codec.decodeEnvelope((await reply.future)!);
  }

  Map<Object?, Object?> lastSession() =>
      sent.lastWhere((c) => c.method == 'session').arguments as Map;

  test(
    'skrin kereta kelihatan tanpa app telefon: GPS sendiri, peta kereta di lokasi pengguna',
    () async {
      expect(location.trackingController.hasListener, isFalse);

      await fromCar('carState', {'visible': true, 'dark': false});
      expect(location.trackingController.hasListener, isTrue);

      location.trackingController.add(
        LocationFix(
          point: const GeoPoint(2.1583, 102.659),
          accuracyMeters: 8,
          timestamp: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final session = lastSession();
      expect(session['lat'], closeTo(2.1583, 1e-6));
      expect(session['lng'], closeTo(102.659, 1e-6));
      // Gaya peta dihantar: dahulu peta kereta kosong tanpa app telefon.
      expect(session['style'], isNotNull);

      // Skrin kereta ditutup: GPS skrin kereta berhenti (bateri).
      await fromCar('carState', {'visible': false, 'dark': false});
      expect(location.trackingController.hasListener, isFalse);
    },
  );

  test(
    'telefon bersambung ke Android Auto: muzik FGMaps disediakan untuk bahagian media kereta',
    () async {
      expect(container.exists(playerControllerProvider), isFalse);
      await fromCar('carState', {
        'visible': false,
        'dark': false,
        'connected': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.exists(playerControllerProvider), isTrue);
    },
  );

  test('fix lapuk atau terlalu kasar tidak menggerakkan peta kereta', () async {
    await fromCar('carState', {'visible': true, 'dark': false});
    location.trackingController
      ..add(
        LocationFix(
          point: const GeoPoint(5, 100),
          accuracyMeters: 8,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      )
      ..add(
        LocationFix(
          point: const GeoPoint(6, 100),
          accuracyMeters: 800,
          timestamp: DateTime.now(),
        ),
      );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final call in sent.where((c) => c.method == 'session')) {
      expect((call.arguments as Map)['lat'], isNot(anyOf(5.0, 6.0)));
    }
  });

  test(
    'Berdekatan tanpa GPS: kod no-location (bukan "semak internet")',
    () async {
      location.accessValue = LocationAccess.askable;
      await expectLater(
        fromCar('nearby', {'category': 'fuel'}),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'no-location'),
        ),
      );
    },
  );

  group('sumber native Android Auto', () {
    const dir = 'android/app/src/main/kotlin/com/fguniversalempire/fgmaps';

    test(
      'skrin kereta memulakan enjin Flutter sendiri, bukan membuka app telefon',
      () {
        final screens = File('$dir/car/FgMapCarScreens.kt').readAsStringSync();
        final bridge = File('$dir/car/CarBridge.kt').readAsStringSync();
        expect(screens, contains('CarBridge.ensureEngine(carContext)'));
        expect(screens, isNot(contains('launchPhone')));
        // Enjin yang sama dengan MainActivity (AudioServiceActivity).
        expect(bridge, contains('AudioServicePlugin.getFlutterEngine'));
        expect(
          File('$dir/MainActivity.kt').readAsStringSync(),
          contains('CarBridge.attach(flutterEngine)'),
        );
      },
    );

    test('kod ralat Dart dibaca Kotlin', () {
      final bridge = File('$dir/car/CarBridge.kt').readAsStringSync();
      expect(bridge, contains('"no-location"'));
    });

    test('hab dicipta sebelum runApp (enjin tanpa paparan)', () {
      final main = File('lib/main.dart').readAsStringSync();
      final read = main.indexOf('container.read(carSessionHubProvider)');
      expect(read, greaterThan(0));
      expect(read, lessThan(main.indexOf('runApp(')));
    });
  });
}
