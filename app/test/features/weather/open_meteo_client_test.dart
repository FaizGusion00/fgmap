import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/weather/data/open_meteo_client.dart';
import 'package:fgmap/features/weather/domain/weather_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

const _dest = GeoPoint(3.1578, 101.7117);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Object Function(RequestOptions o, int n) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final r = handler(options, requests.length);
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

Map<String, Object?> _body({
  num temp = 31.5,
  int code = 1,
  int precipProb = 10,
  num precipMm = 0,
  bool hourly = true,
}) {
  final now = DateTime.now().toUtc();
  return {
    'current': {
      'temperature_2m': temp,
      'weather_code': code,
      'precipitation': precipMm,
      'precipitation_probability': precipProb,
      'relative_humidity_2m': 70,
      'apparent_temperature': temp - 1,
      'wind_speed_10m': 12.0,
    },
    if (hourly)
      'hourly': {
        'time': [
          for (var i = 0; i < 6; i++)
            now.add(Duration(hours: i)).toIso8601String(),
        ],
        'temperature_2m': [for (var i = 0; i < 6; i++) temp - i * 0.2],
        'weather_code': [for (var i = 0; i < 6; i++) code],
        'precipitation_probability': [
          precipProb,
          for (var i = 1; i < 6; i++) precipProb + i,
        ],
      },
  };
}

(OpenMeteoClient, _FakeAdapter) _client(
  Object Function(RequestOptions o, int n) handler,
) {
  final adapter = _FakeAdapter(handler);
  final dio = Dio()..httpClientAdapter = adapter;
  return (OpenMeteoClient(dio), adapter);
}

void main() {
  test(
    'menghuraikan cuaca semasa dan membundarkan koordinat kepada 3 perpuluhan',
    () async {
      final (c, adapter) = _client((_, _) => _body());
      final snap = await c.fetch(destination: _dest);
      expect(snap, isNotNull);
      expect(snap!.tempC, 31.5);
      expect(snap.weatherCode, 1);
      expect(snap.precipProb, 10);
      expect(snap.destination.humidityPct, 70);
      expect(snap.hours, isNotEmpty);
      expect(snap.rainAlongRoute, isFalse);
      expect(snap.severe, isFalse);
      expect(snap.isStale, isFalse);
      final q = adapter.requests.single.queryParameters;
      expect(q['latitude'], '3.158');
      expect(q['longitude'], '101.712');
      expect(adapter.requests.single.uri.host, 'api.open-meteo.com');
    },
  );

  test('hujan tinggi di destinasi menandakan rainAlongRoute', () async {
    final (c, _) = _client((_, _) => _body(precipProb: 70));
    expect((await c.fetch(destination: _dest))!.rainAlongRoute, isTrue);
  });

  test('kod ribut petir dan hujan lebat dianggap teruk', () async {
    for (final code in [65, 82, 95, 96, 99]) {
      final (c, _) = _client((_, _) => _body(code: code));
      expect(
        (await c.fetch(destination: _dest))!.severe,
        isTrue,
        reason: '$code',
      );
    }
    for (final code in [0, 3, 61, 63, 71, 73, 75, 80, 81]) {
      final (c, _) = _client((_, _) => _body(code: code));
      expect(
        (await c.fetch(destination: _dest))!.severe,
        isFalse,
        reason: '$code',
      );
    }
  });

  test(
    'sampel sepanjang laluan: hujan dan cuaca teruk dikesan, maks 4 sampel',
    () async {
      final (c, adapter) = _client((o, n) {
        if (n == 1) return _body();
        if (n == 3) {
          return _body(precipProb: 80, hourly: false);
        }
        if (n == 4) {
          return _body(code: 95, precipProb: 0, hourly: false);
        }
        return _body(precipProb: 0, hourly: false);
      });
      final samples = [
        for (var i = 0; i < 6; i++) GeoPoint(3.0 + i * 0.1, 101.5),
      ];
      final snap = await c.fetch(destination: _dest, alongSamples: samples);
      expect(adapter.requests.length, 5); // 1 destinasi + 4 sampel
      expect(snap!.rainAlongRoute, isTrue);
      expect(snap.severe, isTrue);
    },
  );

  test('asal GPS diambil jika jauh dari destinasi', () async {
    final (c, adapter) = _client((_, n) {
      if (n == 1) return _body(temp: 32);
      return _body(temp: 28, code: 0);
    });
    final snap = await c.fetch(
      destination: _dest,
      origin: const GeoPoint(5.4, 100.3),
    );
    expect(adapter.requests.length, 2);
    expect(snap!.origin, isNotNull);
    expect(snap.origin!.tempC, 28);
    expect(snap.destination.tempC, 32);
  });

  test('ralat pada satu sampel tidak menggagalkan keseluruhan', () async {
    final (c, _) = _client((o, n) {
      if (n == 2) {
        return DioException.connectionError(requestOptions: o, reason: 'x');
      }
      return _body(hourly: n == 1);
    });
    final snap = await c.fetch(
      destination: _dest,
      alongSamples: const [GeoPoint(3.0, 101.5), GeoPoint(2.9, 101.6)],
    );
    expect(snap, isNotNull);
  });

  test('soft-fail: ralat rangkaian tanpa cache memberi null', () async {
    final (c, _) = _client(
      (o, _) => DioException.connectionError(requestOptions: o, reason: 'off'),
    );
    expect(await c.fetch(destination: _dest), isNull);
  });

  test(
    'soft-fail: respons tanpa "current" memberi null (tiada cache)',
    () async {
      final (c, _) = _client((_, _) => {'foo': 1});
      expect(await c.fetch(destination: _dest), isNull);
    },
  );

  test(
    'ralat selepas kejayaan memulangkan cache jika destinasi dekat',
    () async {
      var fail = false;
      final (c, _) = _client((o, _) {
        if (fail) {
          return DioException.connectionError(requestOptions: o, reason: 'off');
        }
        return _body(temp: 28);
      });
      final first = await c.fetch(destination: _dest);
      fail = true;
      final near = await c.fetch(destination: const GeoPoint(3.17, 101.72));
      expect(near!.fromCache, isTrue);
      expect(near.tempC, first!.tempC);
      final far = await c.fetch(destination: const GeoPoint(5.4, 100.3));
      expect(far, isNull);
    },
  );

  group('WeatherSnapshot', () {
    test('isStale selepas 2 jam', () {
      final fresh = WeatherSnapshot(
        destination: const WeatherPoint(
          tempC: 30,
          weatherCode: 0,
          precipProb: 0,
        ),
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      final old = WeatherSnapshot(
        destination: const WeatherPoint(
          tempC: 30,
          weatherCode: 0,
          precipProb: 0,
        ),
        fetchedAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(fresh.isStale, isFalse);
      expect(old.isStale, isTrue);
    });
  });
}
