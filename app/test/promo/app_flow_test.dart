// Aliran app SEBENAR untuk video promosi: MapScreen dan skrin lain dirender dengan peta lutsinar
// (supaya enjin video boleh meletakkan peta ilustrasi di belakang UI sebenar). Setiap langkah
// disimpan sebagai PNG di $PROMO_OUT/flow/<bahasa>_<tema>/. Dilangkau tanpa PROMO_OUT.
//
//   PROMO_OUT=/laluan/promo_out/assets flutter test test/promo/app_flow_test.dart
@Tags(['promo'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/platform/external_actions.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/map_screen.dart';
import 'package:fgmap/features/map/presentation/map_view.dart';
import 'package:fgmap/features/navigation/data/screen_awake.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/offline_maps/domain/offline_models.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_map_controller.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_maps_sheet.dart';
import 'package:fgmap/features/onboarding/presentation/onboarding_page.dart';
import 'package:fgmap/features/splash/presentation/splash_page.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/data/toll_finder.dart';
import 'package:fgmap/features/route_preview/data/valhalla_codec.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/route_options_merge.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/search/data/nearby_search.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/presentation/place_search_controller.dart';
import 'package:fgmap/features/fuel/data/fuel_price_service.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:fgmap/features/speed_limits/domain/speed_limits.dart';
import 'package:fgmap/l10n/generated/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/navigation/nav_test_support.dart';
import '../helpers/fakes.dart';
import '../helpers/legal_override.dart';
import '../helpers/pump_app.dart';

const _rootKey = ValueKey('flow-root');
const _dataDir = '../tools/promo/data';

/// Peta lutsinar: UI app dirender sahaja, peta dilukis oleh enjin video.
class _TransparentMap {
  final camera = FakeCamera();
  MapViewConfig? config;
  bool _announced = false;

  Widget build(BuildContext context, MapViewConfig cfg) {
    config = cfg;
    if (!_announced) {
      _announced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => cfg.onReady(camera));
    }
    return const SizedBox.expand(key: ValueKey('fake-map'));
  }

  Override get override => mapViewBuilderProvider.overrideWithValue(build);
}

class _Geocoder implements Geocoder {
  static const klia = Place(
    name: 'KLIA',
    subtitle: 'Sepang, Selangor',
    point: GeoPoint(2.7456, 101.7072),
    category: 'station',
  );
  static const klccPlace = Place(
    name: 'KLCC',
    subtitle: 'Jalan Ampang, Kuala Lumpur',
    point: GeoPoint(3.1579, 101.7116),
  );
  static const sentral = Place(
    name: 'KL Sentral',
    subtitle: 'Brickfields, Kuala Lumpur',
    point: GeoPoint(3.1343, 101.6860),
    category: 'station',
  );
  static const kliaTwo = Place(
    name: 'KLIA2',
    subtitle: 'Sepang, Selangor',
    point: GeoPoint(2.7400, 101.6870),
    category: 'station',
  );

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    final q = query.toLowerCase();
    if (q.length < 2) return const [];
    if (q == 'kl') return [klccPlace, sentral, klia, kliaTwo];
    if (q == 'kli') return [klia, kliaTwo];
    if (q.startsWith('klia')) return [klia, kliaTwo];
    return const [];
  }
}

class _Nearby implements NearbySearch {
  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async => const NearbyResult([
    Place(
      name: 'Petronas Jalan Ampang',
      subtitle: 'Jalan Ampang, Kuala Lumpur',
      point: GeoPoint(3.1601, 101.7220),
      category: 'fuel',
      osmKey: 'amenity',
      osmType: 'N',
    ),
    Place(
      name: 'Shell Jalan Tun Razak',
      subtitle: 'Jalan Tun Razak, Kuala Lumpur',
      point: GeoPoint(3.1650, 101.7100),
      category: 'fuel',
      osmKey: 'amenity',
      osmType: 'N',
    ),
    Place(
      name: 'Petron Jalan P. Ramlee',
      subtitle: 'Jalan P. Ramlee, Kuala Lumpur',
      point: GeoPoint(3.1580, 101.7190),
      category: 'fuel',
      osmKey: 'amenity',
      osmType: 'N',
    ),
  ]);
}

class _TollFinder implements TollPlazaFinder {
  _TollFinder(this.nodes);
  final List<({String id, GeoPoint point, String? name})> nodes;

  @override
  Future<List<TollPlaza>> find(RouteOption route) async =>
      matchTollPlazas(route.points, nodes);
}

List<RouteOption> _realOptions() {
  List<RouteOption> load(String n) => parseRouteResponse(
    File('$_dataDir/$n.json').readAsStringSync(),
    source: RouteSource.online,
  );
  return mergeRouteCandidates(
    standard: load('standard'),
    noTolls: load('noTolls'),
    noHighways: load('noHighways'),
    shortest: load('shortest'),
    detours: [for (var i = 0; i < 6; i++) ...load('via$i'), ...load('excl')],
  );
}

Future<void> _snap(WidgetTester tester, String path, {double ratio = 2}) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_rootKey)) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void _safeTop(WidgetTester tester, [double logical = 46]) {
  tester.view.padding = FakeViewPadding(top: logical * 3);
  tester.view.viewPadding = FakeViewPadding(top: logical * 3);
}

Future<void> _pumpFlow(
  WidgetTester tester,
  Widget home, {
  required ThemeData theme,
  required Locale locale,
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: _rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    ),
  );
}

_TransparentMap? _lastMap;
String _curTag = '';
final Map<String, Map<String, Map<String, double>>> _targets = {};

/// Merekod pusat sasaran (koordinat logik 390x844) lalu mengetuknya.
Future<void> _tapRec(WidgetTester tester, String name, Finder f) async {
  _rec(tester, name, f);
  await tester.tap(f);
}

void _recIf(WidgetTester tester, String name, Finder f) {
  if (f.evaluate().isNotEmpty) _rec(tester, name, f.first);
}

void _rec(WidgetTester tester, String name, Finder f) {
  final r = tester.getRect(f);
  (_targets[_curTag] ??= {})[name] = {
    'x': r.center.dx,
    'y': r.center.dy,
    'l': r.left,
    't': r.top,
    'w': r.width,
    'h': r.height,
  };
}

DateTime Function() _nowFn = DateTime.now;

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

void main() {
  final out = Platform.environment['PROMO_OUT'];
  if (out == null || out.isEmpty) {
    test('promo flow: dilangkau (PROMO_OUT tiada)', () {}, skip: true);
    return;
  }
  tearDownAll(() {
    File('$out/flow/targets.json').writeAsStringSync(jsonEncode(_targets));
  });
  setUpAll(() async {
    await loadAppFonts();
    // app_links (tautan masuk) tiada pelaksanaan platform dalam ujian: jawab kosong.
    for (final name in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  final langs = (Platform.environment['PROMO_LANGS'] ?? 'ms').split(',');
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  File('$out/flow/meta.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        for (final e in themes.entries)
          e.key: {
            'scaffold': hex(e.value.scaffoldBackgroundColor),
            'surface': hex(e.value.colorScheme.surface),
            'primary': hex(e.value.colorScheme.primary),
          },
      }),
    );
  final options = _realOptions();
  final nodes = parseTollNodes(
    File('$_dataDir/toll_nodes.json').readAsStringSync(),
  );
  final rates = TollRates.parse(
    File('assets/tolls/my_tolls.json').readAsStringSync(),
  );

  Future<SharedPreferences> prefs(Map<String, Object> v) async {
    SharedPreferences.setMockInitialValues(v);
    return SharedPreferences.getInstance();
  }

  Map<String, Object> seed() => {
    'fuel.price.manual': 2.05,
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
      '{"name":"Masjid Negara","subtitle":"Jalan Perdana, Kuala Lumpur","lat":3.1419,"lng":101.6914,"category":"mosque"}',
    ],
  };

  for (final lang in langs) {
    for (final t in themes.entries) {
      final tag = '${lang}_${t.key}';
      final dir = '$out/flow/$tag';

      List<Override> overrides(
        _TransparentMap map,
        SharedPreferences sp,
        FakeLocationService location, {
        List<RouteOption>? route,
        FakeRoutePlanner? planner,
      }) {
        final pl = planner ?? FakeRoutePlanner((_) async => route ?? options);
        return [
          map.override,
          locationServiceProvider.overrideWithValue(location),
          routePlannerProvider.overrideWithValue(pl),
          routeOptionsPlannerProvider.overrideWithValue(pl),
          sharedPreferencesProvider.overrideWithValue(sp),
          geocoderProvider.overrideWithValue(_Geocoder()),
          searchDebounceProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
          nearbySearchProvider.overrideWithValue(_Nearby()),
          tollLookupEnabledProvider.overrideWithValue(true),
          tollPlazaFinderProvider.overrideWithValue(_TollFinder(nodes)),
          tollRatesProvider.overrideWith((ref) async => rates),
          voiceGuideProvider.overrideWithValue(FakeVoice()),
          fuelPricesProvider.overrideWith((ref) async => null),
          speedLimitServiceProvider.overrideWithValue(
            FakeSpeedLimitService(
              const SpeedLimits([
                SpeedLimitSegment(
                  beginShapeIndex: 0,
                  endShapeIndex: 1000,
                  lengthM: 1600,
                  limitKmh: 60,
                ),
                SpeedLimitSegment(
                  beginShapeIndex: 1000,
                  endShapeIndex: 100000,
                  lengthM: 70000,
                  limitKmh: 80,
                ),
              ]),
            ),
          ),
          screenAwakeProvider.overrideWithValue(FakeAwake()),
          shareServiceProvider.overrideWithValue(FakeShareService()),
          phoneDialerProvider.overrideWithValue(FakePhoneDialer()),
        ];
      }

      Future<ProviderContainer> startMap(
        WidgetTester tester, {
        List<RouteOption>? route,
        FakeLocationService? location,
        FakeRoutePlanner? planner,
      }) async {
        usePhoneSurface(tester);
        _safeTop(tester);
        reduceMotion(tester);
        final map = _TransparentMap();
        final sp = await prefs(seed());
        final wall = DateTime.now();
        final wallBase = tester.binding.clock.now();
        _nowFn = () =>
            wall.add(tester.binding.clock.now().difference(wallBase));
        final loc =
            location ??
            FakeLocationService(fix: const LocationFix(point: klcc));
        final base = overrides(map, sp, loc, route: route, planner: planner);
        await _pumpFlow(
          tester,
          const MapScreen(),
          theme: t.value,
          locale: Locale(lang),
          overrides: [
            ...base,
            navClockProvider.overrideWithValue(
              () => wall.add(tester.binding.clock.now().difference(wallBase)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        _lastMap = map;
        return ProviderScope.containerOf(
          tester.element(find.byType(MapScreen)),
        );
      }

      testWidgets('aliran B: navigasi simulasi $tag', (tester) async {
        _curTag = tag;
        final container = await startMap(tester);
        await withShadows(() async {
          _lastMap!.config!.onLongPress(const GeoPoint(2.7456, 101.7072));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          await _tapRec(
            tester,
            'nav_simulate',
            find.byKey(const ValueKey('nav-simulate')),
          );
          await tester.pump();
          final track = <Map<String, Object?>>[];
          var frame = 0;
          for (var step = 0; step < 700 && frame < 380; step++) {
            await tester.pump(const Duration(seconds: 1));
            final st = container.read(navigationControllerProvider);
            final p = st.progress;
            if (p == null) continue;
            await _snap(
              tester,
              '$dir/nav_${frame.toString().padLeft(3, '0')}.png',
            );
            track.add({
              'f': frame,
              'alongM': p.alongM,
              'remainingM': p.remainingM,
              'speedMps': p.speedMps,
              'next': p.next?.kind.name,
              'distanceToNextM': p.distanceToNextM,
              'pos': {'lat': p.position.lat, 'lng': p.position.lng},
              'bearing': p.bearing,
              'cam': _lastMap!.camera.pose == null
                  ? null
                  : {
                      'lat': _lastMap!.camera.pose!.center.lat,
                      'lng': _lastMap!.camera.pose!.center.lng,
                      'zoom': _lastMap!.camera.pose!.zoom,
                      'tilt': _lastMap!.camera.pose!.tilt,
                      'bearing': _lastMap!.camera.pose!.bearing,
                    },
              'veh':
                  _lastMap!.camera.vehicleCalls.isEmpty ||
                      _lastMap!.camera.vehicleCalls.last == null
                  ? null
                  : {
                      'lat': _lastMap!.camera.vehicleCalls.last!.point.lat,
                      'lng': _lastMap!.camera.vehicleCalls.last!.point.lng,
                      'bearing': _lastMap!.camera.vehicleCalls.last!.bearing,
                    },
            });
            frame++;
            if (p.alongM > 2100) break;
          }
          File('$dir/nav_track.json').writeAsStringSync(jsonEncode(track));
          // lembaran tetapan navigasi (kongsi masa tiba, kecemasan, suara)
          await tester.tap(
            find.byTooltip(
              lang == 'ms' ? 'Tetapan navigasi' : 'Navigation settings',
            ),
          );
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
          await _snap(tester, '$dir/nav_settings.png');
          await tester.tapAt(const Offset(195, 60));
          await tester.pump(const Duration(milliseconds: 500));
          await container.read(navigationControllerProvider.notifier).stop();
          await tester.pump(const Duration(seconds: 3));
        });
      });

      testWidgets('aliran C: laluan semula $tag', (tester) async {
        _curTag = tag;
        final location = FakeLocationService(
          fix: const LocationFix(point: klcc),
        );
        final planner = FakeRoutePlanner((_) async => options);
        final container = await startMap(
          tester,
          location: location,
          planner: planner,
        );
        final route = NavRoute(options.first);
        await withShadows(() async {
          _lastMap!.config!.onLongPress(const GeoPoint(2.7456, 101.7072));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          await _tapRec(
            tester,
            'nav_start',
            find.byKey(const ValueKey('nav-start')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          LocationFix at(double along, {double offM = 0}) {
            final bearing = route.bearingAt(along, lookAheadM: 15);
            var point = route.pointAt(along);
            if (offM != 0) point = destinationPoint(point, bearing + 90, offM);
            return LocationFix(
              point: point,
              headingDegrees: bearing.round() % 360,
              accuracyMeters: 5,
              speedMps: 14,
              timestamp: _nowFn(),
            );
          }

          var along = 40.0;
          var frame = 0;
          Future<void> shot() async {
            await _snap(
              tester,
              '$dir/reroute_${frame.toString().padLeft(2, '0')}.png',
            );
            frame++;
          }

          for (var i = 0; i < 6; i++) {
            location.navigationController.add(at(along));
            along += 14;
            await tester.pump(const Duration(seconds: 1));
          }
          await shot();
          // Tersasar: tahan permintaan laluan semula supaya keadaan "mengira semula" kekal.
          final gate = Completer<List<RouteOption>>();
          planner.handler = (_) => gate.future;
          for (var i = 0; i < 7; i++) {
            location.navigationController.add(at(along, offM: 70 + i * 6));
            along += 14;
            await tester.pump(const Duration(seconds: 1));
            if (container.read(navigationControllerProvider).rerouting) break;
          }
          await tester.pump(const Duration(milliseconds: 600));
          await shot();
          await tester.pump(const Duration(milliseconds: 800));
          await shot();
          gate.complete(options);
          await tester.pump(const Duration(seconds: 1));
          for (var i = 0; i < 4; i++) {
            location.navigationController.add(at(along));
            along += 14;
            await tester.pump(const Duration(seconds: 1));
          }
          await shot();
          await container.read(navigationControllerProvider.notifier).stop();
          await tester.pump(const Duration(seconds: 3));
        });
      });

      testWidgets('aliran D: sampai $tag', (tester) async {
        _curTag = tag;
        final container = await startMap(
          tester,
          route: [lShapedRoute(legM: 500)],
        );
        await withShadows(() async {
          _lastMap!.config!.onLongPress(const GeoPoint(2.7456, 101.7072));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          await _tapRec(
            tester,
            'nav_simulate',
            find.byKey(const ValueKey('nav-simulate')),
          );
          await tester.pump();
          var frame = 0;
          for (var step = 0; step < 900; step++) {
            await tester.pump(const Duration(seconds: 1));
            final st = container.read(navigationControllerProvider);
            final p = st.progress;
            final near = p != null && p.remainingM < 140;
            if (near || find.byType(ArrivalCard).evaluate().isNotEmpty) {
              await _snap(
                tester,
                '$dir/arrive_${frame.toString().padLeft(2, '0')}.png',
              );
              frame++;
              if (find.byType(ArrivalCard).evaluate().isNotEmpty && frame > 3) {
                await tester.pump(const Duration(seconds: 1));
                await _snap(tester, '$dir/arrive_done.png');
                break;
              }
            }
          }
          await container.read(navigationControllerProvider.notifier).stop();
          await tester.pump(const Duration(seconds: 3));
        });
      });

      testWidgets('aliran E: ciri $tag', (tester) async {
        _curTag = tag;
        await startMap(tester);
        await withShadows(() async {
          _recIf(
            tester,
            'chip_home',
            find.text(lang == 'ms' ? 'Rumah' : 'Home'),
          );
          await _tapRec(
            tester,
            'emergency',
            find.byTooltip(lang == 'ms' ? 'Kecemasan' : 'Emergency'),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/emergency.png');
          await tester.tapAt(const Offset(195, 60));
          await tester.pumpAndSettle();
          await _tapRec(
            tester,
            'report',
            find.byTooltip(lang == 'ms' ? 'Laporkan' : 'Report'),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/report.png');
          await tester.tapAt(const Offset(195, 60));
          await tester.pumpAndSettle();
          // cari berhampiran: perancang -> stesen minyak
          await _tapRec(
            tester,
            'search_pill',
            find.byKey(const ValueKey('search-pill')),
          );
          await tester.pumpAndSettle();
          await _tapRec(
            tester,
            'chip_fuel',
            find.text(lang == 'ms' ? 'Stesen minyak' : 'Fuel'),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/nearby_fuel.png');
        });
      });

      testWidgets('aliran F: simpan tempat $tag', (tester) async {
        _curTag = tag;
        await startMap(tester);
        await withShadows(() async {
          _lastMap!.config!.onLongPress(const GeoPoint(2.7456, 101.7072));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          await _tapRec(
            tester,
            'save_destination',
            find.byKey(const ValueKey('save-destination')),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/save_place.png');
        });
      });

      testWidgets('aliran G: peta offline dan tetapan $tag', (tester) async {
        _curTag = tag;
        usePhoneSurface(tester);
        _safeTop(tester);
        reduceMotion(tester);
        final states = {
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
        await withShadows(() async {
          for (final e in states.entries) {
            await tester.pumpWidget(const SizedBox());
            final map = _TransparentMap();
            final sp = await prefs(seed());
            await _pumpFlow(
              tester,
              const MapScreen(),
              theme: t.value,
              locale: Locale(lang),
              overrides: [
                ...overrides(
                  map,
                  sp,
                  FakeLocationService(fix: const LocationFix(point: klcc)),
                ),
                offlineMapControllerProvider.overrideWith(
                  () => _FakeOffline(e.value),
                ),
                isMeteredConnectionProvider.overrideWithValue(
                  () async => false,
                ),
              ],
            );
            await tester.pumpAndSettle();
            await _tapRec(
              tester,
              'offline_btn',
              find.byTooltip(lang == 'ms' ? 'Peta offline' : 'Offline map'),
            );
            await tester.pumpAndSettle();
            if (e.key == 'idle') {
              _recIf(
                tester,
                'download_btn',
                find.text(lang == 'ms' ? 'Muat turun' : 'Download'),
              );
            }
            await _snap(tester, '$dir/offline_${e.key}.png');
            await tester.tapAt(const Offset(195, 60));
            await tester.pumpAndSettle();
          }
          // Tetapan penampilan (tema)
          await tester.pumpWidget(const SizedBox());
          final map = _TransparentMap();
          final sp = await prefs(seed());
          await _pumpFlow(
            tester,
            const MapScreen(),
            theme: t.value,
            locale: Locale(lang),
            overrides: overrides(
              map,
              sp,
              FakeLocationService(fix: const LocationFix(point: klcc)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byTooltip(lang == 'ms' ? 'Tetapan' : 'Settings'),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/settings.png');
        });
      });

      testWidgets('aliran H: splash dan onboarding $tag', (tester) async {
        _curTag = tag;
        usePhoneSurface(tester, size: const Size(390, 844));
        _safeTop(tester);
        final sp = await prefs(seed());
        final base = [
          sharedPreferencesProvider.overrideWithValue(sp),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          legalTextOverride(),
        ];
        await withShadows(() async {
          if (t.key == 'light') {
            await tester.pumpWidget(
              ProviderScope(
                overrides: base,
                child: RepaintBoundary(
                  key: _rootKey,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: t.value,
                    locale: Locale(lang),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: const SplashPage(),
                  ),
                ),
              ),
            );
            for (var i = 0; i < 40; i++) {
              await tester.pump(const Duration(milliseconds: 50));
              await _snap(
                tester,
                '$out/flow/splash_$lang/${i.toString().padLeft(2, '0')}.png',
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
          await _pumpFlow(
            tester,
            const OnboardingPage(),
            theme: t.value,
            locale: Locale(lang),
            overrides: base,
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < 3; i++) {
            await _snap(tester, '$dir/onboarding_$i.png');
            final next = find.byKey(const ValueKey('onboarding-next'));
            if (next.evaluate().isEmpty) break;
            await _tapRec(tester, 'onboarding_next', next);
            await tester.pumpAndSettle();
          }
        });
      });

      testWidgets('aliran A: peta, carian, laluan $tag', (tester) async {
        _curTag = tag;
        usePhoneSurface(tester);
        _safeTop(tester);
        reduceMotion(tester);
        final map = _TransparentMap();
        final sp = await prefs(seed());
        final location = FakeLocationService(
          fix: const LocationFix(point: klcc),
        );
        await withShadows(() async {
          await _pumpFlow(
            tester,
            const MapScreen(),
            theme: t.value,
            locale: Locale(lang),
            overrides: overrides(map, sp, location),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/map_idle.png');

          await _tapRec(
            tester,
            'search_pill',
            find.byKey(const ValueKey('search-pill')),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/search_empty.png');

          final field = find.byKey(const ValueKey('destination-field'));
          var i = 0;
          for (final text in ['K', 'KL', 'KLI', 'KLIA']) {
            await tester.enterText(field, text);
            await tester.pump(const Duration(milliseconds: 40));
            await tester.pump();
            await tester.pumpAndSettle();
            await _snap(tester, '$dir/search_t${i++}.png');
          }

          // Pilih KLIA (hasil pertama) -> laluan dikira.
          _recIf(tester, 'result_klia', find.text('KLIA').last);
          await tester.tap(find.text('KLIA').last);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          _recIf(
            tester,
            'toll_summary',
            find.byKey(const ValueKey('toll-summary')),
          );
          _recIf(tester, 'fuel_cost', find.byKey(const ValueKey('fuel-cost')));
          await _snap(tester, '$dir/route_ready_0.png');
          for (var k = 1; k < 5; k++) {
            final tile = find.byKey(ValueKey('route-option-$k'));
            if (tile.evaluate().isEmpty) break;
            await tester.ensureVisible(tile);
            await tester.pumpAndSettle();
            await _tapRec(tester, 'route_option_$k', tile);
            await tester.pumpAndSettle();
            await _snap(tester, '$dir/route_ready_$k.png');
          }
          await tester.tap(find.byKey(const ValueKey('route-option-0')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byTooltip(lang == 'ms' ? 'Motosikal' : 'Motorcycle'),
          );
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/route_ready_moto.png');
          await _tapRec(
            tester,
            'car',
            find.byTooltip(lang == 'ms' ? 'Kereta' : 'Car'),
          );
          await tester.pumpAndSettle();
          _rec(tester, 'nav_start', find.byKey(const ValueKey('nav-start')));
          _rec(
            tester,
            'nav_simulate',
            find.byKey(const ValueKey('nav-simulate')),
          );
          _rec(
            tester,
            'save_destination',
            find.byKey(const ValueKey('save-destination')),
          );
          _rec(
            tester,
            'share_destination',
            find.byKey(const ValueKey('share-destination')),
          );
          // Matikan navigasi/laluan supaya ujian tamat bersih.
          await tester.tap(
            find.byTooltip(lang == 'ms' ? 'Padam laluan' : 'Clear route'),
          );
          await tester.pumpAndSettle();
        });
      });
    }
  }
}
