import 'package:fgmap/features/along_route/domain/along_route_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kategori EV menggunakan charging_station OSM', () {
    final q = AlongRouteCategory.evCharging.overpassQuery(const [
      (3.15, 101.70),
    ]);
    expect(q, contains('charging_station'));
    // Jejari koridor 600 m + margin 120 m kerana garis pertanyaan dipermudah memotong selekoh.
    expect(q, contains('around:720'));
    expect(AlongRouteCategory.evCharging.sampleEveryM, 800);
  });

  test('semua kategori ada selector Overpass', () {
    for (final c in AlongRouteCategory.values) {
      expect(c.selectors, isNotEmpty);
      expect(c.overpassQuery(const [(3.0, 101.0)]), startsWith('[out:json]'));
    }
  });
}
