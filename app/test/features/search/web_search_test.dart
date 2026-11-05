import 'package:fgmap/features/search/presentation/web_search_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pelayar carian Google dalam app: hanya pautan peta yang ditekan diserahkan kepada FGMaps.
void main() {
  test('halaman Google biasa dimuat; pautan peta diserahkan', () {
    expect(
      decideWebNavigation('https://www.google.com/search?q=pavilion'),
      isA<LoadNav>(),
    );
    final d = decideWebNavigation(
      'https://www.google.com/maps/dir/?api=1&destination=3.1,101.7',
    );
    expect(d, isA<HandToMaps>());
    expect(
      decideWebNavigation('https://maps.app.goo.gl/AbC123'),
      isA<HandToMaps>(),
    );
  });

  test('intent:// app Google Maps diserahkan; skema lain disekat', () {
    final d = decideWebNavigation(
      'intent://maps.google.com/maps?daddr=3.1,101.7#Intent;scheme=https;package=com.google.android.apps.maps;end',
    );
    expect(d, isA<HandToMaps>());
    expect((d as HandToMaps).uri.host, 'maps.google.com');
    expect(
      decideWebNavigation('intent://play.google.com/x#Intent;end'),
      isA<BlockNav>(),
    );
    expect(decideWebNavigation('market://details?id=x'), isA<BlockNav>());
    expect(decideWebNavigation('tel:0123'), isA<BlockNav>());
  });

  test('URL carian ikut bahasa app, kawasan Malaysia', () {
    final u = googleSearchUrl('masjid negara', languageCode: 'ms');
    expect(u.host, 'www.google.com');
    expect(u.queryParameters, {'q': 'masjid negara', 'hl': 'ms', 'gl': 'my'});
    expect(
      googleSearchUrl('x', languageCode: 'en').queryParameters['hl'],
      'en',
    );
  });
}
