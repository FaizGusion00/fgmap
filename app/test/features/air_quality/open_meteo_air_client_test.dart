import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/air_quality/data/open_meteo_air_client.dart';
import 'package:fgmap/features/air_quality/domain/air_quality.dart';
import 'package:flutter_test/flutter_test.dart';

const _kl = GeoPoint(3.1578, 101.7117);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Object Function(RequestOptions o) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final r = handler(options);
    if (r is Exception) throw r;
    return ResponseBody.fromString(
      jsonEncode(r),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('jalur AQI mengikut ambang US', () {
    expect(airBandFor(0), AirBand.good);
    expect(airBandFor(50), AirBand.good);
    expect(airBandFor(51), AirBand.moderate);
    expect(airBandFor(100), AirBand.moderate);
    expect(airBandFor(101), AirBand.sensitive);
    expect(airBandFor(151), AirBand.unhealthy);
    expect(airBandFor(201), AirBand.veryUnhealthy);
    expect(airBandFor(301), AirBand.hazardous);
  });

  test('menghuraikan AQI dan membundarkan koordinat', () async {
    final adapter = _FakeAdapter(
      (_) => {
        'current': {
          'us_aqi': 42,
          'pm2_5': 8.2,
          'pm10': 14,
          'nitrogen_dioxide': 6.1,
          'ozone': 48,
        },
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final reading = await OpenMeteoAirClient(dio).fetch(point: _kl, here: true);
    expect(reading, isNotNull);
    expect(reading!.usAqi, 42);
    expect(reading.band, AirBand.good);
    expect(reading.pm25, 8.2);
    expect(reading.here, isTrue);
    expect(reading.fromCache, isFalse);
    final q = adapter.requests.single.queryParameters;
    expect(q['latitude'], '3.158');
    expect(q['longitude'], '101.712');
    expect(adapter.requests.single.uri.host, 'air-quality-api.open-meteo.com');
  });

  test('ralat rangkaian tanpa cache memberi null', () async {
    final adapter = _FakeAdapter(
      (o) => DioException.connectionError(requestOptions: o, reason: 'off'),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    expect(await OpenMeteoAirClient(dio).fetch(point: _kl), isNull);
  });

  test('ralat selepas kejayaan guna cache jika tempat dekat', () async {
    var fail = false;
    final adapter = _FakeAdapter((o) {
      if (fail) {
        return DioException.connectionError(requestOptions: o, reason: 'off');
      }
      return {
        'current': {'us_aqi': 88, 'pm2_5': 20},
      };
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final c = OpenMeteoAirClient(dio);
    final first = await c.fetch(point: _kl, placeLabel: 'KL');
    fail = true;
    final near = await c.fetch(point: const GeoPoint(3.17, 101.72));
    expect(near!.fromCache, isTrue);
    expect(near.usAqi, first!.usAqi);
    final far = await c.fetch(point: const GeoPoint(5.4, 100.3));
    expect(far, isNull);
  });
}
