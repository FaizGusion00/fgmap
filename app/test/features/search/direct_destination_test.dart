import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/domain/direct_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('placeFromDirectQuery', () {
    test('koordinat dipisah koma', () {
      final place = placeFromDirectQuery('3.1579, 101.7116')!;
      expect(place.point, const GeoPoint(3.1579, 101.7116));
      expect(place.category, 'coordinates');
    });

    test('koordinat dipisah titik bertindih / ruang', () {
      final place = placeFromDirectQuery('3.14 101.68')!;
      expect(place.point.lat, closeTo(3.14, 1e-9));
      expect(place.point.lng, closeTo(101.68, 1e-9));
    });

    test('pautan Google Maps place dengan @lat,lng', () {
      final place = placeFromDirectQuery(
        'https://www.google.com/maps/place/Alam+Perdana/@3.14,101.68,17z',
      )!;
      expect(place.point, const GeoPoint(3.14, 101.68));
      expect(place.name, 'Alam Perdana');
    });

    test('pautan Waze', () {
      final place = placeFromDirectQuery(
        'https://waze.com/ul?ll=3.14%2C101.68&q=Alam%20Perdana',
      )!;
      expect(place.point, const GeoPoint(3.14, 101.68));
      expect(place.name, 'Alam Perdana');
    });

    test('nama biasa: bukan destinasi terus', () {
      expect(placeFromDirectQuery('Lotus Puncak Alam'), isNull);
    });

    test('pautan search Google tanpa koordinat: label untuk carian OSM', () {
      expect(
        placeFromDirectQuery('https://www.google.com/maps/search/Alam+Perdana'),
        isNull,
      );
      expect(
        searchLabelFromMapLink(
          'https://www.google.com/maps/search/Alam+Perdana',
        ),
        'Alam Perdana',
      );
    });
  });

  group('looksLikeDirectDestination', () {
    test('koordinat dan pautan pendek', () {
      expect(looksLikeDirectDestination('3.1,101.7'), isTrue);
      expect(
        looksLikeDirectDestination('https://maps.app.goo.gl/abc123'),
        isTrue,
      );
      expect(looksLikeDirectDestination('maps.app.goo.gl/abc123'), isTrue);
      expect(looksLikeDirectDestination('petronas'), isFalse);
    });
  });
}
