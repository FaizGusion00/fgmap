// Aliran app SEBENAR untuk video promosi: MapScreen dan skrin lain dirender dengan peta lutsinar
// (supaya enjin video boleh meletakkan peta ilustrasi di belakang UI sebenar). Setiap langkah
// disimpan sebagai PNG di $PROMO_OUT/flow/<bahasa>_<tema>/. Dilangkau tanpa PROMO_OUT.
//
//   PROMO_OUT=/laluan/promo_out/assets flutter test test/promo/app_flow_test.dart
@Tags(['promo'])
library;

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
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
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
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
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

void main() {
  final out = Platform.environment['PROMO_OUT'];
  if (out == null || out.isEmpty) {
    test('promo flow: dilangkau (PROMO_OUT tiada)', () {}, skip: true);
    return;
  }
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
      }) => [
        map.override,
        locationServiceProvider.overrideWithValue(location),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => route ?? options),
        ),
        routeOptionsPlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => route ?? options),
        ),
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
        speedLimitServiceProvider.overrideWithValue(FakeSpeedLimitService()),
        screenAwakeProvider.overrideWithValue(FakeAwake()),
        shareServiceProvider.overrideWithValue(FakeShareService()),
        phoneDialerProvider.overrideWithValue(FakePhoneDialer()),
      ];

      testWidgets('aliran A: peta, carian, laluan $tag', (tester) async {
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

          await tester.tap(find.byKey(const ValueKey('search-pill')));
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
          await tester.tap(find.text('KLIA').last);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          await _snap(tester, '$dir/route_ready_0.png');
          for (var k = 1; k < 5; k++) {
            final tile = find.byKey(ValueKey('route-option-$k'));
            if (tile.evaluate().isEmpty) break;
            await tester.ensureVisible(tile);
            await tester.pumpAndSettle();
            await tester.tap(tile);
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
          await tester.tap(find.byTooltip(lang == 'ms' ? 'Kereta' : 'Car'));
          await tester.pumpAndSettle();
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
