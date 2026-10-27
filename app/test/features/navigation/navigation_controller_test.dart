import 'dart:async';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/data/location_sources.dart';
import 'package:fgmap/features/navigation/data/navigation_settings.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/reports/domain/report.dart';
import 'package:fgmap/features/reports/presentation/report_alerts_controller.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import 'nav_test_support.dart';

/// Sumber fix yang dikawal ujian: setiap `emit` menggerakkan jam palsu ke cap masa fix.
class ScriptedSource implements NavLocationSource {
  ScriptedSource(this.clock);

  final FakeClock clock;
  final controller = StreamController<LocationFix>();

  @override
  bool get isSimulated => false;

  @override
  Stream<LocationFix> fixes() => controller.stream;

  Future<void> emit(LocationFix fix) async {
    clock.now = fix.timestamp!;
    controller.add(fix);
    await pumpEventQueue();
  }

  Future<void> emitAll(Iterable<LocationFix> fixes) async {
    for (final f in fixes) {
      await emit(f);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeClock clock;
  late FakeVoice voice;
  late FakeAwake awake;
  late FakeRoutePlanner planner;
  late ScriptedSource source;
  late ProviderContainer container;
  late RouteOption routeOption;
  late NavRoute navRoute;
  const destination = GeoPoint(3.0, 101.05);

  // Pilihan pengguna di pratonton (motosikal, tanpa tol/lebuh raya) mesti terbawa ke pengiraan semula.
  RouteQuery query() => RouteQuery(
    origin: navRoute.points.first,
    destination: destination,
    vehicle: RouteVehicle.motorcycle,
    avoidTolls: true,
    avoidHighways: true,
    destinationLabel: 'Destinasi',
  );

  Future<void> setUpContainer({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    clock = FakeClock();
    voice = FakeVoice();
    awake = FakeAwake();
    source = ScriptedSource(clock);
    planner = FakeRoutePlanner((_) async => [routeOption]);
    routeOption = lShapedRoute(legM: 2000);
    navRoute = NavRoute(routeOption);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        voiceGuideProvider.overrideWithValue(voice),
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        screenAwakeProvider.overrideWithValue(awake),
        navClockProvider.overrideWithValue(clock.call),
        reportsClockProvider.overrideWithValue(clock.call),
        routePlannerProvider.overrideWithValue(planner),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
      ],
    );
    addTearDown(container.dispose);
  }

  NavigationController controller() =>
      container.read(navigationControllerProvider.notifier);
  NavigationState state() => container.read(navigationControllerProvider);

  Future<void> begin({VoiceLanguage ui = VoiceLanguage.ms}) async {
    container.listen(navigationControllerProvider, (_, _) {});
    final ok = await controller().start(
      routeOption,
      query(),
      uiLanguage: ui,
      source: source,
    );
    expect(ok, isTrue);
  }

  group('NavigationController', () {
    test(
      'mula: aktif, skrin dijaga hidup, pengumuman pembukaan disebut',
      () async {
        await setUpContainer();
        await begin();
        expect(state().phase, NavPhase.active);
        expect(awake.enabled, isTrue);
        expect(voice.said.single.$1.kind, AnnouncementKind.start);
        expect(voice.said.single.$2, VoiceLanguage.ms);
      },
    );

    test(
      'pemanduan penuh: kemajuan dikemas kini, arahan disebut, tiba, dan berhenti mendengar',
      () async {
        await setUpContainer();
        await begin();
        await source.emitAll(driveFixes(navRoute, speedMps: 14));
        expect(state().phase, NavPhase.arrived);
        expect(state().progress!.status, NavStatus.arrived);
        final kinds = voice.said.map((s) => s.$1.kind).toList();
        expect(
          kinds,
          containsAllInOrder([
            AnnouncementKind.start,
            AnnouncementKind.far,
            AnnouncementKind.near,
            AnnouncementKind.now,
          ]),
        );
        expect(voice.said.last.$1.text, 'Anda telah sampai.');
      },
    );

    test(
      'tamat: stop() mengosongkan keadaan, menghentikan suara, melepaskan wakelock',
      () async {
        await setUpContainer();
        await begin();
        await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 500));
        await controller().stop();
        expect(state().phase, NavPhase.idle);
        expect(state().progress, isNull);
        expect(voice.stops, greaterThan(0));
        expect(awake.enabled, isFalse);
        // Fix selepas stop diabaikan.
        await source.emit(
          driveFixes(navRoute, from: DateTime.utc(2026, 1, 1, 13)).first,
        );
        expect(state().phase, NavPhase.idle);
      },
    );

    test('tamat: suara gagal berhenti tetap melepaskan wakelock', () async {
      await setUpContainer();
      await begin();
      voice.failStop = true;
      await controller().stop();
      expect(state().phase, NavPhase.idle);
      expect(awake.enabled, isFalse);
    });

    test(
      're-route: ralat bukan RoutingFailure tidak menyangkut "mengira semula"',
      () async {
        await setUpContainer();
        await begin();
        await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
        planner.handler = (_) async => throw StateError('respons rosak');

        final base = DateTime.utc(2026, 1, 1, 12, 10);
        for (var i = 0; i < 6; i++) {
          await source.emit(
            LocationFix(
              point: destinationPoint(navRoute.pointAt(700), 0, 14.0 * (i + 1)),
              headingDegrees: 0,
              accuracyMeters: 5,
              speedMps: 14,
              timestamp: base.add(Duration(seconds: i)),
            ),
          );
        }
        expect(planner.queries, hasLength(1));
        expect(state().phase, NavPhase.active);
        expect(state().rerouting, isFalse);
        expect(state().rerouteFailure, RoutingFailureKind.generic);
      },
    );

    test('re-route: senarai kosong dianggap kegagalan, bukan ranap', () async {
      await setUpContainer();
      await begin();
      await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
      planner.handler = (_) async => <RouteOption>[];

      final base = DateTime.utc(2026, 1, 1, 12, 10);
      for (var i = 0; i < 6; i++) {
        await source.emit(
          LocationFix(
            point: destinationPoint(navRoute.pointAt(700), 0, 14.0 * (i + 1)),
            headingDegrees: 0,
            accuracyMeters: 5,
            speedMps: 14,
            timestamp: base.add(Duration(seconds: i)),
          ),
        );
      }
      expect(state().rerouting, isFalse);
      expect(state().rerouteFailure, RoutingFailureKind.generic);
    });

    test(
      'laporan di hadapan disebut; soalan "Masih ada?" bila dilepasi; tamat reset',
      () async {
        await setUpContainer();
        container.listen(reportsControllerProvider, (_, _) {});
        container.listen(reportAlertsProvider, (_, _) {});
        final point = navRoute.pointAt(700);
        await container
            .read(reportsRepositoryProvider)
            .create(
              ReportType.police,
              point,
              clock.now.subtract(const Duration(minutes: 30)),
            );
        await container.read(reportsControllerProvider.notifier).refresh();
        await begin();

        await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 600));
        final spoken = voice.said
            .where((s) => s.$1.kind == AnnouncementKind.report)
            .toList();
        expect(spoken, hasLength(1));
        expect(spoken.single.$1.text, startsWith('Polis di hadapan'));
        expect(container.read(reportAlertsProvider).ask, isNull);

        await source.emitAll(
          driveFixes(
            navRoute,
            speedMps: 14,
            startM: 600,
            endM: 760,
            from: DateTime.utc(2026, 1, 1, 12, 1),
          ),
        );
        expect(container.read(reportAlertsProvider).ask, isNotNull);
        expect(
          voice.said.where((s) => s.$1.kind == AnnouncementKind.report),
          hasLength(1),
          reason: 'tidak diulang',
        );

        await controller().stop();
        expect(container.read(reportAlertsProvider).ask, isNull);
      },
    );

    test('amaran laporan dimatikan: tiada suara laporan', () async {
      await setUpContainer(prefs: {'nav.reportAlerts': false});
      container.listen(reportsControllerProvider, (_, _) {});
      await container
          .read(reportsRepositoryProvider)
          .create(ReportType.police, navRoute.pointAt(700), clock.now);
      await container.read(reportsControllerProvider.notifier).refresh();
      await begin();
      await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 600));
      expect(
        voice.said.where((s) => s.$1.kind == AnnouncementKind.report),
        isEmpty,
      );
    });

    test('mute: tiada suara disebut', () async {
      await setUpContainer(prefs: {'nav.voice': false});
      await begin();
      await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 1800));
      expect(voice.said, isEmpty);
      expect(state().progress, isNotNull);
    });

    test('mute semasa navigasi menghentikan suara serta-merta', () async {
      await setUpContainer();
      await begin();
      final stopsBefore = voice.stops;
      await container
          .read(navigationSettingsProvider.notifier)
          .setVoiceEnabled(false);
      await pumpEventQueue();
      expect(voice.stops, stopsBefore + 1);
    });

    test(
      'bahasa suara: ikut app, tetapi pilihan pengguna mengatasinya',
      () async {
        await setUpContainer();
        await begin(ui: VoiceLanguage.en);
        expect(voice.said.first.$2, VoiceLanguage.en);
        voice.said.clear();
        await container
            .read(navigationSettingsProvider.notifier)
            .setVoiceLanguage(VoiceLanguage.ms);
        await source.emitAll(
          driveFixes(navRoute, speedMps: 14, startM: 1500, endM: 1900),
        );
        expect(voice.said.map((s) => s.$2).toSet(), {VoiceLanguage.ms});
        expect(voice.said.any((s) => s.$1.text.startsWith('Dalam')), isTrue);
      },
    );

    test(
      'menyimpang: re-route dengan kedudukan, arah dan destinasi; laluan diganti',
      () async {
        await setUpContainer();
        await begin();
        await source.emitAll(
          driveFixes(navRoute, speedMps: 14, startM: 0, endM: 700),
        );

        // Laluan baharu bermula di tempat pemandu menyimpang.
        final detour = destinationPoint(navRoute.pointAt(700), 0, 100);
        final newRoute = RouteOption(
          distanceM: 3000,
          durationS: 220,
          hasTolls: false,
          points: [
            detour,
            destinationPoint(detour, 0, 1500),
            destinationPoint(detour, 0, 3000),
          ],
          maneuvers: const [
            Maneuver(
              type: 1,
              streetNames: ['Jalan Baru'],
              lengthM: 3000,
              timeS: 220,
              beginShapeIndex: 0,
            ),
            Maneuver(
              type: 4,
              streetNames: [],
              lengthM: 0,
              timeS: 0,
              beginShapeIndex: 2,
            ),
          ],
        );
        planner.handler = (_) async => [newRoute];

        final base = DateTime.utc(2026, 1, 1, 12, 10);
        for (var i = 0; i < 6; i++) {
          await source.emit(
            LocationFix(
              point: destinationPoint(navRoute.pointAt(700), 0, 14.0 * (i + 1)),
              headingDegrees: 0,
              accuracyMeters: 5,
              speedMps: 14,
              timestamp: base.add(Duration(seconds: i)),
            ),
          );
        }
        expect(planner.queries, hasLength(1));
        final q = planner.queries.single;
        expect(q.destination, destination);
        expect(q.headingDegrees, 0);
        expect(q.vehicle, RouteVehicle.motorcycle);
        expect(q.avoidTolls, isTrue);
        expect(q.avoidHighways, isTrue);
        expect(
          q.alternates,
          0,
          reason: 'pengiraan semula hanya perlukan satu laluan',
        );
        expect(
          distanceMeters(q.origin, navRoute.pointAt(700)),
          greaterThan(30),
        );

        expect(state().routeVersion, 2);
        expect(state().rerouting, isFalse);
        expect(state().route!.totalM, closeTo(3000, 20));
        // Fix terkini disuap ke sesi baharu: HUD tidak kosong menunggu fix seterusnya.
        expect(state().progress, isNotNull);
        final kinds = voice.said.map((s) => s.$1.kind);
        expect(
          kinds,
          containsAllInOrder([
            AnnouncementKind.reroute,
            AnnouncementKind.newRoute,
          ]),
        );
      },
    );

    test(
      're-route gagal: kekal aktif, kegagalan dilaporkan, cuba lagi selepas cooldown berjaya',
      () async {
        await setUpContainer();
        await begin();
        await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
        planner.handler = (_) async =>
            throw const RoutingFailure(RoutingFailureKind.network);

        final base = DateTime.utc(2026, 1, 1, 12, 10);
        Future<void> offFix(int i) => source.emit(
          LocationFix(
            point: destinationPoint(navRoute.pointAt(700), 0, 14.0 * (i + 1)),
            headingDegrees: 0,
            accuracyMeters: 5,
            speedMps: 14,
            timestamp: base.add(Duration(seconds: i)),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await offFix(i);
        }
        expect(planner.queries, hasLength(1));
        expect(state().phase, NavPhase.active);
        expect(state().rerouting, isFalse);
        expect(state().rerouteFailure, RoutingFailureKind.network);
        expect(state().routeVersion, 1);

        // Rangkaian pulih; cooldown 8 s berlalu dan masih menyimpang -> cuba lagi.
        final detour = destinationPoint(navRoute.pointAt(700), 0, 100);
        planner.handler = (_) async => [
          RouteOption(
            distanceM: 2000,
            durationS: 150,
            hasTolls: false,
            points: [detour, destinationPoint(detour, 0, 2000)],
            maneuvers: const [
              Maneuver(
                type: 1,
                streetNames: [],
                lengthM: 2000,
                timeS: 150,
                beginShapeIndex: 0,
              ),
              Maneuver(
                type: 4,
                streetNames: [],
                lengthM: 0,
                timeS: 0,
                beginShapeIndex: 1,
              ),
            ],
          ),
        ];
        for (var i = 6; i < 16; i++) {
          await offFix(i);
        }
        expect(planner.queries.length, greaterThanOrEqualTo(2));
        expect(state().routeVersion, 2);
        expect(state().rerouteFailure, isNull);
      },
    );

    test(
      'hanya satu re-route pada satu masa walaupun fix terus tiba',
      () async {
        await setUpContainer();
        await begin();
        await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
        final completer = Completer<List<RouteOption>>();
        planner.handler = (_) => completer.future;
        final base = DateTime.utc(2026, 1, 1, 12, 10);
        for (var i = 0; i < 20; i++) {
          await source.emit(
            LocationFix(
              point: destinationPoint(navRoute.pointAt(700), 0, 14.0 * (i + 1)),
              headingDegrees: 0,
              accuracyMeters: 5,
              speedMps: 14,
              timestamp: base.add(Duration(seconds: i)),
            ),
          );
        }
        expect(planner.queries, hasLength(1));
        expect(state().rerouting, isTrue);
        completer.completeError(
          const RoutingFailure(RoutingFailureKind.timeout),
        );
        await pumpEventQueue();
        expect(state().rerouting, isFalse);
      },
    );

    group('re-route: kestabilan', () {
      final base = DateTime.utc(2026, 1, 1, 12, 10);
      LocationFix offAt(int i, {double lateral = 14.0}) => LocationFix(
        point: destinationPoint(navRoute.pointAt(700), 0, lateral * (i + 1)),
        headingDegrees: 0,
        accuracyMeters: 5,
        speedMps: 14,
        timestamp: base.add(Duration(seconds: i)),
      );

      RouteOption detourRoute() {
        final detour = destinationPoint(navRoute.pointAt(700), 0, 100);
        return RouteOption(
          distanceM: 3000,
          durationS: 220,
          hasTolls: false,
          points: [
            detour,
            destinationPoint(detour, 0, 1500),
            destinationPoint(detour, 0, 3000),
          ],
          maneuvers: const [
            Maneuver(
              type: 1,
              streetNames: [],
              lengthM: 3000,
              timeS: 220,
              beginShapeIndex: 0,
            ),
            Maneuver(
              type: 4,
              streetNames: [],
              lengthM: 0,
              timeS: 0,
              beginShapeIndex: 2,
            ),
          ],
        );
      }

      test(
        'asal diunjur ke hadapan sepanjang heading (RTT ~1.5 s x 14 m/s)',
        () async {
          await setUpContainer();
          await begin();
          await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
          GeoPoint? lastPoint;
          late RouteQuery sent;
          planner.handler = (q) async {
            sent = q;
            return [detourRoute()];
          };
          for (var i = 0; i < 6; i++) {
            final f = offAt(i);
            lastPoint = f.point;
            await source.emit(f);
            if (planner.queries.isNotEmpty) break;
          }
          expect(planner.queries, hasLength(1));
          final lead = distanceMeters(sent.origin, lastPoint!);
          expect(lead, closeTo(21, 4));
          expect(bearingDegrees(lastPoint, sent.origin), closeTo(0, 3));
          expect(sent.urgent, isTrue);
          expect(sent.headingToleranceDegrees, 45);
        },
      );

      test(
        '"mengira semula" disebut sekali walaupun dicuba semula selepas gagal',
        () async {
          await setUpContainer();
          await begin();
          await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
          planner.handler = (_) async =>
              throw const RoutingFailure(RoutingFailureKind.network);
          for (var i = 0; i < 18; i++) {
            await source.emit(offAt(i));
          }
          expect(planner.queries.length, greaterThanOrEqualTo(2));
          expect(
            voice.said.where((s) => s.$1.kind == AnnouncementKind.reroute),
            hasLength(1),
          );
        },
      );

      test('cuba semula 3 s selepas gagal (bukan 8 s)', () async {
        await setUpContainer();
        await begin();
        await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
        planner.handler = (_) async =>
            throw const RoutingFailure(RoutingFailureKind.timeout);
        var firstAt = -1;
        var secondAt = -1;
        for (var i = 0; i < 14; i++) {
          await source.emit(offAt(i));
          if (planner.queries.length == 1 && firstAt < 0) firstAt = i;
          if (planner.queries.length == 2 && secondAt < 0) secondAt = i;
        }
        expect(firstAt, greaterThanOrEqualTo(0));
        expect(secondAt - firstAt, inInclusiveRange(3, 4));
      });

      test(
        'cooldown merentas sesi: selepas re-route berjaya tiada permintaan baharu dalam 8 s',
        () async {
          await setUpContainer();
          await begin();
          await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
          planner.handler = (_) async => [detourRoute()];
          var i = 0;
          while (state().routeVersion == 1 && i < 10) {
            await source.emit(offAt(i++));
          }
          expect(state().routeVersion, 2);
          final queriesAfterSwap = planner.queries.length;
          // Pemandu terus jauh di luar laluan baharu (cth. asal disnap ke jalan lain).
          final swappedAt = clock.now;
          var t = swappedAt;
          for (var k = 1; k <= 6; k++) {
            t = swappedAt.add(Duration(seconds: k));
            await source.emit(
              LocationFix(
                point: destinationPoint(
                  destinationPoint(navRoute.pointAt(700), 0, 100),
                  90,
                  300.0 + 14 * k,
                ),
                headingDegrees: 90,
                accuracyMeters: 5,
                speedMps: 14,
                timestamp: t,
              ),
            );
          }
          expect(
            planner.queries.length,
            queriesAfterSwap,
            reason: 'masih dalam tempoh sejuk 8 s',
          );
          for (var k = 7; k <= 13; k++) {
            await source.emit(
              LocationFix(
                point: destinationPoint(
                  destinationPoint(navRoute.pointAt(700), 0, 100),
                  90,
                  300.0 + 14 * k,
                ),
                headingDegrees: 90,
                accuracyMeters: 5,
                speedMps: 14,
                timestamp: swappedAt.add(Duration(seconds: k)),
              ),
            );
          }
          expect(planner.queries.length, greaterThan(queriesAfterSwap));
        },
      );

      test(
        'jawapan lewat dibuang bila pemandu sudah kembali ke laluan lama',
        () async {
          await setUpContainer();
          await begin();
          await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 700));
          final completer = Completer<List<RouteOption>>();
          planner.handler = (_) => completer.future;
          var i = 0;
          while (planner.queries.isEmpty && i < 8) {
            await source.emit(offAt(i++));
          }
          expect(state().rerouting, isTrue);
          // Kembali ke laluan asal (di hadapan) dan stabil di atasnya.
          for (var k = 0; k < 5; k++) {
            await source.emit(
              LocationFix(
                point: navRoute.pointAt(900.0 + 14 * k),
                headingDegrees: 90,
                accuracyMeters: 5,
                speedMps: 14,
                timestamp: base.add(Duration(seconds: i + k)),
              ),
            );
          }
          expect(state().progress!.status, NavStatus.onRoute);
          completer.complete([detourRoute()]);
          await pumpEventQueue();
          expect(
            state().routeVersion,
            1,
            reason: 'jawapan lewat tidak menggantikan laluan',
          );
          expect(state().rerouting, isFalse);
        },
      );
    });

    test(
      'ralat aliran lokasi dilaporkan, dan pulih bila fix datang semula',
      () async {
        await setUpContainer();
        await begin();
        source.controller.addError(StateError('permission revoked'));
        await pumpEventQueue();
        expect(state().locationError, isTrue);
        await source.emit(driveFixes(navRoute).first);
        expect(state().locationError, isFalse);
      },
    );

    test(
      'laluan tidak boleh digunakan: start() gagal tanpa mengubah keadaan',
      () async {
        await setUpContainer();
        container.listen(navigationControllerProvider, (_, _) {});
        final ok = await controller().start(
          const RouteOption(
            distanceM: 0,
            durationS: 0,
            hasTolls: false,
            points: [],
          ),
          query(),
          uiLanguage: VoiceLanguage.ms,
          source: source,
        );
        expect(ok, isFalse);
        expect(state().phase, NavPhase.idle);
      },
    );

    test('start semula menggantikan sesi lama', () async {
      await setUpContainer();
      await begin();
      await source.emitAll(driveFixes(navRoute, speedMps: 14, endM: 300));
      final second = ScriptedSource(clock);
      await controller().start(
        routeOption,
        query(),
        uiLanguage: VoiceLanguage.ms,
        source: second,
      );
      expect(state().progress, isNull);
      expect(state().phase, NavPhase.active);
      expect(awake.enableCalls, 2);
    });
  });

  group('Sumber lokasi', () {
    test(
      'ReplayLocationSource: cap masa ditulis semula, kelajuan didarab, jarak masa dihormati',
      () async {
        final fixes = driveFixes(
          NavRoute(lShapedRoute()),
          speedMps: 10,
          endM: 50,
        );
        final sleeps = <Duration>[];
        final wall = DateTime.utc(2030);
        final source = ReplayLocationSource(
          fixes,
          speedMultiplier: 4,
          sleep: (d) async => sleeps.add(d),
          clock: () => wall,
        );
        final out = await source.fixes().toList();
        expect(out.length, fixes.length);
        expect(out.every((f) => f.timestamp == wall), isTrue);
        expect(out.first.speedMps, 40);
        expect(
          sleeps.every((d) => d == const Duration(milliseconds: 250)),
          isTrue,
        );
        expect(sleeps.length, fixes.length - 1);
      },
    );

    test(
      'simulateDrive: berakhir di destinasi, kelajuan munasabah, memperlahan untuk belokan',
      () {
        final route = NavRoute(lShapedRoute(legM: 1500));
        final fixes = simulateDrive(route);
        expect(
          distanceMeters(fixes.last.point, route.points.last),
          lessThan(5),
        );
        expect(fixes.last.speedMps, 0);
        final speeds = fixes.map((f) => f.speedMps!).toList();
        expect(speeds.reduce((a, b) => a > b ? a : b), lessThan(34));
        // Lebih perlahan berhampiran selekoh (km 1.5) berbanding di tengah kaki pertama.
        double speedNear(double m) {
          var best = fixes.first;
          for (final f in fixes) {
            if ((distanceMeters(f.point, route.pointAt(m))) <
                distanceMeters(best.point, route.pointAt(m))) {
              best = f;
            }
          }
          return best.speedMps!;
        }

        expect(speedNear(1480), lessThan(speedNear(700)));
        // Cap masa menaik satu saat sekali.
        for (var i = 1; i < fixes.length; i++) {
          expect(
            fixes[i].timestamp!.difference(fixes[i - 1].timestamp!),
            const Duration(seconds: 1),
          );
        }
      },
    );

    test(
      'simulasi melalui sesi: tiba tanpa pernah menyimpang (laluan KLCC-KLIA)',
      () {
        final route = loadFixtureNavRoute();
        final clock = FakeClock();
        final session = NavigationSession(
          route: route,
          language: VoiceLanguage.en,
          clock: clock.call,
        );
        NavProgress? last;
        for (final f in simulateDrive(route)) {
          clock.now = f.timestamp!;
          final u = session.onFix(f);
          if (u == null) continue;
          expect(u.progress.status, isNot(NavStatus.offRoute));
          expect(u.reroute, isNull);
          last = u.progress;
        }
        expect(last!.status, NavStatus.arrived);
      },
    );
  });
}
