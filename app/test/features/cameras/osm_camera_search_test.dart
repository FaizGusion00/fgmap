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
    expect(cams.last.name, 'Kamera OSM');
  });
}
