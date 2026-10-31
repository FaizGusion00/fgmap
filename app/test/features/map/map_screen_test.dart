import 'dart:async';

import 'package:fgmap/core/config/app_config.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/platform/external_actions.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/reports/domain/report.dart';
import 'package:fgmap/features/reports/presentation/report_alerts_controller.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:fgmap/features/saved_places/data/saved_places_controller.dart';
import 'package:fgmap/features/settings/presentation/settings_page.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/core/theme/theme_controller.dart';
import 'package:fgmap/features/map/presentation/idle_follow.dart';
import 'package:fgmap/features/map/presentation/map_screen.dart';
import 'package:fgmap/features/music/presentation/player_controller.dart';
import 'package:fgmap/core/audio/audio_coordinator.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart'
    show CameraPose;
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../music/music_test_support.dart';

/// Gaya segera (tiada rangkaian): gelap = URL gelap. Ujian yang mahu JSON malam guna [_NightLoader].
class _UrlLoader extends MapStyleLoader {
  _UrlLoader() : super(Dio(), null);

  @override
  Future<ResolvedMapStyle> resolve({required bool dark}) async => dark
      ? const ResolvedMapStyle(
          AppConfig.mapStyleDark,
          'url:${AppConfig.mapStyleDark}',
        )
      : light();
}

class _NightLoader extends MapStyleLoader {
  _NightLoader() : super(Dio(), null);

  @override
  Future<ResolvedMapStyle> resolve({required bool dark}) async => dark
      ? const ResolvedMapStyle('{"version":8,"layers":[]}', 'night:test')
      : light();
}

class _Reverse implements ReverseGeocoder {
  Place? result;
  bool fail = false;

  @override
  Future<Place?> reverse(GeoPoint point, {CancelToken? cancel}) async {
    if (fail) throw const GeocodeFailure(GeocodeFailureKind.network);
    return result;
  }
}

void main() {
  late _Reverse reverse;
  late FakeShareService share;
  late FakePhoneDialer dialer;
  late FakeMapHarness map;
  late FakeLocationService location;
  late FakeRoutePlanner repo;
  late SharedPreferences prefs;

  setUp(() async {
    reverse = _Reverse();
    share = FakeShareService();
    dialer = FakePhoneDialer();
    map = FakeMapHarness();
    location = FakeLocationService(fix: const LocationFix(point: klcc));
    repo = FakeRoutePlanner(
      (_) async => [
        sampleOption(),
        // Titik berbeza: laluan alternatif bukan laluan yang sama.
        sampleOption(
          durationS: 3722,
          distanceM: 72447,
          points: const [klcc, batuCaves, klia],
          label: RouteLabel.alternative,
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    Duration recenterAfter = const Duration(hours: 1),
    List<Override> extra = const [],
    bool settle = true,
  }) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const MapScreen(),
      overrides: [
        map.override,
        locationServiceProvider.overrideWithValue(location),
        routeOptionsPlannerProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        idleRecenterAfterProvider.overrideWithValue(recenterAfter),
        mapStyleLoaderProvider.overrideWithValue(_UrlLoader()),
        reverseGeocoderProvider.overrideWithValue(reverse),
        shareServiceProvider.overrideWithValue(share),
        phoneDialerProvider.overrideWithValue(dialer),
        ...extra,
      ],
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Navigasi menganimasikan tanpa henti: pam terhad.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    return ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
  }

  testWidgets('keadaan awal: petunjuk long-press dan kawalan peta kelihatan', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
    expect(
      find.text('Tekan lama pada peta untuk pilih destinasi'),
      findsNothing,
      reason:
          'petunjuk kekal sebagai hint aksesibiliti supaya pil lebih rendah',
    );
    expect(find.byTooltip('Lokasi saya'), findsOneWidget);
    expect(find.byTooltip('Zum masuk'), findsOneWidget);
    expect(find.byTooltip('Zum keluar'), findsOneWidget);
    expect(find.byTooltip('Tetapan'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('search-pill'))).height,
      lessThanOrEqualTo(64),
    );
    expect(find.text('Mengira laluan…'), findsNothing);
    expect(map.config!.routes, isEmpty);
    expect(map.config!.destination, isNull);
  });

  testWidgets(
    'pemain muzik kecil mengelak bar navigasi sistem (Android 3-butang) dan boleh diketik',
    (tester) async {
      // Bar navigasi 48 dp di bawah skrin: butang di bawahnya tidak boleh diketik.
      tester.view.viewPadding = const FakeViewPadding(bottom: 48 * 3);
      tester.view.padding = const FakeViewPadding(bottom: 48 * 3);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final engine = FakeMusicEngine();
      final c = await pumpScreen(
        tester,
        extra: [
          musicEngineProvider.overrideWithValue(engine),
          audioCoordinatorProvider.overrideWithValue(AudioCoordinator()),
          audioServiceStarterProvider.overrideWithValue(null),
        ],
      );
      await c
          .read(playerControllerProvider.notifier)
          .playTrack(track('r1', title: 'Sinar FM'));
      // Pemutar memuat (gelendong berputar): pam terhad, bukan pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final mini = find.byKey(const ValueKey('mini-player'));
      expect(mini, findsOneWidget);
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getBottomLeft(mini).dy,
        lessThanOrEqualTo(screenHeight - 48),
        reason: 'pemain muzik tidak boleh berada di bawah bar navigasi sistem',
      );
      // Butang tutup berada dalam kawasan yang boleh diketik.
      final toggle = find.byKey(const ValueKey('mini-close'));
      expect(
        tester.getBottomLeft(toggle).dy,
        lessThanOrEqualTo(screenHeight - 48),
      );
    },
  );

  testWidgets(
    'laluan navigasi dipudarkan hanya semasa re-route (garisan lama bukan arah yang patut diikut)',
    (tester) async {
      await pumpScreen(
        tester,
        settle: false,
        extra: [navigationControllerProvider.overrideWith(_ReroutingNav.new)],
      );
      expect(map.config!.navStale, isTrue);
    },
  );

  testWidgets('tanpa navigasi laluan tidak dipudarkan', (tester) async {
    await pumpScreen(tester);
    expect(map.config!.navStale, isFalse);
  });

  testWidgets('butang zum mengubah aras zum kamera', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Zum masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zum keluar'));
    await tester.pumpAndSettle();

    expect(map.camera.zoomByCalls, [1, -1]);
  });

  testWidgets(
    'long-press -> laluan dikira, lembaran dipaparkan, peta menerima laluan dan destinasi',
    (tester) async {
      await pumpScreen(tester);

      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();

      expect(
        find.text('58 min'),
        findsWidgets,
      ); // tajuk lembaran + chip laluan 1
      expect(find.text('67.0 km'), findsWidgets); // tajuk + kad laluan 1
      expect(find.text('Ada tol'), findsOneWidget);
      expect(find.byKey(const ValueKey('route-option-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-option-1')), findsOneWidget);
      // Semua pilihan terpapar serta-merta dengan label bermakna, tanpa menekan sebarang butang.
      expect(find.text('Terpantas'), findsOneWidget);
      expect(find.text('Alternatif'), findsOneWidget);
      expect(find.text('Elak tol'), findsNothing);
      expect(repo.queries, hasLength(1));

      final cfg = map.config!;
      expect(cfg.destination, klia);
      expect(cfg.routes, hasLength(2));
      expect(cfg.routes.where((r) => r.isMain), hasLength(1));
      // Laluan utama dilukis terakhir (paling atas).
      expect(cfg.routes.last.isMain, isTrue);

      // Asal ialah lokasi pengguna (fix), bukan pusat peta.
      expect(repo.queries.single.origin, klcc);

      // Kamera memuatkan laluan dalam pandangan dengan ruang untuk lembaran bawah.
      expect(map.camera.fitToCalls, hasLength(1));
      expect(map.camera.fitToCalls.single.$2.bottom, greaterThan(200));

      // Petunjuk tekan-lama disorok selepas pengguna mencuba; pil carian kekal.
      expect(
        find.text('Tekan lama pada peta untuk pilih destinasi'),
        findsNothing,
      );
      expect(find.text('Ke mana?'), findsOneWidget);
    },
  );

  testWidgets(
    'memilih kad laluan kedua menukar laluan utama tanpa menyesuaikan semula kamera',
    (tester) async {
      await pumpScreen(tester);
      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();
      final mainBefore = map.config!.routes.last.points;

      await tester.tap(find.byKey(const ValueKey('route-option-1')));
      await tester.pumpAndSettle();

      expect(
        find.text('1 j 2 min'),
        findsWidgets,
      ); // 3722 s -> 62 min -> 1 j 2 min (tajuk + kad)
      expect(map.config!.routes.last.points, isNot(same(mainBefore)));
      expect(
        map.camera.fitToCalls,
        hasLength(1),
        reason: 'bertukar laluan tidak menggerakkan kamera',
      );
    },
  );

  testWidgets('mengetuk laluan alternatif pada peta memilihnya', (
    tester,
  ) async {
    await pumpScreen(tester);
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
    final mainBefore = map.config!.routes.last.points;
    expect(map.config!.onTap, isNotNull);

    // Titik pada garis klcc -> batuCaves, yang hanya dilalui laluan alternatif.
    map.config!.onTap!(
      GeoPoint((klcc.lat + batuCaves.lat) / 2, (klcc.lng + batuCaves.lng) / 2),
    );
    await tester.pumpAndSettle();

    expect(map.config!.routes.last.points, isNot(same(mainBefore)));
    expect(map.config!.routes.last.points, contains(batuCaves));
  });

  testWidgets(
    'mengetuk peta jauh dari mana-mana laluan tidak mengubah pilihan',
    (tester) async {
      await pumpScreen(tester);
      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();
      final mainBefore = map.config!.routes.last.points;

      map.config!.onTap!(const GeoPoint(5.0, 100.0));
      await tester.pumpAndSettle();

      expect(map.config!.routes.last.points, same(mainBefore));
    },
  );

  testWidgets('menukar kenderaan mengira semula untuk kenderaan baharu', (
    tester,
  ) async {
    await pumpScreen(tester);
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Motosikal'));
    await tester.pumpAndSettle();

    expect(repo.queries, hasLength(2));
    expect(repo.queries.last.vehicle, RouteVehicle.motorcycle);
  });

  testWidgets(
    'semasa mengira laluan: destinasi dipaparkan dan boleh dibatalkan',
    (tester) async {
      final pending = Completer<List<RouteOption>>();
      repo.handler = (_) => pending.future;
      await pumpScreen(tester);
      map.config!.onLongPress(klia);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('route-cancel')), findsOneWidget);
      expect(map.config!.destination, klia);

      await tester.tap(find.byKey(const ValueKey('route-cancel')));
      await tester.pumpAndSettle();
      pending.complete([sampleOption()]);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('route-cancel')), findsNothing);
      expect(map.config!.routes, isEmpty);
    },
  );

  testWidgets('padam laluan menutup lembaran dan mengosongkan peta', (
    tester,
  ) async {
    await pumpScreen(tester);
    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Padam laluan'), findsOneWidget);

    await tester.tap(find.byTooltip('Padam laluan'));
    await tester.pumpAndSettle();

    expect(find.text('Ada tol'), findsNothing);
    expect(map.config!.routes, isEmpty);
    expect(map.config!.destination, isNull);
  });

  testWidgets('tiada laluan: mesej mesra tanpa butang Cuba lagi', (
    tester,
  ) async {
    repo.handler = (_) async =>
        throw const RoutingFailure(RoutingFailureKind.noRoute);
    await pumpScreen(tester);

    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiada laluan ditemui'), findsOneWidget);
    expect(find.text('Cuba lagi'), findsNothing);
    expect(find.text('Padam laluan'), findsOneWidget);
    expect(
      map.config!.destination,
      klia,
      reason: 'penanda destinasi kekal supaya pengguna nampak apa yang gagal',
    );
  });

  testWidgets('server tidak tersedia: butang Cuba lagi memulihkan', (
    tester,
  ) async {
    var attempts = 0;
    repo.handler = (_) async {
      attempts++;
      if (attempts == 1) {
        throw const RoutingFailure(RoutingFailureKind.unavailable);
      }
      return [sampleOption()];
    };
    await pumpScreen(tester);

    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();
    expect(find.textContaining('tidak tersedia'), findsOneWidget);

    await tester.tap(find.text('Cuba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('58 min'), findsWidgets);
    expect(attempts, 2);
  });

  testWidgets('tanpa GPS tepat: laluan tidak bermula dari pusat peta', (
    tester,
  ) async {
    await pumpScreen(tester);
    location.fix = null;

    map.config!.onLongPress(klia);
    await tester.pumpAndSettle();

    expect(repo.queries, isEmpty);
    expect(
      find.textContaining('Lokasi GPS yang tepat belum tersedia'),
      findsOneWidget,
    );
    expect(map.config!.destination, klia);
  });

  group('ikut lokasi semasa idle (gaya Waze)', () {
    const farAway = GeoPoint(3.20, 101.70); // ~6 km dari klcc
    LocationFix at(GeoPoint p) => LocationFix(point: p, accuracyMeters: 6);

    Future<void> moveTo(WidgetTester tester, GeoPoint p) async {
      location.trackingController.add(at(p));
      await tester.pump();
    }

    testWidgets('selepas pelancaran kamera terus mengikut pengguna bergerak', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(location.trackingListens, 1);

      await moveTo(tester, farAway);

      expect(map.camera.animateToCalls, hasLength(1));
      expect(map.camera.animateToCalls.single.center, farAway);
    });

    testWidgets('zum, condongan dan arah pilihan pengguna dikekalkan', (
      tester,
    ) async {
      await pumpScreen(tester);
      map.camera.pose = const CameraPose(
        center: klcc,
        zoom: 17.5,
        tilt: 30,
        bearing: 120,
      );

      await moveTo(tester, farAway);

      final pose = map.camera.animateToCalls.single;
      expect((pose.zoom, pose.tilt, pose.bearing), (17.5, 30.0, 120.0));
    });

    testWidgets('hingar GPS ketika pegun (< 4 m) tidak menggoyang kamera', (
      tester,
    ) async {
      await pumpScreen(tester);
      map.camera.pose = const CameraPose(
        center: klcc,
        zoom: 15,
        tilt: 0,
        bearing: 0,
      );
      await moveTo(tester, GeoPoint(klcc.lat + 0.00001, klcc.lng)); // ~1 m
      expect(map.camera.animateToCalls, isEmpty);
    });

    testWidgets(
      'pengguna menggerakkan peta: kamera berhenti mengikut, titik lokasi terus hidup',
      (tester) async {
        await pumpScreen(tester);
        expect(location.trackingController.hasListener, isTrue);

        map.config!.onUserGesture!();
        await tester.pump();

        // GPS kekal untuk titik lokasi; hanya kamera yang dilepaskan.
        expect(location.trackingController.hasListener, isTrue);
        await moveTo(tester, farAway);
        expect(map.camera.animateToCalls, isEmpty);
        expect(map.config!.userLocation!.value!.point, farAway);
      },
    );

    testWidgets('"Lokasi saya" mula mengikut semula selepas dilepaskan', (
      tester,
    ) async {
      await pumpScreen(tester);
      map.config!.onUserGesture!();
      await tester.pump();
      await moveTo(tester, farAway);
      expect(map.camera.animateToCalls, isEmpty);

      await tester.tap(find.byTooltip('Lokasi saya'));
      await tester.pumpAndSettle();

      // ~100 m lebih jauh: cukup untuk menggerakkan kamera tanpa dianggap lompatan GPS yang mustahil.
      final next = GeoPoint(farAway.lat + 0.0009, farAway.lng);
      await moveTo(tester, next);
      // Kedudukan dilicinkan penapis: kamera menuju ke arah titik baharu, bukan fix mentah.
      final target = map.camera.animateToCalls.single.center;
      expect(target.lat, greaterThan(farAway.lat));
      expect(distanceMeters(target, next), lessThan(100));
    });

    testWidgets('kebenaran tiada: tiada strim GPS dibuka', (tester) async {
      location.accessValue = LocationAccess.deniedForever;
      await pumpScreen(tester);
      expect(location.trackingListens, 0);
    });

    testWidgets(
      'laluan dipratonton menggantung ikutan; kamera dipegang oleh paparan laluan',
      (tester) async {
        await pumpScreen(tester);
        map.config!.onLongPress(klia);
        await tester.pumpAndSettle();

        map.camera.animateToCalls.clear();
        await moveTo(tester, farAway);
        expect(map.camera.animateToCalls, isEmpty);
        // Titik lokasi kekal mengikut GPS walaupun kamera dipegang oleh paparan laluan.
        expect(map.config!.userLocation!.value!.point, farAway);
      },
    );

    testWidgets(
      'app ke latar belakang melepaskan GPS dan kembali menyambungnya',
      (tester) async {
        await pumpScreen(tester);
        expect(location.trackingController.hasListener, isTrue);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(location.trackingController.hasListener, isFalse);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(location.trackingController.hasListener, isTrue);
      },
    );

    testWidgets(
      'fix lapuk (cache platform) tidak menggerakkan kamera atau titik lokasi',
      (tester) async {
        await pumpScreen(tester);
        location.trackingController.add(
          LocationFix(
            point: farAway,
            accuracyMeters: 6,
            timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
          ),
        );
        await tester.pump();

        expect(map.camera.animateToCalls, isEmpty);
        expect(map.config!.userLocation!.value, isNull);
      },
    );

    testWidgets(
      'kembali dari latar belakang: titik lapuk ditandakan sehingga fix segar tiba',
      (tester) async {
        await pumpScreen(tester);
        await moveTo(tester, farAway);
        expect(map.config!.userLocation!.value!.stale, isFalse);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(map.config!.userLocation!.value!.stale, isTrue);

        await moveTo(tester, GeoPoint(farAway.lat + 0.0005, farAway.lng));
        expect(map.config!.userLocation!.value!.stale, isFalse);
      },
    );

    testWidgets(
      'kembali dari latar belakang lama: tidak terbang ke lokasi terakhir yang lapuk',
      (tester) async {
        await pumpScreen(tester, recenterAfter: Duration.zero);
        map.camera.flyToCalls.clear();
        // Peranti masih menyimpan lokasi lama di tempat lain; fix segar ada di Batu Caves.
        location.lastKnown = const LocationFix(
          point: farAway,
          accuracyMeters: 50,
        );
        location.fix = LocationFix(
          point: batuCaves,
          accuracyMeters: 6,
          timestamp: DateTime.now(),
        );

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(map.camera.flyToCalls.map((c) => c.$1), [batuCaves]);
      },
    );

    testWidgets('kembali dari latar belakang sebentar: kamera tidak dialih', (
      tester,
    ) async {
      await pumpScreen(tester); // ambang 1 jam
      map.camera.flyToCalls.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(map.camera.flyToCalls, isEmpty);
    });

    testWidgets(
      'kembali dari latar belakang lama: peta dipusatkan semula pada pengguna',
      (tester) async {
        await pumpScreen(tester, recenterAfter: Duration.zero);
        map
            .config!
            .onUserGesture!(); // pengguna sempat menggeser peta ke tempat lain
        map.camera.flyToCalls.clear();
        location.fix = LocationFix(
          point: batuCaves,
          accuracyMeters: 6,
          timestamp: DateTime.now(),
        );

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(map.camera.flyToCalls.last, (batuCaves, 15.0));
        expect(location.trackingController.hasListener, isTrue);
      },
    );
  });

  group('kebenaran lokasi', () {
    testWidgets('sudah diberi: tiada dialog, kamera terus ke lokasi pengguna', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(map.camera.flyToCalls, [(klcc, 15.0)]);
      expect(map.config!.showUserLocation, isTrue);
    });

    testWidgets(
      'pelancaran pertama: penjelasan mendahului dialog sistem, kemudian kamera terus ke lokasi pengguna',
      (tester) async {
        location
          ..accessValue = LocationAccess.askable
          ..requestResult = LocationAccess.granted;
        await pumpScreen(tester);

        expect(
          find.text('Benarkan akses lokasi?'),
          findsOneWidget,
          reason: 'app minta lokasi sendiri semasa pelancaran (gaya Waze)',
        );
        expect(
          location.requestCalls,
          0,
          reason: 'dialog sistem belum boleh muncul sebelum pengguna bersetuju',
        );
        expect(map.config!.showUserLocation, isFalse);

        await tester.tap(find.text('Benarkan'));
        await tester.pumpAndSettle();

        expect(location.requestCalls, 1);
        expect(map.config!.showUserLocation, isTrue);
        expect(map.camera.flyToCalls, [(klcc, 15.0)]);
      },
    );

    testWidgets(
      'Bukan sekarang: tidak meminta kebenaran sistem, app kekal berfungsi dan butang lokasi bertanya semula',
      (tester) async {
        location.accessValue = LocationAccess.askable;
        await pumpScreen(tester);

        expect(find.text('Benarkan akses lokasi?'), findsOneWidget);
        await tester.tap(find.text('Bukan sekarang'));
        await tester.pumpAndSettle();

        expect(location.requestCalls, 0);
        expect(map.camera.flyToCalls, isEmpty);
        expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);

        await tester.tap(find.byTooltip('Lokasi saya'));
        await tester.pumpAndSettle();
        expect(find.text('Benarkan akses lokasi?'), findsOneWidget);
      },
    );

    testWidgets(
      'pelancaran: lompat dahulu ke lokasi terakhir diketahui, kemudian diperhalusi dengan fix segar',
      (tester) async {
        location.lastKnown = const LocationFix(point: batuCaves);
        await pumpScreen(tester);

        expect(map.camera.flyToCalls, [(batuCaves, 15.0), (klcc, 15.0)]);
      },
    );

    testWidgets(
      'pelancaran: fix segar yang hampir dengan lokasi terakhir tidak mencetus animasi kedua',
      (tester) async {
        final nearKlcc = GeoPoint(klcc.lat + 0.0001, klcc.lng); // ~11 m
        location.lastKnown = LocationFix(point: nearKlcc);
        await pumpScreen(tester);

        expect(map.camera.flyToCalls, [(nearKlcc, 15.0)]);
      },
    );

    testWidgets(
      'pelancaran tanpa fix terakhir mahupun fix segar: kamera kekal dan app tidak ranap',
      (tester) async {
        location.fix = null;
        await pumpScreen(tester);

        expect(map.camera.flyToCalls, isEmpty);
        expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
      },
    );

    testWidgets(
      'ditolak kekal: tiada dialog semasa pelancaran; butang lokasi menawarkan Tetapan',
      (tester) async {
        location.accessValue = LocationAccess.deniedForever;
        await pumpScreen(tester);
        expect(
          find.byType(AlertDialog),
          findsNothing,
          reason: 'jangan ganggu pengguna yang telah menolak',
        );

        await tester.tap(find.byTooltip('Lokasi saya'));
        await tester.pumpAndSettle();
        expect(find.textContaining('dimatikan'), findsOneWidget);

        await tester.tap(find.text('Buka Tetapan'));
        await tester.pumpAndSettle();
        expect(location.openAppSettingsCalls, 1);
        expect(location.requestCalls, 0);
      },
    );

    testWidgets('GPS dimatikan: butang lokasi menawarkan Tetapan lokasi', (
      tester,
    ) async {
      location.accessValue = LocationAccess.serviceDisabled;
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Lokasi saya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka Tetapan'));
      await tester.pumpAndSettle();

      expect(location.openLocationSettingsCalls, 1);
    });

    testWidgets(
      'butang lokasi apabila sudah diberi menerbangkan kamera ke fix terkini',
      (tester) async {
        await pumpScreen(tester);
        map.camera.flyToCalls.clear();
        location.fix = LocationFix(
          point: batuCaves,
          accuracyMeters: 8,
          timestamp: DateTime.now(),
        );

        await tester.tap(find.byTooltip('Lokasi saya'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(map.camera.flyToCalls, [(batuCaves, 15.0)]);
        expect(find.text('Anggaran ketepatan lokasi ±8 m'), findsOneWidget);
      },
    );

    testWidgets('lokasi tiada fix: butang memaklumkan dan boleh dicuba semula', (
      tester,
    ) async {
      location.fix = null;
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Lokasi saya'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'GPS belum dapat lokasi yang cukup tepat. Pergi ke kawasan terbuka dan cuba lagi.',
        ),
        findsOneWidget,
      );
      expect(map.camera.flyToCalls, isEmpty);
      expect(find.byTooltip('Lokasi saya'), findsOneWidget);
    });
  });

  group('tetapan paparan', () {
    testWidgets('halaman About boleh dibuka dari tetapan', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Tetapan'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tentang FGMaps'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentang FGMaps'));
      await tester.pumpAndSettle();

      expect(find.text('Dibangunkan oleh'), findsOneWidget);
      expect(find.text('Faiz Nasir'), findsOneWidget);
      expect(find.text('Dimiliki oleh'), findsOneWidget);
      expect(find.text('FG Universal Empire Company'), findsOneWidget);
    });

    testWidgets('memilih Gelap dan AMOLED menukar dan menyimpan tetapan', (
      tester,
    ) async {
      await prefs.setString('theme.mode', 'light');
      final container = await pumpScreen(tester);
      expect(map.config!.styleUrl, AppConfig.mapStyleLight);

      await tester.tap(find.byTooltip('Tetapan'));
      await tester.pumpAndSettle();
      expect(find.text('Hitam AMOLED'), findsOneWidget);

      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('amoled-switch')));
      await tester.pumpAndSettle();
      expect(
        container.read(themeControllerProvider),
        const ThemeSettings(mode: AppThemeMode.dark, amoled: true),
      );
      expect(prefs.getString('theme.mode'), 'dark');
      expect(prefs.getBool('theme.amoled'), isTrue);

      // Peta di bawah halaman Tetapan; gayanya mengikut apabila pengguna kembali.
      Navigator.of(tester.element(find.byType(SettingsPage))).pop();
      await tester.pumpAndSettle();
      expect(map.config!.styleUrl, AppConfig.mapStyleDark);

      await tester.tap(find.byTooltip('Tetapan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerah'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SettingsPage))).pop();
      await tester.pumpAndSettle();
      expect(map.config!.styleUrl, AppConfig.mapStyleLight);
    });
  });

  group('Laporan komuniti', () {
    testWidgets('butang Laporkan: pilih jenis -> penanda muncul pada peta', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(map.config!.reports, isEmpty);

      await tester.tap(find.byTooltip('Laporkan'));
      await tester.pumpAndSettle();
      expect(find.text('Laporkan di sini'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-police')));
      await tester.pumpAndSettle();

      expect(find.text('Laporan dihantar. Terima kasih!'), findsOneWidget);
      expect(map.config!.reports, hasLength(1));
      expect(map.config!.reports.single.type, ReportType.police);
      expect(map.config!.reports.single.point, klcc);
    });

    testWidgets(
      'ketuk penanda: "Masih ada?" dan jawapan "Tiada" membuang laporan',
      (tester) async {
        final container = await pumpScreen(tester);
        await container
            .read(reportsRepositoryProvider)
            .create(ReportType.hazard, klcc, DateTime.now());
        await container.read(reportsControllerProvider.notifier).refresh();
        await tester.pumpAndSettle();
        expect(map.config!.reports, hasLength(1));

        // Ketukan jauh dari penanda tidak membuka soalan.
        map.config!.onTap!(klia);
        await tester.pumpAndSettle();
        expect(find.text('Bahaya masih ada?'), findsNothing);

        map.config!.onTap!(klcc);
        await tester.pumpAndSettle();
        expect(find.text('Bahaya masih ada?'), findsOneWidget);
        await tester.tap(find.text('Tiada'));
        await tester.pumpAndSettle();
        expect(map.config!.reports, isEmpty);
      },
    );
  });

  group('Soalan "Masih ada?" semasa memandu', () {
    Future<ProviderContainer> seeded(WidgetTester tester) async {
      final container = await pumpScreen(tester);
      await container
          .read(reportsRepositoryProvider)
          .create(
            ReportType.police,
            klcc,
            DateTime.now().subtract(const Duration(minutes: 30)),
          );
      await container.read(reportsControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      container
          .read(reportAlertsProvider.notifier)
          .onFix(
            const LocationFix(point: klcc, headingDegrees: 90),
            VoiceLanguage.ms,
          );
      await tester.pump();
      await tester.pump();
      return container;
    }

    testWidgets('dialog muncul dan jawapan mengundi', (tester) async {
      final container = await seeded(tester);
      expect(find.text('Polis masih ada?'), findsOneWidget);
      await tester.tap(find.text('Ya, masih ada'));
      await tester.pumpAndSettle();
      expect(find.text('Polis masih ada?'), findsNothing);
      expect(container.read(reportsControllerProvider).single.confirms, 1);
      expect(container.read(reportAlertsProvider).ask, isNull);
    });

    testWidgets('tidak dijawab: ditutup sendiri tanpa undi', (tester) async {
      final container = await seeded(tester);
      expect(find.text('Polis masih ada?'), findsOneWidget);
      await tester.pump(
        ReportAlertsController.askTimeout + const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('Polis masih ada?'), findsNothing);
      expect(container.read(reportsControllerProvider).single.confirms, 0);
    });
  });

  group('kongsi, kecemasan dan kos minyak', () {
    testWidgets(
      'kongsi destinasi: nama, masa tiba, tempoh, jarak dan pautan OSM',
      (tester) async {
        await pumpScreen(tester);
        map.config!.onLongPress(klia);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('share-destination')));
        await tester.pumpAndSettle();

        expect(share.shared, hasLength(1));
        final text = share.shared.single;
        expect(text, contains('Saya menuju ke'));
        expect(text, contains('Anggaran tiba'));
        expect(text, contains('58 min'));
        expect(
          text,
          contains(
            'https://www.openstreetmap.org/?mlat=2.74560&mlon=101.70720',
          ),
        );
      },
    );

    testWidgets('lembaran kongsi gagal: mesej, tiada ranap', (tester) async {
      share.fail = true;
      await pumpScreen(tester);
      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-destination')));
      await tester.pumpAndSettle();
      expect(find.textContaining('lembaran kongsi'), findsOneWidget);
    });

    testWidgets(
      'butang kecemasan di peta: sahkan dahulu sebelum papan nombor',
      (tester) async {
        await pumpScreen(tester);
        await tester.tap(find.byTooltip('Kecemasan'));
        await tester.pumpAndSettle();
        expect(find.text('Hubungi 999'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('emergency-112')));
        await tester.pumpAndSettle();
        expect(dialer.dialed, isEmpty);
        await tester.tap(find.byKey(const ValueKey('emergency-confirm')));
        await tester.pumpAndSettle();
        expect(dialer.dialed, ['112']);
      },
    );

    testWidgets('kecemasan: kongsi lokasi tepat guna lokasi pengguna', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Kecemasan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emergency-share')));
      await tester.pumpAndSettle();
      expect(share.shared.single, contains('3.15790, 101.71160'));
    });

    testWidgets(
      'tanpa harga minyak: tiada anggaran kos minyak (tidak direka)',
      (tester) async {
        await pumpScreen(tester);
        map.config!.onLongPress(klia);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('fuel-cost')), findsNothing);
      },
    );

    testWidgets('dengan harga sendiri: anggaran = jarak x penggunaan x harga', (
      tester,
    ) async {
      await prefs.setDouble('fuel.price.manual', 2.0);
      await pumpScreen(tester);
      map.config!.onLongPress(klia);
      await tester.pumpAndSettle();
      // 67.049 km x 8.0 / 100 x RM2.00 = RM10.73.
      expect(find.byKey(const ValueKey('fuel-cost')), findsOneWidget);
      expect(find.text('≈ RM 10.73 minyak'), findsOneWidget);

      // Motosikal: penggunaan 3.5 L/100 km -> RM4.69.
      await tester.tap(find.byTooltip('Motosikal'));
      await tester.pumpAndSettle();
      expect(find.text('≈ RM 4.69 minyak'), findsOneWidget);
    });
  });

  group('Rumah/Kerja', () {
    testWidgets(
      'chip dipaparkan; yang belum ditetapkan membuka perancang tetapkan',
      (tester) async {
        await pumpScreen(tester);
        expect(find.byKey(const ValueKey('shortcut-home')), findsOneWidget);
        expect(find.byKey(const ValueKey('shortcut-work')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('shortcut-home')));
        await tester.pumpAndSettle();
        // Pilihan: cari alamat ATAU guna lokasi semasa.
        expect(find.byKey(const ValueKey('assign-current')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('assign-search')));
        await tester.pumpAndSettle();
        expect(find.text('Cari alamat Rumah anda'), findsWidgets);
      },
    );

    testWidgets(
      'Rumah yang ditetapkan terus mengira laluan dengan radius bangunan',
      (tester) async {
        final container = await pumpScreen(tester);
        await container
            .read(savedPlacesControllerProvider.notifier)
            .setHome(
              const Place(
                name: "Lotus's Puncak Alam",
                subtitle: '',
                point: GeoPoint(3.2262, 101.4278),
                osmType: 'W',
                extentDiagonalM: 70,
              ),
            );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('shortcut-home')));
        await tester.pumpAndSettle();

        expect(repo.queries, isNotEmpty);
        final query = repo.queries.first;
        expect(query.destination, const GeoPoint(3.2262, 101.4278));
        expect(query.destinationRadiusM, 35);
        expect(query.destinationLabel, "Lotus's Puncak Alam");
      },
    );

    const lotus = Place(
      name: "Lotus's Puncak Alam",
      subtitle: '',
      point: GeoPoint(3.2262, 101.4278),
    );

    testWidgets('ketik Rumah: kiraan 3 saat, kemudian navigasi bermula', (
      tester,
    ) async {
      final container = await pumpScreen(tester);
      await container
          .read(savedPlacesControllerProvider.notifier)
          .setHome(lotus);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('shortcut-home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text("Memulakan navigasi ke Lotus's Puncak Alam dalam 3…"),
        findsOneWidget,
      );
      expect(container.read(navigationControllerProvider).isActive, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text("Memulakan navigasi ke Lotus's Puncak Alam dalam 2…"),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('auto-start-banner')), findsNothing);
      expect(container.read(navigationControllerProvider).isActive, isTrue);
    });

    testWidgets('Batal pada kiraan: kekal di pratonton, tidak mula', (
      tester,
    ) async {
      final container = await pumpScreen(tester);
      await container
          .read(savedPlacesControllerProvider.notifier)
          .setHome(lotus);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('shortcut-home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('auto-start-cancel')));
      await tester.pump();
      expect(find.byKey(const ValueKey('auto-start-banner')), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      expect(container.read(navigationControllerProvider).isActive, isFalse);
      expect(find.byKey(const ValueKey('route-sheet')), findsOneWidget);
    });

    testWidgets('menukar laluan semasa kiraan membatalkan mula automatik', (
      tester,
    ) async {
      final container = await pumpScreen(tester);
      await container
          .read(savedPlacesControllerProvider.notifier)
          .setHome(lotus);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('shortcut-home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('auto-start-banner')), findsOneWidget);

      container.read(routePreviewControllerProvider.notifier).select(1);
      await tester.pump();
      expect(find.byKey(const ValueKey('auto-start-banner')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(container.read(navigationControllerProvider).isActive, isFalse);
    });

    testWidgets('tiada lokasi: laluan tidak dikira, tiada kiraan', (
      tester,
    ) async {
      location.fix = null;
      final container = await pumpScreen(tester);
      await container
          .read(savedPlacesControllerProvider.notifier)
          .setHome(lotus);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shortcut-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auto-start-banner')), findsNothing);
    });

    testWidgets(
      'tetapkan Rumah dengan lokasi semasa: nama daripada geokod songsang',
      (tester) async {
        reverse.result = const Place(
          name: 'Jalan Bukit Jelutong',
          subtitle: 'Shah Alam, Selangor',
          point: GeoPoint(3.1, 101.5),
        );
        final container = await pumpScreen(tester);
        await tester.tap(find.byKey(const ValueKey('shortcut-home')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('assign-current')));
        await tester.pumpAndSettle();

        final home = container
            .read(savedPlacesControllerProvider.notifier)
            .home!;
        expect(home.place.name, 'Jalan Bukit Jelutong');
        // Titik yang disimpan ialah kedudukan tepat pengguna, bukan titik alamat geokod.
        expect(home.place.point, klcc);
        expect(find.text('Disimpan sebagai Rumah'), findsOneWidget);
      },
    );

    testWidgets('geokod songsang gagal: tetap disimpan dengan nama umum', (
      tester,
    ) async {
      reverse.fail = true;
      final container = await pumpScreen(tester);
      await tester.tap(find.byKey(const ValueKey('shortcut-work')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-current')));
      await tester.pumpAndSettle();

      final work = container.read(savedPlacesControllerProvider.notifier).work!;
      expect(work.place.name, 'Lokasi semasa');
      expect(work.place.point, klcc);
      expect(work.place.subtitle, '3.15790, 101.71160');
    });

    testWidgets('lokasi semasa tidak dapat ditentukan: tiada simpanan', (
      tester,
    ) async {
      location.fix = null;
      final container = await pumpScreen(tester);
      await tester.tap(find.byKey(const ValueKey('shortcut-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-current')));
      await tester.pumpAndSettle();
      expect(
        container.read(savedPlacesControllerProvider.notifier).home,
        isNull,
      );
    });

    testWidgets('tekan lama Rumah: Tukar membuka pilihan cari/lokasi semasa', (
      tester,
    ) async {
      final container = await pumpScreen(tester);
      await container
          .read(savedPlacesControllerProvider.notifier)
          .setHome(lotus);
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('shortcut-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage-change')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assign-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('assign-current')), findsOneWidget);
    });

    testWidgets(
      'butang simpan pada lembaran laluan membuka pilihan simpan sebagai',
      (tester) async {
        await pumpScreen(tester);
        map.config!.onLongPress(klia);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('save-destination')));
        await tester.pumpAndSettle();
        expect(find.text('Simpan sebagai'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-as-work')));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MapScreen)),
        );
        expect(
          container
              .read(savedPlacesControllerProvider.notifier)
              .work!
              .place
              .point,
          klia,
        );
      },
    );
  });

  testWidgets('mod Matahari: disimpan, petunjuk dipaparkan, peta mengikut jam', (
    tester,
  ) async {
    // 21:00 waktu Malaysia (13:00 UTC): malam di Kuala Lumpur (lokasi lalai mod matahari).
    final night = DateTime.utc(2026, 10, 26, 13).toLocal();
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const MapScreen(),
      overrides: [
        map.override,
        locationServiceProvider.overrideWithValue(location),
        routeOptionsPlannerProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        idleRecenterAfterProvider.overrideWithValue(const Duration(hours: 1)),
        themeClockProvider.overrideWithValue(() => night),
        mapStyleLoaderProvider.overrideWithValue(_NightLoader()),
      ],
    );
    await tester.pumpAndSettle();
    expect(map.config!.styleUrl, AppConfig.mapStyleLight);

    await tester.tap(find.byTooltip('Tetapan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matahari'));
    await tester.pumpAndSettle();
    expect(prefs.getString('theme.mode'), 'sun');
    expect(find.byKey(const ValueKey('sun-hint')), findsOneWidget);
    Navigator.of(tester.element(find.byType(SettingsPage))).pop();
    await tester.pumpAndSettle();
    expect(map.config!.styleId, 'night:test');
  });

  testWidgets('mod gelap menghantar gaya malam JSON; kunci stabil', (
    tester,
  ) async {
    await prefs.setString('theme.mode', 'dark');
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      const MapScreen(),
      overrides: [
        map.override,
        locationServiceProvider.overrideWithValue(location),
        routeOptionsPlannerProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        idleRecenterAfterProvider.overrideWithValue(const Duration(hours: 1)),
        mapStyleLoaderProvider.overrideWithValue(_NightLoader()),
      ],
    );
    await tester.pumpAndSettle();
    expect(map.config!.styleUrl, startsWith('{'));
    expect(map.config!.styleId, 'night:test');
  });

  testWidgets(
    'dengan animasi penuh, keadaan memuatkan tidak menimbulkan pengecualian',
    (tester) async {
      usePhoneSurface(tester);
      final pending = Future<List<RouteOption>>.delayed(
        const Duration(milliseconds: 400),
        () => [sampleOption()],
      );
      repo.handler = (_) => pending;
      await pumpApp(
        tester,
        const MapScreen(),
        overrides: [
          map.override,
          locationServiceProvider.overrideWithValue(location),
          routeOptionsPlannerProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await tester.pump(const Duration(milliseconds: 50));

      map.config!.onLongPress(klia);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mengira laluan…'), findsOneWidget);

      await tester.pump(
        const Duration(milliseconds: 150),
      ); // kilau skeleton bergerak
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('58 min'), findsWidgets);
    },
  );
}

/// Navigasi aktif yang sedang mengira semula laluan.
class _ReroutingNav extends NavigationController {
  @override
  NavigationState build() =>
      const NavigationState(phase: NavPhase.active, rerouting: true);
}
