import 'package:fgmap/core/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 26, 10, 30);

  group('GeolocatorLocationService.isFresh', () {
    test('fix baru diterima', () {
      expect(
        GeolocatorLocationService.isFresh(
          now.subtract(const Duration(seconds: 5)),
          now,
        ),
        isTrue,
      );
    });

    test('tepat pada had umur masih diterima', () {
      expect(
        GeolocatorLocationService.isFresh(
          now.subtract(GeolocatorLocationService.maxLastKnownAge),
          now,
        ),
        isTrue,
      );
    });

    test('fix lapuk ditolak (bukan titik mula laluan yang betul)', () {
      expect(
        GeolocatorLocationService.isFresh(
          now.subtract(const Duration(minutes: 3)),
          now,
        ),
        isFalse,
      );
      expect(
        GeolocatorLocationService.isFresh(
          now.subtract(const Duration(days: 30)),
          now,
        ),
        isFalse,
      );
    });
  });
}
