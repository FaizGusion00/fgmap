import 'package:fgmap/features/music/domain/stream_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cleanStreamTitle', () {
    test('tajuk lagu biasa dikekalkan, ruang putih dipadatkan', () {
      expect(
        cleanStreamTitle('  Spring  -   Kugapai Cinta '),
        'Spring - Kugapai Cinta',
      );
    });

    test('kosong, pendek, pemisah sahaja dan URL dibuang', () {
      expect(cleanStreamTitle(null), isNull);
      expect(cleanStreamTitle(''), isNull);
      expect(cleanStreamTitle(' a '), isNull);
      expect(cleanStreamTitle(' - '), isNull);
      expect(cleanStreamTitle('| | |'), isNull);
      expect(cleanStreamTitle('https://hitz.fm'), isNull);
      expect(cleanStreamTitle('www.sinar.fm'), isNull);
    });

    test('mengulang nama stesen (iklan/celahan) dibuang tanpa kira huruf', () {
      expect(cleanStreamTitle('SINAR FM', station: 'Sinar FM'), isNull);
      expect(
        cleanStreamTitle('Sinar FM - Ziana Zain', station: 'Sinar FM'),
        'Sinar FM - Ziana Zain',
      );
    });
  });
}
