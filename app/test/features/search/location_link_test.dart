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

  group('pautan Google daripada carian dalam app', () {
    test('pin data=!3d!4d lebih tepat daripada @ (pusat peta)', () {
      final s = sharedLocationFromUri(
        Uri.parse(
          'https://www.google.com/maps/place/Pavilion+Kuala+Lumpur/@3.1488,101.7100,17z/data=!3m1!4b1!4m6!3m5!1s0x31cc37d12d669c1f:0x9e3afdd17c8a9056!8m2!3d3.1489!4d101.7131!16s%2Fm%2F02pxbxt',
        ),
      )!;
      expect(s.point, const GeoPoint(3.1489, 101.7131));
      expect(s.label, 'Pavilion Kuala Lumpur');
    });

    test('/maps/dir//NAMA/@… memberi nama destinasi', () {
      final s = sharedLocationFromUri(
        Uri.parse(
          'https://www.google.com.my/maps/dir//Masjid+Negara,+Jalan+Perdana,+Kuala+Lumpur/@3.1420,101.6917,17z/data=!4m8!4m7!1m0!1m5!1m1!1s0x31cc49!2m2!1d101.6917!2d3.1420',
        ),
      )!;
      expect(s.label, 'Masjid Negara, Jalan Perdana, Kuala Lumpur');
      expect(s.point, isNotNull);
    });

    test('butang Arah Google Search: "Nama, Alamat @lat,lng"', () {
      final s = sharedLocationFromUri(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=Zoo+Negara+Malaysia%2C+Kemensah+Heights%2C+68000+Ampang+Jaya%2C+Selangor+%403.210301%2C101.758821',
        ),
      )!;
      expect(s.point, const GeoPoint(3.210301, 101.758821));
      expect(
        s.label,
        'Zoo Negara Malaysia, Kemensah Heights, 68000 Ampang Jaya, Selangor',
      );
    });

    test(
      'butang Arah sebenar Google Search (maps.google.com daddr=…@lat,lng)',
      () {
        final s = sharedLocationFromUri(
          Uri.parse(
            'https://maps.google.com/maps?hl=en&gl=my&um=1&ie=UTF-8&fb=1&entry=s&sa=X&geocode=KeEfgwq2OcwxMS972wLHAMjy&daddr=Kemensah+Heights,+68000+Ampang+Jaya,+Selangor+@3.210301,101.758821',
          ),
        )!;
        expect(s.point, const GeoPoint(3.210301, 101.758821));
        expect(s.label, 'Kemensah Heights, 68000 Ampang Jaya, Selangor');
      },
    );

    test('butang Arah: destination tanpa koordinat = nama untuk dicari', () {
      final s = sharedLocationFromUri(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=Masjid+Wilayah+Persekutuan&destination_place_id=ChIJ',
        ),
      )!;
      expect(s.point, isNull);
      expect(s.label, 'Masjid Wilayah Persekutuan');
    });

    test('intent:// app Google Maps ditukar kepada pautan yang boleh dibaca', () {
      final fromFallback = mapLinkFromIntent(
        'intent://maps.google.com/maps?daddr=3.1579,101.7117#Intent;scheme=https;package=com.google.android.apps.maps;S.browser_fallback_url=https%3A%2F%2Fmaps.google.com%2Fmaps%3Fdaddr%3D3.1579%2C101.7117;end',
      )!;
      expect(
        sharedLocationFromUri(fromFallback)!.point,
        const GeoPoint(3.1579, 101.7117),
      );
      final rebuilt = mapLinkFromIntent(
        'intent://maps.google.com/maps?daddr=3.1,101.6#Intent;scheme=https;package=com.google.android.apps.maps;end',
      )!;
      expect(sharedLocationFromUri(rebuilt)!.point, const GeoPoint(3.1, 101.6));
      expect(mapLinkFromIntent('intent://example.com/x#Intent;end'), isNull);
      expect(mapLinkFromIntent('https://maps.google.com'), isNull);
    });

    test(
      'pelayar: hanya pautan peta diserahkan ke FGMaps, carian biasa kekal',
      () {
        bool handoff(String u) => isMapHandoffUrl(Uri.parse(u));
        expect(handoff('https://www.google.com/search?q=pavilion+kl'), isFalse);
        expect(handoff('https://www.google.com.my/search?q=masjid'), isFalse);
        expect(
          handoff('https://www.google.com/maps/dir/?api=1&destination=x'),
          isTrue,
        );
        expect(
          handoff('https://www.google.com.my/maps/place/X/@3,101,17z'),
          isTrue,
        );
        expect(handoff('https://maps.google.com/maps?daddr=3,101'), isTrue);
        expect(handoff('https://maps.app.goo.gl/abc123'), isTrue);
        expect(handoff('geo:3.1,101.6'), isTrue);
        expect(handoff('https://www.youtube.com/watch?v=1'), isFalse);
      },
    );
  });

  group('pin tepat untuk carian Google (bukan pusat paparan)', () {
    test('halaman arah: titik destinasi terakhir !1d<lng>!2d<lat>', () {
      final u = Uri.parse(
        'https://www.google.com/maps/dir//Zoo+Negara+Malaysia/@3.2105,101.7380,13z/data=!4m8!4m7!1m0!1m5!1m1!1s0x31cc3a9:0x9b!2m2!1d101.758821!2d3.210301',
      );
      expect(mapPinFromUri(u), const GeoPoint(3.210301, 101.758821));
      expect(
        sharedLocationFromUri(u)!.point,
        const GeoPoint(3.210301, 101.758821),
      );
    });

    test('hanya @pusat paparan atau nama: tiada pin (perlu diselesaikan)', () {
      expect(
        mapPinFromUri(
          Uri.parse(
            'https://www.google.com/maps/dir//Zoo+Negara/@3.21,101.73,13z',
          ),
        ),
        isNull,
      );
      expect(
        mapPinFromUri(
          Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=Zoo+Negara',
          ),
        ),
        isNull,
      );
      expect(mapPinFromUri(Uri.parse('https://maps.app.goo.gl/AbC')), isNull);
    });

    test('pin daripada place !3d!4d dan daddr "Nama @lat,lng"', () {
      expect(
        mapPinFromUri(
          Uri.parse(
            'https://www.google.com/maps/place/X/@3.1,101.7,17z/data=!3m1!4b1!8m2!3d3.1489!4d101.7131',
          ),
        ),
        const GeoPoint(3.1489, 101.7131),
      );
      expect(
        mapPinFromUri(
          Uri.parse(
            'https://maps.google.com/maps?daddr=Kemensah+Heights+@3.210301,101.758821',
          ),
        ),
        const GeoPoint(3.210301, 101.758821),
      );
    });
  });

  group('alamat bernombor bukan koordinat', () {
    test('daddr "2, 4 & 6, Jalan SS 21/39" tiada pin palsu (2,4)', () {
      final u = Uri.parse(
        'https://maps.google.com/maps?daddr=2,+4+%26+6,+Jalan+SS+21%2F39,+Petaling+Jaya',
      );
      expect(mapPinFromUri(u), isNull);
      final s = sharedLocationFromUri(u)!;
      expect(s.point, isNull);
      expect(s.label, '2, 4 & 6, Jalan SS 21/39, Petaling Jaya');
    });

    test(
      'koordinat sah dengan label, altitud dan parameter geo kekal dibaca',
      () {
        expect(
          sharedLocationFromUri(Uri.parse('geo:3.1,101.7,20;u=35'))!.point,
          const GeoPoint(3.1, 101.7),
        );
        final named = sharedLocationFromUri(
          Uri.parse('https://maps.google.com/maps?q=3.1,101.7(Masjid+Negara)'),
        )!;
        expect(named.point, const GeoPoint(3.1, 101.7));
        expect(named.label, 'Masjid Negara');
      },
    );

    test('/maps/dir/<dari>/<lat,lng>/@… memberi pin destinasi', () {
      expect(
        mapPinFromUri(
          Uri.parse(
            'https://www.google.com/maps/dir/3.1,101.6/3.2,101.7/@3.15,101.65,12z',
          ),
        ),
        const GeoPoint(3.2, 101.7),
      );
    });
  });
}
