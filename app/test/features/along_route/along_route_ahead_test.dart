import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/along_route/domain/along_route_ahead.dart';
import 'package:fgmap/features/along_route/domain/along_route_category.dart';
import 'package:fgmap/features/along_route/domain/along_route_poi.dart';
import 'package:flutter_test/flutter_test.dart';

AlongRoutePoi _poi(String id, double alongM, {AlongRouteCategory? cat}) =>
    AlongRoutePoi(
      id: id,
      category: cat ?? AlongRouteCategory.restArea,
      name: id,
      point: const GeoPoint(0, 0),
      alongM: alongM,
      crossTrackM: 10,
    );

void main() {
  test('memilih POI paling hampir di hadapan dalam julat', () {
    final next = nextAlongPoiAhead(
      pois: [_poi('jauh', 9000), _poi('dekat', 3000), _poi('belakang', 100)],
      alongNow: 500,
    );
    expect(next?.id, 'dekat');
  });

  test('abaikan di belakang, terlalu dekat, atau di luar withinM', () {
    expect(
      nextAlongPoiAhead(pois: [_poi('a', 520)], alongNow: 500, minAheadM: 80),
      isNull,
    );
    expect(
      nextAlongPoiAhead(pois: [_poi('b', 9000)], alongNow: 0, withinM: 8000),
      isNull,
    );
  });

  test('senarai kosong memberi null', () {
    expect(nextAlongPoiAhead(pois: const [], alongNow: 0), isNull);
  });
}
