import 'package:fgmap/core/utils/geo.dart';
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

  group('serahan diseragamkan (nama terbaik, pin Google)', () {
    test('Arah: alamat daddr diganti carian Google', () {
      final u = normalizeGoogleHandoff(
        Uri.parse(
          'https://maps.google.com/maps?daddr=168,+Jln+Bukit+Bintang,+55100+Kuala+Lumpur+@3.149106,101.712924',
        ),
        serpQuery: 'Pavilion KL',
      );
      final s = sharedLocationFromUri(u)!;
      expect(s.label, 'Pavilion KL');
      expect(s.point, const GeoPoint(3.149106, 101.712924));
    });

    test('nama tempat dalam pautan diutamakan berbanding carian', () {
      final u = normalizeGoogleHandoff(
        Uri.parse(
          'https://www.google.com/maps/place/Aquaria+KLCC/@3.15,101.71,17z/data=!3d3.1535!4d101.7131',
        ),
        serpQuery: 'aqua klcc',
      );
      expect(sharedLocationFromUri(u)!.label, 'Aquaria KLCC');
      expect(mapPinFromUri(u), const GeoPoint(3.1535, 101.7131));
    });

    test('geo: dan pautan tanpa pin tidak diubah', () {
      final g = Uri.parse('geo:3.1,101.7');
      expect(normalizeGoogleHandoff(g), g);
      final q = Uri.parse('https://maps.google.com/maps?q=Zoo+Negara');
      expect(normalizeGoogleHandoff(q), q);
    });

    test('hos Google sahaja boleh menyerahkan pautan', () {
      expect(isGoogleHost('www.google.com'), isTrue);
      expect(isGoogleHost('www.google.com.my'), isTrue);
      expect(isGoogleHost('maps.google.com'), isTrue);
      expect(isGoogleHost('google.evil.com'), isFalse);
      expect(isGoogleHost('notgoogle.com'), isFalse);
      expect(isGoogleHost('example.com'), isFalse);
    });
  });
}
