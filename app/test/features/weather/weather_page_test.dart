import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/weather/data/open_meteo_client.dart';
import 'package:fgmap/features/weather/data/weather_forecast_store.dart';
import 'package:fgmap/features/weather/domain/weather_forecast.dart';
import 'package:fgmap/features/weather/presentation/weather_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _kt = GeoPoint(5.329, 103.137);

Map<String, dynamic> _fixture({bool day = false, int? code}) {
  final json =
      jsonDecode(
            File(
              'test/features/weather/fixtures/open_meteo_forecast_kt.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final current = json['current'] as Map<String, dynamic>;
  if (day) current['is_day'] = 1;
  if (code != null) current['weather_code'] = code;
  return json;
}

class _Reverse implements ReverseGeocoder {
  @override
  Future<Place?> reverse(GeoPoint point, {CancelToken? cancel}) async =>
      const Place(
        name: 'Kuala Terengganu',
        subtitle: 'Kuala Terengganu, Terengganu, Malaysia',
        point: _kt,
      );
}

void main() {
  test('ramalan dihurai: semasa, 48 jam, 10 hari, matahari terbit', () {
    final f = WeatherForecast.parse(_fixture(), _kt)!;
    expect(f.hours, hasLength(48));
    expect(f.days, hasLength(10));
    expect(f.current.humidityPct, isNotNull);
    expect(f.current.windDirDeg, isNotNull);
    expect(f.today!.sunrise, isNotNull);
    expect(f.timezone, 'Asia/Kuala_Lumpur');
  });

  test('simpanan: disimpan dan dibaca semula tanpa rangkaian', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = WeatherForecastStore(prefs);
    final at = DateTime.now();
    await store.save(_kt, _fixture(), at);
    final back = store.load(const GeoPoint(5.3291, 103.1371))!;
    expect(back.days, hasLength(10));
    expect(back.fetchedAt.difference(at).inSeconds.abs(), lessThan(1));
    expect(back.isStale(), isFalse);
  });

  Future<void> pump(
    WidgetTester tester, {
    required Map<String, dynamic> response,
    Locale locale = const Locale('ms'),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio()
      ..httpClientAdapter = StubAdapter((_) => StubAdapter.json(response));
    usePhoneSurface(tester, size: const Size(390, 1400));
    reduceMotion(tester);
    await pumpApp(
      tester,
      const WeatherPage(),
      locale: locale,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(fix: const LocationFix(point: _kt)),
        ),
        reverseGeocoderProvider.overrideWithValue(_Reverse()),
        openMeteoClientProvider.overrideWithValue(OpenMeteoClient(dio)),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lokasi semasa: nama, suhu, jam, 10 hari, butiran', (
    tester,
  ) async {
    await pump(tester, response: _fixture());
    expect(find.text('Kuala Terengganu'), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-temp')), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-hourly')), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-daily')), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kelembapan'.toUpperCase()), findsOneWidget);
  });

  testWidgets('golden: siang berawan (BM)', (tester) async {
    await pump(tester, response: _fixture(day: true, code: 2));
    await expectLater(
      find.byType(WeatherPage),
      matchesGoldenFile('goldens/weather_page_day.png'),
    );
  });

  testWidgets('golden: malam ribut (English)', (tester) async {
    await pump(
      tester,
      response: _fixture(code: 95),
      locale: const Locale('en'),
    );
    expect(find.textContaining('Thunderstorm'), findsWidgets);
    await expectLater(
      find.byType(WeatherPage),
      matchesGoldenFile('goldens/weather_page_storm_en.png'),
    );
  });
}
