import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fgmap/core/utils/geo.dart';

void main() {
  group('decodePolyline', () {
    test('contoh rasmi Google (ketepatan 5)', () {
      // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
      final points = decodePolyline(
        '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
        precision: 5,
      );
      expect(points, [
        const GeoPoint(38.5, -120.2),
        const GeoPoint(40.7, -120.95),
        const GeoPoint(43.252, -126.453),
      ]);
    });

    test('rentetan kosong menghasilkan senarai kosong', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('geometri sebenar Valhalla KLCC -> KLIA (ketepatan 6)', () {
      final fixture =
          jsonDecode(
                File('test/fixtures/klcc_klia_shape.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final points = decodePolyline(fixture['shape'] as String);

      // Bilangan titik mesti sepadan dengan indeks shape terakhir manuver (end_shape_index + 1).
      expect(points.length, (fixture['end_shape_index'] as int) + 1);

      // Permulaan berhampiran KLCC dan penghujung berhampiran KLIA (dalam ~1 km).
      expect(points.first.lat, closeTo(3.1579, 0.01));
      expect(points.first.lng, closeTo(101.7116, 0.01));
      expect(points.last.lat, closeTo(2.7456, 0.01));
      expect(points.last.lng, closeTo(101.7072, 0.01));

      // Semua titik berada dalam Malaysia (kotak kasar) dan tiada lompatan melebihi 2 km antara titik.
      for (final p in points) {
        expect(p.lat, inInclusiveRange(1, 7));
        expect(p.lng, inInclusiveRange(99, 120));
      }
      for (var i = 1; i < points.length; i++) {
        final dLat = (points[i].lat - points[i - 1].lat).abs();
        final dLng = (points[i].lng - points[i - 1].lng).abs();
        expect(dLat, lessThan(0.02), reason: 'lompatan lat pada titik $i');
        expect(dLng, lessThan(0.02), reason: 'lompatan lng pada titik $i');
      }
    });

    test('input terpotong melempar FormatException', () {
      // Potong separuh nilai terakhir: bit sambungan (>= 0x20) masih menyala tetapi data habis.
      expect(() => decodePolyline('_p~iF~ps|U_'), throwsFormatException);
    });

    test('aksara di luar julat melempar FormatException', () {
      expect(() => decodePolyline('abc def'), throwsFormatException);
    });
  });
}
