import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/cameras/data/osm_camera_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  test('respons Overpass diterjemah kepada kamera (badan respons, bukan objek '
      'Response)', () async {
    final adapter = StubAdapter(
      (_) => StubAdapter.json({
        'elements': [
          {
            'type': 'node',
            'id': 7,
            'lat': 3.1,
            'lon': 101.5,
            'tags': {'name': 'Kamera Persekutuan'},
          },
          {'type': 'node', 'id': 8, 'lat': 3.2, 'lon': 101.6},
        ],
      }),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final cams = await OsmCameraSearch(dio, const [
      'https://o.test/api',
    ]).searchAlong(const [GeoPoint(3.0, 101.4), GeoPoint(3.3, 101.7)]);
    expect(cams.map((c) => c.id), ['osm-7', 'osm-8']);
    expect(cams.first.name, 'Kamera Persekutuan');
    expect(cams.last.name, 'Kamera kelajuan');
  });

  test(
    'tag direction/maxspeed/enforcement dan bound dalam nama dibaca',
    () async {
      final adapter = StubAdapter(
        (_) => StubAdapter.json({
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 2.158,
              'lon': 102.659,
              'tags': {
                'name': 'AWAS Pagoh - Northbound',
                'direction': '305',
                'maxspeed': '110',
              },
            },
            {
              'type': 'node',
              'id': 2,
              'lat': 2.28,
              'lon': 102.41,
              // Darjah bercanggah dengan (NB) -> dibuang, bound kekal.
              'tags': {'name': 'KM 184.2 Jasin (NB)', 'direction': '90'},
            },
            {
              'type': 'node',
              'id': 3,
              'lat': 3.17,
              'lon': 101.68,
              'tags': {'enforcement': 'traffic_signals', 'direction': 'both'},
            },
          ],
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final cams = await OsmCameraSearch(dio, const [
        'https://o.test/api',
      ]).searchAlong(const [GeoPoint(2.0, 101.4), GeoPoint(3.3, 102.7)]);
      expect(cams, hasLength(3));
      expect(cams[0].bound, 'NB');
      expect(cams[0].directionDegrees, 305);
      expect(cams[0].maxSpeedKmh, 110);
      expect(cams[1].bound, 'NB');
      expect(cams[1].directionDegrees, isNull);
      expect(cams[2].type, 'red_light');
      expect(cams[2].name, 'Kamera lampu isyarat');
      expect(cams[2].directionDegrees, isNull);
    },
  );
}
