import 'package:fgmap/features/local_assistant/domain/intent_router.dart';
import 'package:fgmap/features/route_preview/domain/route_preference.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RouteIntent route(String text, {bool hasRoute = false}) {
    final intent = parseIntent(text, hasRoute: hasRoute);
    expect(intent, isA<RouteIntent>(), reason: text);
    return intent! as RouteIntent;
  }

  group('laluan', () {
    test('BI dan BM: destinasi bersih', () {
      expect(route('Route to KLCC').destination, 'klcc');
      expect(
        route('route to Kuala Terengganu').destination,
        'kuala terengganu',
      );
      expect(route('Bawa saya ke Masjid Putra').destination, 'masjid putra');
      expect(route('nak pergi ipoh').destination, 'ipoh');
      expect(route('jalan ke Pavilion KL sekarang').destination, 'pavilion kl');
    });

    test('destinasi baharu tidak mewarisi yang lama', () {
      expect(route('Route to KLCC').destination, 'klcc');
      expect(
        route('route to kuala terengganu', hasRoute: true).destination,
        'kuala terengganu',
      );
    });

    test('pilihan laluan dikesan dan dibuang daripada nama', () {
      final a = route('Route to Penang without tolls');
      expect(a.destination, 'penang');
      expect(a.preference, RoutePreference.noTolls);
      final b = route('laluan ke johor bahru paling selamat');
      expect(b.destination, 'johor bahru');
      expect(b.preference, RoutePreference.safest);
      final c = route('route to melaka fastest');
      expect(c.preference, RoutePreference.fastest);
      expect(
        route('ke seremban tanpa tol').preference,
        RoutePreference.noTolls,
      );
    });

    test('navigate / bawa saya / "start now" bermula terus', () {
      expect(route('navigate to KLIA').autoStart, isTrue);
      expect(route('bawa saya ke KLIA').autoStart, isTrue);
      expect(route('route to klia and start').autoStart, isTrue);
      expect(route('route to KLIA, start now').destination, 'klia');
      expect(route('Route to KLIA').autoStart, isFalse);
    });

    test('dari lokasi semasa dibuang', () {
      expect(
        route('route to klcc from my current location').destination,
        'klcc',
      );
    });
  });

  group('mula / pilihan semasa', () {
    test(
      'ayat pengguna sebenar: "start point is current position. start now"',
      () {
        expect(
          parseIntent(
            'start point is current position. start now',
            hasRoute: true,
          ),
          isA<StartNavigationIntent>(),
        );
      },
    );

    test('perkataan pendek hanya bermakna bila laluan ada', () {
      expect(parseIntent('ok', hasRoute: true), isA<StartNavigationIntent>());
      expect(parseIntent('jom', hasRoute: true), isA<StartNavigationIntent>());
      expect(parseIntent('ok'), isNull);
    });

    test('"tanpa tol" pada laluan semasa', () {
      final i = parseIntent('tanpa tol', hasRoute: true);
      expect(i, isA<RoutePreferenceIntent>());
      expect((i! as RoutePreferenceIntent).preference, RoutePreference.noTolls);
      final s = parseIntent('take the safest route', hasRoute: true);
      expect((s! as RoutePreferenceIntent).preference, RoutePreference.safest);
    });

    test('batal laluan', () {
      expect(
        parseIntent('cancel route', hasRoute: true),
        isA<CancelRouteIntent>(),
      );
    });
  });

  group('lain-lain', () {
    test('tempat terdekat', () {
      final i = parseIntent('Nearest petrol station');
      expect((i! as NearbyIntent).category, NearbyCategory.fuel);
      expect(
        (parseIntent('surau terdekat')! as NearbyIntent).category,
        NearbyCategory.mosque,
      );
    });

    test('sepanjang laluan', () {
      expect(
        (parseIntent('EV charging along the route')! as AlongRouteIntent)
            .category,
        'ev',
      );
      expect(
        (parseIntent('R&R sepanjang laluan')! as AlongRouteIntent).category,
        'rest_area',
      );
    });

    test('cuaca dengan dan tanpa tempat', () {
      expect((parseIntent('weather in Ipoh')! as WeatherIntent).place, 'ipoh');
      expect(
        (parseIntent('cuaca di kuala terengganu hari ini')! as WeatherIntent)
            .place,
        'kuala terengganu',
      );
      expect((parseIntent('cuaca sekarang')! as WeatherIntent).place, isNull);
    });

    test('kiblat, waktu solat, IPU, muzik', () {
      expect(parseIntent('arah kiblat'), isA<QiblaIntent>());
      expect(parseIntent('waktu solat hari ini'), isA<PrayerTimesIntent>());
      expect(parseIntent('IPU near me'), isA<AirQualityIntent>());
      expect((parseIntent('play radio Era')! as PlayRadioIntent).query, 'era');
      expect(
        (parseIntent('mainkan lagu Siti Nurhaliza')! as PlayMusicIntent).query,
        'siti nurhaliza',
      );
    });

    test('carian', () {
      expect((parseIntent('cari Pavilion')! as SearchIntent).query, 'pavilion');
    });

    test('lokasi semasa guna GPS, bukan carian nama tempat', () {
      expect(
        parseIntent('Search my current location'),
        isA<CurrentLocationIntent>(),
      );
      expect(parseIntent('where am I'), isA<CurrentLocationIntent>());
      expect(parseIntent('lokasi saya'), isA<CurrentLocationIntent>());
      expect(parseIntent('cari lokasi semasa'), isA<CurrentLocationIntent>());
      expect(parseIntent('my current location'), isA<CurrentLocationIntent>());
    });

    test('soalan ciri / offline FAQ tidak pergi ke model', () {
      expect(
        parseIntent('What can i ask you using your ofline features?'),
        isA<CapabilitiesIntent>(),
      );
      expect(
        (parseIntent('What can i ask you using your ofline features?')!
                as CapabilitiesIntent)
            .offlineFocused,
        isTrue,
      );
      expect(parseIntent('what can you do'), isA<CapabilitiesIntent>());
      expect(parseIntent('help'), isA<CapabilitiesIntent>());
    });

    test('soalan umum pergi ke model', () {
      expect(parseIntent('Explain tolls in Malaysia'), isNull);
      expect(parseIntent('apa itu sabar?'), isNull);
      expect(parseIntent('what is the best way to learn english'), isNull);
    });
  });

  test('bahasa mesej', () {
    expect(looksMalay('bawa saya ke klcc'), isTrue);
    expect(looksMalay('route to klcc'), isFalse);
    expect(looksEnglish('route to klcc'), isTrue);
  });
}
