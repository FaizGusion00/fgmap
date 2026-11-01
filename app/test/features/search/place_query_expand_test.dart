import 'package:fgmap/features/search/domain/place_query_expand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('singkatan jalan dikembangkan', () {
    expect(expandPlaceQuery('jln ampang'), 'jalan ampang');
    expect(expandPlaceQuery('tmn melawati'), 'taman melawati');
  });

  test('landasan MY ditulis semula', () {
    expect(expandPlaceQuery('klcc'), 'Suria KLCC');
    expect(expandPlaceQuery('Pavilion KL'), 'Pavilion Kuala Lumpur');
    expect(expandPlaceQuery('uitm shah alam'), 'UiTM Shah Alam');
  });

  test('bukan landasan kekal huruf besar asal', () {
    expect(expandPlaceQuery('Lotus Puncak Alam'), 'Lotus Puncak Alam');
  });
}
