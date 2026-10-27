// Penjana aset video promosi: merender widget SEBENAR app (HUD, kad laluan, kereta 3D) ke PNG berlatar
// telus. Tidak berbuat apa-apa kecuali PROMO_OUT ditetapkan, jadi `flutter test` biasa tidak menulis fail.
//
//   PROMO_OUT=/laluan/promo_out/assets flutter test test/promo/promo_assets_test.dart
@Tags(['promo'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/offline_maps/domain/offline_models.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_map_controller.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_maps_sheet.dart';
import 'package:fgmap/features/onboarding/presentation/onboarding_page.dart';
import 'package:fgmap/features/search/presentation/trip_planner_page.dart';
import 'package:fgmap/features/settings/presentation/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/legal_override.dart';
import '../features/navigation/nav_test_support.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/route_preview/data/toll_finder.dart';
import 'package:fgmap/features/route_preview/data/valhalla_codec.dart';
import 'package:fgmap/features/route_preview/domain/route_options_merge.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'dart:convert';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/presentation/car/car_mesh.dart';
import 'package:fgmap/features/navigation/presentation/car/car_renderer.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/route_preview/presentation/route_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

NavManeuver _maneuver(
  int index,
  ManeuverKind kind,
  double startM, {
  List<String> streets = const [],
  int? exit,
}) => NavManeuver(
  index: index,
  kind: kind,
  startM: startM,
  lengthM: 500,
  timeS: 40,
  streetNames: streets,
  roundaboutExit: exit,
);

NavProgress _progress({
  required NavManeuver next,
  NavManeuver? following,
  double distance = 450,
  double speed = 16.7,
  double remainingM = 12800,
  double remainingS = 1260,
  NavStatus status = NavStatus.onRoute,
}) => NavProgress(
  status: status,
  alongM: 1000,
  remainingM: remainingM,
  remainingS: remainingS,
  next: next,
  distanceToNextM: distance,
  following: following,
  position: const GeoPoint(3.1, 101.6),
  bearing: 90,
  speedMps: speed,
  accuracyM: 5,
  crossTrackM: 2,
  street: 'Jalan Tun Razak',
  gpsWeak: false,
);

Future<void> _save(
  WidgetTester tester,
  Key key,
  String path, {
  double ratio = 3,
}) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

class _FakeOffline extends OfflineMapController {
  _FakeOffline(this.initial);
  final OfflineMapState initial;
  @override
  OfflineMapState build() => initial;
  @override
  Future<void> download() async {}
  @override
  void cancel() {}
  @override
  Future<void> delete() async {}
  @override
  Future<void> refresh({bool checkRemote = true}) async {}
}

OfflineManifest _manifest() => OfflineManifest(
  region: 'malaysia',
  version: '20261026',
  valhalla: expectedValhallaVersion,
  file: 'malaysia-20261026.tar.gz',
  sizeBytes: 253855993,
  sha256: 'a' * 64,
  extractedSizeBytes: 682844160,
  extractedSha256: 'b' * 64,
);

void _screens(String out) {
  const key = ValueKey('promo-screen');
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};
  final locales = {'ms': const Locale('ms'), 'en': const Locale('en')};

  Future<SharedPreferences> prefs([Map<String, Object> v = const {}]) async {
    SharedPreferences.setMockInitialValues(v);
    return SharedPreferences.getInstance();
  }

  for (final t in themes.entries) {
    for (final l in locales.entries) {
      final tag = '${l.key}_${t.key}';

      // Peta offline: belum dimuat turun, sedang dimuat turun (35%, 72%), siap dipasang.
      final states = <String, OfflineMapState>{
        'idle': OfflineMapState(configured: true, latest: _manifest()),
        'p35': OfflineMapState(
          configured: true,
          latest: _manifest(),
          op: OfflineOp.downloading,
          receivedBytes: 88849000,
          totalBytes: 253855993,
        ),
        'p72': OfflineMapState(
          configured: true,
          latest: _manifest(),
          op: OfflineOp.downloading,
          receivedBytes: 182775000,
          totalBytes: 253855993,
        ),
        'done': OfflineMapState(
          configured: true,
          latest: _manifest(),
          installed: InstalledMap(
            version: '20261026',
            sizeBytes: 682844160,
            tarPath: '/x/valhalla_tiles.tar',
          ),
        ),
      };
      for (final e in states.entries) {
        testWidgets('peta offline ${e.key} $tag', (tester) async {
          usePhoneSurface(tester, size: const Size(390, 700));
          reduceMotion(tester);
          final sp = await prefs();
          await withShadows(() async {
            await pumpApp(
              tester,
              Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 390,
                    child: Material(
                      color: t.value.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: const OfflineMapsSheet(),
                    ),
                  ),
                ),
              ),
              theme: t.value,
              locale: l.value,
              overrides: [
                offlineMapControllerProvider.overrideWith(
                  () => _FakeOffline(e.value),
                ),
                isMeteredConnectionProvider.overrideWithValue(
                  () async => false,
                ),
                sharedPreferencesProvider.overrideWithValue(sp),
              ],
            );
            await tester.pump(const Duration(milliseconds: 300));
            await _save(tester, key, '$out/offline_${e.key}_$tag.png');
          });
        });
      }

      testWidgets('onboarding $tag', (tester) async {
        usePhoneSurface(tester, size: const Size(390, 844));
        safeTop(tester);
        reduceMotion(tester);
        final sp = await prefs();
        await withShadows(() async {
          await pumpApp(
            tester,
            RepaintBoundary(key: key, child: const OnboardingPage()),
            theme: t.value,
            locale: l.value,
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sp),
              locationServiceProvider.overrideWithValue(FakeLocationService()),
              legalTextOverride(),
            ],
          );
          await tester.pumpAndSettle();
          await _save(tester, key, '$out/onboarding_welcome_$tag.png');
          await tester.tap(find.byKey(const ValueKey('onboarding-next')));
          await tester.pumpAndSettle();
          await _save(tester, key, '$out/onboarding_privacy_$tag.png');
        });
      });

      testWidgets('perancang perjalanan $tag', (tester) async {
        final sp = await prefs({
          'saved.v1': jsonEncode({
            'v': 1,
            'items': [
              {
                'id': 'home',
                'kind': 'home',
                'place': {
                  'name': 'Bangsar, Kuala Lumpur',
                  'subtitle': 'Kuala Lumpur',
                  'lat': 3.1290,
                  'lng': 101.6710,
                  'category': null,
                },
              },
              {
                'id': 'work',
                'kind': 'work',
                'place': {
                  'name': 'Petronas Twin Towers',
                  'subtitle': 'Jalan Ampang, Kuala Lumpur',
                  'lat': 3.1579,
                  'lng': 101.7116,
                  'category': null,
                },
              },
            ],
          }),
          'search.history.v1': [
            '{"name":"KLIA Terminal 1","subtitle":"Sepang, Selangor","lat":2.7456,"lng":101.7072,"category":"station"}',
            '{"name":"Petronas Twin Towers","subtitle":"Jalan Ampang, Kuala Lumpur","lat":3.1579,"lng":101.7116}',
            '{"name":"Masjid Negara","subtitle":"Jalan Perdana, Kuala Lumpur","lat":3.1419,"lng":101.6914,"category":"mosque"}',
          ],
        });
        usePhoneSurface(tester);
        safeTop(tester);
        reduceMotion(tester);
        await withShadows(() async {
          await pumpApp(
            tester,
            RepaintBoundary(key: key, child: const TripPlannerPage()),
            theme: t.value,
            locale: l.value,
            overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
          );
          await tester.pump(const Duration(milliseconds: 400));
          await _save(tester, key, '$out/trip_planner_$tag.png');
        });
      });

      testWidgets('tetapan $tag', (tester) async {
        final sp = await prefs();
        usePhoneSurface(tester, size: const Size(390, 1400));
        reduceMotion(tester);
        await withShadows(() async {
          await pumpApp(
            tester,
            RepaintBoundary(key: key, child: const SettingsPage()),
            theme: t.value,
            locale: l.value,
            overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
          );
          await tester.pumpAndSettle();
          await _save(tester, key, '$out/settings_$tag.png');
        });
      });
    }
  }
}

/// Data SEBENAR (Valhalla awam + OSM, diambil melalui GitHub Actions): laluan KLCC -> KLIA digabung dengan
/// kod penggabungan app (label), anggaran tol daripada dataset kadar rasmi, dan HUD daripada sesi
/// navigasi sebenar. Semua nombor dalam video datang dari sini.
void _realData(String out) {
  const dataDir = '../tools/promo/data';
  const key = ValueKey('promo-real');
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};
  final locales = {'ms': const Locale('ms'), 'en': const Locale('en')};

  List<RouteOption> load(String name) => parseRouteResponse(
    File('$dataDir/$name.json').readAsStringSync(),
    source: RouteSource.online,
  );

  late List<RouteOption> merged;
  late Map<String, TollEstimate> tolls;

  test('data sebenar: gabung, tol, eksport', () {
    merged = mergeRouteCandidates(
      standard: load('standard'),
      noTolls: load('noTolls'),
      noHighways: load('noHighways'),
      shortest: load('shortest'),
      detours: [for (var i = 0; i < 6; i++) ...load('via$i'), ...load('excl')],
    );
    final nodes = parseTollNodes(
      File('$dataDir/toll_nodes.json').readAsStringSync(),
    );
    final rates = TollRates.parse(
      File('assets/tolls/my_tolls.json').readAsStringSync(),
    );
    tolls = {
      for (final o in merged)
        routeKey(o): rates.estimate(
          matchTollPlazas(o.points, nodes),
          RouteVehicle.car,
        ),
    };
    List<List<double>> down(List<GeoPoint> pts) {
      final step = (pts.length / 900).ceil().clamp(1, 1000);
      return [
        for (var i = 0; i < pts.length; i += step) [pts[i].lat, pts[i].lng],
        [pts.last.lat, pts.last.lng],
      ];
    }

    final summary = [
      for (final o in merged)
        {
          'label': o.label.name,
          'durationS': o.durationS,
          'distanceM': o.distanceM,
          'hasTolls': o.hasTolls,
          'hasHighway': o.hasHighway,
          'via': o.via,
          'toll': {
            'plazas': tolls[routeKey(o)]!.plazaCount,
            'unknown': tolls[routeKey(o)]!.unknownCount,
            'knownRm': tolls[routeKey(o)]!.knownRm,
          },
          'points': down(o.points),
        },
    ];
    Directory('$out/../data').createSync(recursive: true);
    File('$out/../data/routes.json').writeAsStringSync(jsonEncode(summary));
    final main = NavRoute(merged.first);
    File('$out/../data/head.json').writeAsStringSync(
      jsonEncode({
        'points': [
          for (var i = 0; i < main.points.length && main.cum[i] <= 4500; i++)
            [main.points[i].lat, main.points[i].lng, main.cum[i]],
        ],
        'maneuvers': [
          for (final m in main.maneuvers)
            if (m.startM <= 4500)
              {'startM': m.startM, 'kind': m.kind.name, 'street': m.street},
        ],
        'totalM': main.totalM,
        'origin': [klcc.lat, klcc.lng],
        'destination': [klia.lat, klia.lng],
      }),
    );
    // ignore: avoid_print
    print(
      [
        for (final o in merged)
          '${o.label.name} ${o.durationS ~/ 60}min ${(o.distanceM / 1000).toStringAsFixed(1)}km tol=${tolls[routeKey(o)]!.knownRm.toStringAsFixed(2)} (${tolls[routeKey(o)]!.unknownCount}/${tolls[routeKey(o)]!.plazaCount} tak diketahui)',
      ].join('\n'),
    );
  });

  // Lembaran laluan sebenar, setiap pilihan terpilih secara bergilir.
  for (final t in themes.entries) {
    for (final l in locales.entries) {
      testWidgets('lembaran laluan sebenar ${l.key}_${t.key}', (tester) async {
        usePhoneSurface(tester, size: const Size(390, 700));
        reduceMotion(tester);
        final count = merged.length;
        for (var idx = 0; idx < count && idx < 10; idx++) {
          final ready = RouteReady(
            query: const RouteQuery(
              origin: klcc,
              destination: klia,
              destinationLabel: 'KLIA Terminal 1',
            ),
            options: merged,
            selectedIndex: idx,
            tolls: tolls,
            expanded: idx >= 6,
          );
          await withShadows(() async {
            await pumpApp(
              tester,
              Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 390,
                    child: RouteSummarySheet(
                      state: ready,
                      onSelect: (_) {},
                      onVehicleChanged: (_) {},
                      onRetry: () {},
                      onClear: () {},
                      onOpenOfflineMaps: () {},
                      onStart: () {},
                      onSimulate: () {},
                      now: DateTime(2026, 10, 26, 14, 5),
                    ),
                  ),
                ),
              ),
              theme: t.value,
              locale: l.value,
            );
            await tester.pumpAndSettle();
            await _save(
              tester,
              key,
              '$out/real_sheet_${idx}_${l.key}_${t.key}.png',
            );
          });
        }
      });
    }
  }

  // HUD daripada sesi navigasi sebenar pada laluan utama.
  for (final t in themes.entries) {
    for (final l in locales.entries) {
      testWidgets('HUD sebenar ${l.key}_${t.key}', (tester) async {
        usePhoneSurface(tester, size: const Size(390, 400));
        reduceMotion(tester);
        final route = NavRoute(merged.first);
        final clock = FakeClock();
        final session = NavigationSession(
          route: route,
          language: l.key == 'ms' ? VoiceLanguage.ms : VoiceLanguage.en,
          clock: clock.call,
        );
        final fixes = driveFixes(route, speedMps: 20, endM: 2600);
        final track = <Map<String, Object?>>[];
        var k = 0;
        for (var i = 0; i < fixes.length; i++) {
          clock.now = fixes[i].timestamp!;
          final u = session.onFix(fixes[i]);
          if (u == null || i % 2 != 0) continue;
          final p = u.progress;
          if (p.next == null) continue;
          await withShadows(() async {
            await pumpApp(
              tester,
              Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 390,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: ManeuverBanner(progress: p),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Row(
                            children: [
                              SpeedBubble(
                                speedMps: p.speedMps,
                                limitKmh: null,
                                overspeed: false,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: NavBottomPanel(
                            progress: p,
                            now: DateTime(2026, 10, 26, 14, 5),
                            simulated: false,
                            onEnd: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              theme: t.value,
              locale: l.value,
            );
            await tester.pump(const Duration(milliseconds: 50));
            await _save(
              tester,
              key,
              '$out/nav/hud_${l.key}_${t.key}_$k.png',
              ratio: 2,
            );
          });
          track.add({
            'k': k,
            'alongM': p.alongM,
            'lat': p.position.lat,
            'lng': p.position.lng,
            'bearing': p.bearing,
            'remainingM': p.remainingM,
            'remainingS': p.remainingS,
            'next': p.next!.kind.name,
            'distanceToNextM': p.distanceToNextM,
          });
          k++;
        }
        if (l.key == 'ms' && t.key == 'light') {
          Directory('$out/../data').createSync(recursive: true);
          File(
            '$out/../data/nav_track.json',
          ).writeAsStringSync(jsonEncode(track));
        }
      });
    }
  }
}

/// Ruang selamat atas (bar status) supaya kandungan tidak bertindih dengan bar status/pulau kamera
/// pada bingkai telefon dalam video.
void safeTop(WidgetTester tester, [double logical = 46]) {
  tester.view.padding = FakeViewPadding(top: logical * 3);
  tester.view.viewPadding = FakeViewPadding(top: logical * 3);
}

void main() {
  final out = Platform.environment['PROMO_OUT'];
  if (out == null || out.isEmpty) {
    test('promo: dilangkau (PROMO_OUT tiada)', () {}, skip: true);
    return;
  }
  setUpAll(loadAppFonts);
  _screens(out);
  _realData(out);

  const frameKey = ValueKey('promo-frame');
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};
  final locales = {'ms': const Locale('ms'), 'en': const Locale('en')};

  final right = _maneuver(
    1,
    ManeuverKind.right,
    1450,
    streets: ['Jalan Ampang'],
  );
  final left = _maneuver(2, ManeuverKind.left, 1600);
  final state = NavigationState(
    phase: NavPhase.active,
    progress: _progress(next: right, following: left),
    simulated: false,
  );
  final p = state.progress!;

  Widget transparent(Widget child, double width) => RepaintBoundary(
    key: frameKey,
    child: SizedBox(width: width, child: child),
  );

  for (final t in themes.entries) {
    for (final l in locales.entries) {
      final tag = '${l.key}_${t.key}';

      testWidgets('HUD atas $tag', (tester) async {
        usePhoneSurface(tester, size: const Size(390, 400));
        reduceMotion(tester);
        await withShadows(() async {
          await pumpApp(
            tester,
            Align(
              alignment: Alignment.topLeft,
              child: transparent(ManeuverBanner(progress: p), 366),
            ),
            theme: t.value,
            locale: l.value,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await _save(tester, frameKey, '$out/hud_banner_$tag.png');
        });
      });

      testWidgets('HUD bawah $tag', (tester) async {
        usePhoneSurface(tester, size: const Size(390, 400));
        reduceMotion(tester);
        await withShadows(() async {
          await pumpApp(
            tester,
            Align(
              alignment: Alignment.topLeft,
              child: transparent(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SpeedBubble(
                            speedMps: p.speedMps,
                            limitKmh: 60,
                            overspeed: false,
                          ),
                        ],
                      ),
                    ),
                    NavBottomPanel(
                      progress: p,
                      now: DateTime(2026, 10, 26, 14, 5),
                      simulated: false,
                      onEnd: () {},
                    ),
                  ],
                ),
                390,
              ),
            ),
            theme: t.value,
            locale: l.value,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await _save(tester, frameKey, '$out/hud_bottom_$tag.png');
        });
      });

      testWidgets('kad laluan $tag', (tester) async {
        usePhoneSurface(tester, size: const Size(390, 700));
        reduceMotion(tester);
        const query = RouteQuery(
          origin: klcc,
          destination: klia,
          destinationLabel: 'KLIA Terminal 1',
        );
        final ready = RouteReady(
          query: query,
          options: [
            sampleOption(
              via: 'Lebuhraya KLIA',
              label: RouteLabel.recommended,
              hasHighway: true,
            ),
            sampleOption(
              durationS: 3300,
              distanceM: 70100,
              label: RouteLabel.fastest,
            ),
            sampleOption(
              durationS: 3722,
              distanceM: 58100,
              label: RouteLabel.shortest,
            ),
            sampleOption(
              durationS: 4380,
              distanceM: 72447,
              hasTolls: false,
              label: RouteLabel.noTolls,
            ),
            sampleOption(
              durationS: 5100,
              distanceM: 80200,
              label: RouteLabel.noHighways,
            ),
            sampleOption(
              durationS: 4700,
              distanceM: 74000,
              label: RouteLabel.alternative,
            ),
            sampleOption(
              durationS: 4900,
              distanceM: 76000,
              label: RouteLabel.alternative,
            ),
            sampleOption(
              durationS: 5200,
              distanceM: 79000,
              label: RouteLabel.alternative,
            ),
            sampleOption(
              durationS: 5400,
              distanceM: 83000,
              label: RouteLabel.alternative,
            ),
          ],
        );
        await withShadows(() async {
          await pumpApp(
            tester,
            Align(
              alignment: Alignment.topLeft,
              child: transparent(
                RouteSummarySheet(
                  state: ready,
                  onSelect: (_) {},
                  onVehicleChanged: (_) {},
                  onRetry: () {},
                  onClear: () {},
                  onOpenOfflineMaps: () {},
                  onStart: () {},
                  onSimulate: () {},
                  now: DateTime(2026, 10, 26, 14, 5),
                ),
                390,
              ),
            ),
            theme: t.value,
            locale: l.value,
          );
          await tester.pumpAndSettle();
          await _save(tester, frameKey, '$out/route_sheet_$tag.png');
        });
      });
    }
  }

  // Kereta 3D sebenar (CarRenderer) pada beberapa arah: untuk animasi selekoh.
  testWidgets('sprite kereta 3D', (tester) async {
    await tester.runAsync(() async {
      for (final kind in [VehicleKind.car, VehicleKind.motorcycle]) {
        for (final dark in [false, true]) {
          final palette = CarPalette.forBrightness(
            const Color(0xFF2563EB),
            dark ? Brightness.dark : Brightness.light,
          );
          for (var yaw = -90; yaw <= 90; yaw += 5) {
            const size = 520.0;
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(
              recorder,
              const Rect.fromLTWH(0, 0, size, size),
            );
            CarRenderer(kind.mesh).paint(
              canvas,
              anchor: const Offset(size / 2, size * 0.62),
              lengthPx: 300 * kind.screenScale,
              yawDeg: yaw.toDouble(),
              tiltDeg: 55,
              palette: palette,
            );
            final image = await recorder.endRecording().toImage(
              size.toInt(),
              size.toInt(),
            );
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final name =
                '${kind.name}_${dark ? 'dark' : 'light'}_${yaw < 0 ? 'm${-yaw}' : 'p$yaw'}';
            File('$out/car/$name.png')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data!.buffer.asUint8List());
          }
        }
      }
    });
  });
}
