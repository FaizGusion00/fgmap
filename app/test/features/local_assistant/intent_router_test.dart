import 'package:fgmap/features/local_assistant/data/wikipedia_client.dart';
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
      // Topik satu perkataan: Wikipedia dahulu, model sebagai sandaran.
      expect(parseIntent('apa itu sabar?'), isA<TopicIntent>());
      expect(parseIntent('what is the best way to learn english'), isNull);
    });
  });

  test('bahasa mesej', () {
    expect(looksMalay('bawa saya ke klcc'), isTrue);
    expect(looksMalay('route to klcc'), isFalse);
    expect(looksEnglish('route to klcc'), isTrue);
  });

  group('perbualan (templat, bukan model)', () {
    ChatKind? kind(String t) => switch (parseIntent(t, hasRoute: true)) {
      ChatIntent(:final kind) => kind,
      _ => null,
    };

    test('identiti: BI dan BM, termasuk bercampur salam', () {
      for (final t in [
        'Hi who are you?',
        'who r u',
        "What's your name?",
        'who made you',
        'Who developed this app?',
        'siapa awak',
        'Awak ni siapa?',
        'apa nama kamu',
        'siapa buat app ni',
        'perkenalkan diri',
      ]) {
        expect(kind(t), ChatKind.identity, reason: t);
      }
    });

    test('salam, terima kasih dan "boleh jawab tak"', () {
      for (final t in [
        'hi',
        'Hello!',
        'Assalamualaikum',
        'selamat pagi',
        'hai FG AI',
      ]) {
        expect(kind(t), ChatKind.greeting, reason: t);
      }
      for (final t in ['thanks', 'Thank you so much', 'terima kasih', 'tq']) {
        expect(kind(t), ChatKind.thanks, reason: t);
      }
      for (final t in [
        'Can you answer me?',
        'are you there',
        'boleh jawab tak',
        'kenapa tak jawab',
        'ada tak?',
      ]) {
        expect(kind(t), ChatKind.ping, reason: t);
      }
    });

    test('bukan perbualan: soalan umum dan arahan tetap ke laluan biasa', () {
      expect(kind('who is the prime minister of Malaysia'), isNull);
      expect(kind('siapa perdana menteri malaysia'), isNull);
      expect(kind('hi, route to Ipoh'), isNull);
      expect(kind('hello world program in python'), isNull);
      expect(parseIntent('route to Kuala Kedah'), isA<RouteIntent>());
    });
  });

  group('topik ensiklopedia (Wikipedia, model sebagai sandaran)', () {
    String? topic(String t) => switch (parseIntent(t)) {
      TopicIntent(:final topic) => topic,
      _ => null,
    };

    test('pelbagai cara bertanya tentang topik', () {
      expect(topic('So well wanna ask you about Palestine'), 'palestine');
      expect(topic('Can you tell me the idea about love'), 'love');
      expect(topic('Who is Albert Einstein'), 'albert einstein');
      expect(topic('what is a durian?'), 'durian');
      expect(topic('apa itu durian'), 'durian');
      expect(
        topic('siapa perdana menteri malaysia'),
        'perdana menteri malaysia',
      );
      expect(topic('cerita pasal sejarah Melaka sikit'), 'sejarah melaka');
    });

    test('bukan topik: diri, masa, perjalanan, identiti', () {
      expect(topic('what is the time'), isNull);
      expect(topic('tell me about yourself'), isNull);
      expect(topic('tell me about the route'), isNull);
      expect(parseIntent('who are you'), isA<ChatIntent>());
      expect(parseIntent('weather in Kuantan'), isA<WeatherIntent>());
    });
  });

  group('lokasi, muzik umum dan Wikipedia', () {
    test('pelbagai cara bertanya lokasi semasa', () {
      for (final t in [
        'Where am i now',
        'where am I right now?',
        'where are we',
        'saya kat mana sekarang',
        'kat mana saya',
        'lokasi saya sekarang',
        'aku dekat mana ni',
      ]) {
        expect(parseIntent(t), isA<CurrentLocationIntent>(), reason: t);
      }
    });

    test('"play a music" = lagu popular (tiada carian "a music")', () {
      for (final t in [
        'Play a music',
        'play music',
        'play a song',
        'mainkan lagu',
        'pasang muzik',
      ]) {
        final i = parseIntent(t);
        expect(i, isA<PlayMusicIntent>(), reason: t);
        expect((i! as PlayMusicIntent).query, '', reason: t);
      }
      expect(
        (parseIntent('play Siti Nurhaliza')! as PlayMusicIntent).query,
        'siti nurhaliza',
      );
    });

    test('tajuk Wikipedia paling hampir dipilih', () {
      expect(
        bestTitleMatch('palestin', [
          (key: 'Ira_J._Palestin', title: 'Ira J. Palestin'),
          (key: 'Palestine', title: 'Palestine'),
          (key: 'Palestinians', title: 'Palestinians'),
        ]),
        'Palestine',
      );
    });
  });
}
