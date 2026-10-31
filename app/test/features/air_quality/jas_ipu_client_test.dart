import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/air_quality/data/jas_ipu_client.dart';
import 'package:fgmap/features/air_quality/domain/air_quality.dart';
import 'package:flutter_test/flutter_test.dart';

const _kl = GeoPoint(3.15, 101.70);

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

Map<String, Object?> _row({
  required String id,
  required String name,
  required double lat,
  required double lng,
  required int api,
  String dt = '2026-10-31T19:00:00',
}) => {
  'STATION_ID': id,
  'STATION_LOCATION': name,
  'LATITUDE': lat,
  'LONGITUDE': lng,
  'API': api,
  'DATETIME': dt,
};

void main() {
  test('jalur IPU JAS (tanpa jalur sensitif AQI AS)', () {
    expect(airBandFor(0), AirBand.good);
    expect(airBandFor(50), AirBand.good);
    expect(airBandFor(51), AirBand.moderate);
    expect(airBandFor(100), AirBand.moderate);
    expect(airBandFor(101), AirBand.unhealthy);
    expect(airBandFor(200), AirBand.unhealthy);
    expect(airBandFor(201), AirBand.veryUnhealthy);
    expect(airBandFor(301), AirBand.hazardous);
  });

  test('mengambil bacaan terkini setiap stesen dan stesen KL terdekat', () async {
    final adapter = _FakeAdapter(
      (_) => {
        'api_table_hourly': [
          _row(
            id: 'CA01R',
            name: 'Kangar, PERLIS',
            lat: 6.43,
            lng: 100.21,
            api: 31,
          ),
          _row(
            id: 'CA02',
            name: 'Cheras, W.P. KUALA LUMPUR',
            lat: 3.106,
            lng: 101.718,
            api: 80,
            dt: '2026-10-31T18:00:00',
          ),
          _row(
            id: 'CA02',
            name: 'Cheras, W.P. KUALA LUMPUR',
            lat: 3.106,
            lng: 101.718,
            api: 90,
            dt: '2026-10-31T19:00:00',
          ),
        ],
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final c = JasIpuClient(dio);
    final stations = await c.stations();
    expect(stations, hasLength(2));
    final reading = await c.nearest(point: _kl, here: true);
    expect(reading, isNotNull);
    expect(reading!.stationName, contains('Cheras'));
    expect(reading.ipu, 90);
    expect(reading.band, AirBand.moderate);
    expect(reading.here, isTrue);
    expect(adapter.requests.single.uri.host, 'eqms.doe.gov.my');
  });

  test('alertAlong memilih stesen IPU tinggi berhampiran sampel', () async {
    final adapter = _FakeAdapter(
      (_) => {
        'api_table_hourly': [
          _row(
            id: 'GOOD',
            name: 'Baik',
            lat: 3.15,
            lng: 101.70,
            api: 40,
          ),
          _row(
            id: 'BAD',
            name: 'Jerebu',
            lat: 3.20,
            lng: 101.75,
            api: 150,
          ),
        ],
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final alert = await JasIpuClient(dio).alertAlong(
      samples: const [_kl, GeoPoint(3.18, 101.72)],
    );
    expect(alert?.id, 'BAD');
    expect(alert?.ipu, 150);
  });

  test('ralat rangkaian tanpa cache memberi senarai kosong', () async {
    final adapter = _FakeAdapter(
      (o) => DioException.connectionError(requestOptions: o, reason: 'off'),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    expect(await JasIpuClient(dio).stations(), isEmpty);
    expect(await JasIpuClient(dio).nearest(point: _kl), isNull);
  });
}
