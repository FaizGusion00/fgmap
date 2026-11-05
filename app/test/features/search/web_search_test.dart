import 'package:fgmap/features/search/domain/location_link.dart';
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

  test(
    '"Open in Maps" tanpa koordinat + pin kad Google: terus pin, nama dikekalkan',
    () {
      final original = Uri.parse(
        'https://maps.google.com/maps?hl=en&gl=my&um=1&ie=UTF-8&fb=1&entry=s&sa=X'
        '&ftid=0x31cc37d39d319733:0x68a27ec3fd8f6bed&q=Aquaria+KLCC&ictx=111',
      );
      expect(mapPinFromUri(original), isNull);
      final u = withGooglePin(original, '3.153698,101.713405')!;
      final pin = mapPinFromUri(u)!;
      expect(pin.lat, closeTo(3.153698, 1e-9));
      expect(pin.lng, closeTo(101.713405, 1e-9));
      expect(sharedLocationFromUri(u)?.label, 'Aquaria KLCC');
    },
  );

  test('pin halaman tidak sah ditolak', () {
    final o = Uri.parse('https://maps.google.com/maps?q=X');
    expect(withGooglePin(o, ''), isNull);
    expect(withGooglePin(o, '0,0'), isNull);
    expect(withGooglePin(o, '95.1,101.7'), isNull);
    expect(withGooglePin(o, 'abc'), isNull);
    expect(mapPinFromUri(withGooglePin(o, '-6.2,106.8')!)!.lat, -6.2);
  });

  test('pautan alamat tanpa nama: nama daripada carian Google semasa', () {
    final o = Uri.parse(
      'https://maps.google.com/maps?hl=en&ftid=0x31cc37d39d319733:0x68a27ec3fd8f6bed',
    );
    final u = withGooglePin(
      o,
      '3.1535483,101.713178',
      fallbackLabel: 'Aquaria KLCC',
    )!;
    expect(sharedLocationFromUri(u)?.label, 'Aquaria KLCC');
    expect(mapPinFromUri(u)!.lng, closeTo(101.713178, 1e-9));
    final bare = withGooglePin(o, '3.1535483,101.713178')!;
    expect(mapPinFromUri(bare)!.lat, closeTo(3.1535483, 1e-9));
  });
}
