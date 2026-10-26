import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

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

    test('fix lebih lama daripada had sepuluh saat ditolak', () {
      expect(
        GeolocatorLocationService.isFresh(
          now.subtract(const Duration(seconds: 11)),
          now,
        ),
        isFalse,
      );
    });

    test('fix lapuk ditolak (bukan titik mula laluan yang betul)', () {
      expect(
        GeolocatorLocationService.isFresh(
          now.subtract(const Duration(seconds: 31)),
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

    test('cap masa masa depan ditolak', () {
      expect(
        GeolocatorLocationService.isFresh(
          now.add(const Duration(seconds: 1)),
          now,
        ),
        isFalse,
      );
    });
  });

  group('GeolocatorLocationService.isUsableFix', () {
    LocationFix fix({
      GeoPoint point = const GeoPoint(3, 101),
      double? accuracyMeters = 8,
      DateTime? timestamp,
    }) => LocationFix(
      point: point,
      accuracyMeters: accuracyMeters,
      timestamp: timestamp ?? now.subtract(const Duration(seconds: 1)),
    );

    test('menerima fix semasa dalam had ketepatan', () {
      expect(GeolocatorLocationService.isUsableFix(fix(), now), isTrue);
    });

    test('menolak fix yang terlalu samar untuk titik mula laluan', () {
      expect(
        GeolocatorLocationService.isUsableFix(fix(accuracyMeters: 31), now),
        isFalse,
      );
    });

    test('menolak fix tanpa ketepatan atau cap masa', () {
      expect(
        GeolocatorLocationService.isUsableFix(
          const LocationFix(point: GeoPoint(3, 101)),
          now,
        ),
        isFalse,
      );
    });

    test('menolak koordinat di luar julat', () {
      expect(
        GeolocatorLocationService.isUsableFix(
          fix(point: const GeoPoint(91, 101)),
          now,
        ),
        isFalse,
      );
    });
  });

  group('GeolocatorLocationService.trackingSettings', () {
    test('Android: ketepatan tinggi, tanpa notifikasi latar depan', () {
      final settings = GeolocatorLocationService.trackingSettings(
        TargetPlatform.android,
      );
      expect(settings, isA<AndroidSettings>());
      expect(
        (settings as AndroidSettings).foregroundNotificationConfig,
        isNull,
      );
      expect(settings.distanceFilter, lessThanOrEqualTo(10));
      expect(settings.accuracy, LocationAccuracy.high);
    });

    test('iOS: tiada kemas kini latar belakang untuk peta idle', () {
      final settings = GeolocatorLocationService.trackingSettings(
        TargetPlatform.iOS,
      );
      expect(settings, isA<AppleSettings>());
      expect(
        (settings as AppleSettings).allowBackgroundLocationUpdates,
        isFalse,
      );
    });

    test(
      'navigasi kekal berketepatan tertinggi dan hidup di latar belakang',
      () {
        final nav = GeolocatorLocationService.navigationSettings(
          TargetPlatform.android,
        );
        expect(nav.accuracy, LocationAccuracy.bestForNavigation);
        expect(
          (nav as AndroidSettings).foregroundNotificationConfig,
          isNotNull,
        );
      },
    );
  });
}
