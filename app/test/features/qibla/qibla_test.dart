import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/qibla/domain/qibla.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kiblat dari KL mengarah barat laut (~292°)', () {
    const kl = GeoPoint(3.139, 101.687);
    final b = qiblaBearingDegrees(kl);
    expect(b, inInclusiveRange(280, 300));
    expect(qiblaDistanceKm(kl), greaterThan(6000));
    expect(qiblaDistanceKm(kl), lessThan(8000));
  });

  test('sudut relatif kepada heading', () {
    const kl = GeoPoint(3.139, 101.687);
    final q = qiblaBearingDegrees(kl);
    expect(qiblaRelativeDegrees(kl, q), closeTo(0, 0.01));
    expect(qiblaRelativeDegrees(kl, null), isNull);
    final rel = qiblaRelativeDegrees(kl, (q + 90) % 360)!;
    expect(rel, closeTo(270, 0.5));
  });

  test('normalizeDeltaDegrees', () {
    expect(normalizeDeltaDegrees(370), closeTo(10, 1e-9));
    expect(normalizeDeltaDegrees(-190), closeTo(170, 1e-9));
  });
}
