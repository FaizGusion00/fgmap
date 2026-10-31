import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/air_quality/domain/air_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ambang amaran jerebu ialah Tidak sihat (101)', () {
    expect(ipuAlertThreshold, 101);
    expect(airBandFor(100), AirBand.moderate);
    expect(airBandFor(101), AirBand.unhealthy);
  });

  test('AirReading.gauge saturates at 300; usAqi alias = ipu', () {
    final r = AirReading(
      ipu: 450,
      point: const GeoPoint(3, 101),
      fetchedAt: DateTime(2026),
      stationName: 'x',
      stationDistanceM: 0,
    );
    expect(r.gauge, 1.0);
    expect(r.usAqi, 450);
    expect(r.band, AirBand.hazardous);
  });
}
