import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/domain/location_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sharedLocationFromUri', () {
    test('geo URI reads coordinates and a human-readable label', () {
      final shared = sharedLocationFromUri(
        Uri.parse('geo:0,0?q=3.142,101.686(Alam+Perdana)'),
      );

      expect(shared?.point, const GeoPoint(3.142, 101.686));
      expect(shared?.label, 'Alam Perdana');
    });

    test('Google Maps directions destination is parsed', () {
      final shared = sharedLocationFromUri(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=3.14%2C101.68',
        ),
      );

      expect(shared?.point, const GeoPoint(3.14, 101.68));
    });

    test('Google Maps place links use embedded coordinates and place name', () {
      final shared = sharedLocationFromUri(
        Uri.parse(
          'https://www.google.com/maps/place/Alam+Perdana/@3.14,101.68,17z',
        ),
      );

      expect(shared?.point, const GeoPoint(3.14, 101.68));
      expect(shared?.label, 'Alam Perdana');
    });

    test('Waze links read ll coordinates and search label', () {
      final shared = sharedLocationFromUri(
        Uri.parse('https://waze.com/ul?ll=3.14%2C101.68&q=Alam%20Perdana'),
      );

      expect(shared?.point, const GeoPoint(3.14, 101.68));
      expect(shared?.label, 'Alam Perdana');
    });

    test('Google navigation intent URIs are parsed', () {
      final shared = sharedLocationFromUri(
        Uri.parse('google.navigation:q=3.14,101.68'),
      );

      expect(shared?.point, const GeoPoint(3.14, 101.68));
    });

    test('Google Maps search path gives a place label', () {
      final shared = sharedLocationFromUri(
        Uri.parse('https://www.google.com/maps/search/Alam+Perdana'),
      );

      expect(shared?.label, 'Alam Perdana');
    });

    test('coordinates outside valid geographic bounds are rejected', () {
      expect(sharedLocationFromUri(Uri.parse('geo:0,0?q=95,200')), isNull);
    });

    test('unrelated URLs are ignored', () {
      expect(sharedLocationFromUri(Uri.parse('https://example.com')), isNull);
    });
  });
}
