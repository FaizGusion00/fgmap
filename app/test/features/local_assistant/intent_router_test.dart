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
      // Tanpa laluan, "ok" ialah pengesahan ringkas (templat), bukan arahan mula dan bukan soalan untuk model.
      expect(parseIntent('ok'), isA<ChatIntent>());
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

    test('permintaan topik jelas dan nama khas -> Wikipedia', () {
      expect(topic('So well wanna ask you about Palestine'), 'palestine');
      expect(topic('Can you tell me the idea about love'), 'love');
      expect(topic('cerita pasal sejarah Melaka sikit'), 'sejarah melaka');
      expect(topic('Who is Albert Einstein'), 'albert einstein');
      expect(topic('apa itu Proton Saga'), 'proton saga');
      expect(topic('siapa Tunku Abdul Rahman'), 'tunku abdul rahman');
    });

    test('soalan bebas huruf kecil -> model (jawab soalan, bukan rencana)', () {
      expect(topic('what is a durian?'), isNull);
      expect(topic('apa itu sabar'), isNull);
      expect(topic('siapa perdana menteri malaysia'), isNull);
      expect(topic('what is the capital of france'), isNull);
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

    test('"play a music" tanya lagu, bukan carian "a music"', () {
      for (final t in [
        'Play a music',
        'play music',
        'play a song',
        'mainkan lagu',
        'pasang muzik',
      ]) {
        final i = parseIntent(t);
        expect(i, isA<AskSlotIntent>(), reason: t);
        expect((i! as AskSlotIntent).slot, AskSlot.musicQuery, reason: t);
      }
      expect((parseIntent('play something')! as PlayMusicIntent).query, '');
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

  group('ayat bersahaja daripada ujian telefon pemilik', () {
    test('lokasi semasa dengan pembungkus sopan (bukan gema model)', () {
      for (final t in [
        'Can you tell me where are my current location?',
        'Please tell me my current location',
        'can you please tell me my current location',
        'could you tell me where i am',
        'tell me my location',
        'whats my location now',
        'where are my current location',
        'tolong beritahu lokasi saya',
        'saya kat mana sekarang',
        'kat mana saya ni',
      ]) {
        expect(parseIntent(t), isA<CurrentLocationIntent>(), reason: t);
      }
    });

    test('"im heading to X can you tell me how" -> destinasi bersih', () {
      for (final t in [
        'Im heading to masjid attaufiqiah can you tell me how?',
        'Im heading to masjid attaufiqiah, how do i do that?',
        'im going to masjid attaufiqiah can you show me the way',
        'I want to go to Masjid At-Taufiqiah please tell me how',
        'saya nak pergi ke masjid attaufiqiah macam mana',
      ]) {
        final r = parseIntent(t);
        expect(r, isA<RouteIntent>(), reason: t);
        expect(
          (r! as RouteIntent).destination,
          anyOf('masjid attaufiqiah', 'masjid at-taufiqiah'),
          reason: t,
        );
      }
    });

    test('tail soalan tidak memakan nama destinasi lain', () {
      expect(
        (parseIntent('navigate to Pavilion KL can you start now')!
                as RouteIntent)
            .destination,
        'pavilion kl',
      );
      expect(
        (parseIntent('can you take me to klcc?')! as RouteIntent).destination,
        'klcc',
      );
    });

    test('susulan tanpa destinasi ("how do i do that")', () {
      for (final t in [
        'how do i do that?',
        'how do i get there',
        'tell me how',
        'how',
        'can you tell me how to get there',
        'macam mana nak pergi',
        'show me the route',
      ]) {
        expect(parseIntent(t), isA<RouteFollowUpIntent>(), reason: t);
      }
      for (final t in [
        'take me there',
        'navigate there',
        'bawa saya ke sana',
      ]) {
        final r = parseIntent(t);
        expect(r, isA<RouteFollowUpIntent>(), reason: t);
        expect((r! as RouteFollowUpIntent).autoStart, isTrue, reason: t);
      }
    });

    test('soalan umum "how ..." tetap ke model', () {
      expect(parseIntent('how does inflation work'), isNull);
      expect(parseIntent('what is the best way to learn english'), isNull);
    });
  });

  group('sembang ringkas dijawab terus (tangkapan skrin penguji)', () {
    ChatKind? kind(String text) {
      final i = parseIntent(text);
      return i is ChatIntent ? i.kind : null;
    }

    test('hari dan tarikh', () {
      for (final t in [
        'What day is today?',
        'what day is it',
        'what is the date today',
        "what's today's date",
        'hari apa hari ini',
        'Hari ni hari apa?',
        'tarikh hari ini',
        'tarikh berapa hari ni',
      ]) {
        expect(kind(t), ChatKind.date, reason: t);
      }
    });

    test('masa', () {
      for (final t in [
        'what time is it',
        "what's the time now",
        'pukul berapa sekarang',
        'Jam berapa?',
        'masa sekarang',
      ]) {
        expect(kind(t), ChatKind.time, reason: t);
      }
      // Soalan perjalanan "what time will I arrive" kekal sebagai soalan perjalanan.
      expect(parseIntent('what time will i arrive'), isA<TripInfoIntent>());
    });

    test('"siapa saya" ialah soalan tentang pengguna, bukan tentang FG AI', () {
      for (final t in [
        'Do you know who am i?',
        'who am i',
        'do you know me',
        'siapa saya',
        'awak kenal saya tak',
        'aku ni siapa',
      ]) {
        expect(kind(t), ChatKind.userIdentity, reason: t);
      }
      expect(kind('who are you'), ChatKind.identity);
    });

    test('khabar, selamat tinggal, mengantuk', () {
      expect(kind('how are you'), ChatKind.howAreYou);
      expect(kind('apa khabar'), ChatKind.howAreYou);
      expect(kind('bye'), ChatKind.farewell);
      expect(kind('jumpa lagi'), ChatKind.farewell);
      expect(kind('I am so sleepy'), ChatKind.drowsy);
      expect(kind('saya mengantuk'), ChatKind.drowsy);
      expect(kind('penat'), ChatKind.drowsy);
      expect(kind('nak rehat'), ChatKind.drowsy);
    });

    test('"selamat malam" kekal salam, bukan selamat tinggal', () {
      expect(kind('selamat malam'), ChatKind.greeting);
    });

    test('"saya sesat" menunjukkan lokasi semasa', () {
      expect(parseIntent('I am lost'), isA<CurrentLocationIntent>());
      expect(parseIntent('saya sesat'), isA<CurrentLocationIntent>());
    });

    test(
      'ayat panjang yang kebetulan mengandungi perkataan itu tidak ditangkap',
      () {
        expect(
          parseIntent('who am i going to meet at klcc'),
          isNot(isA<ChatIntent>()),
        );
        expect(
          parseIntent('why am i so tired of traffic jams in kl'),
          isNot(isA<ChatIntent>()),
        );
      },
    );
  });

  group('kategori tempat (kedai gunting, farmasi, ATM...)', () {
    NearbyCategory? cat(String text) {
      final i = parseIntent(text);
      return i is NearbyIntent ? i.category : null;
    }

    test('ayat sebenar penguji: kedai gunting terdekat', () {
      expect(
        cat('Ok boleh bagi tahu saya dimana kedai gunting terdekat?'),
        NearbyCategory.barber,
      );
      expect(cat('kedai gunting terdekat'), NearbyCategory.barber);
      expect(cat('nearest barber shop'), NearbyCategory.barber);
      expect(cat('nak gunting rambut'), NearbyCategory.barber);
    });

    test('kategori sahaja tanpa "terdekat" pun difahami', () {
      expect(cat('kedai gunting'), NearbyCategory.barber);
      expect(cat('farmasi'), NearbyCategory.pharmacy);
      expect(cat('atm'), NearbyCategory.atm);
      expect(cat('makan'), NearbyCategory.food);
      expect(cat('bengkel kereta'), NearbyCategory.workshop);
    });

    test('perkataan BM dan Inggeris bagi setiap kategori baharu', () {
      const cases = {
        'klinik terdekat': NearbyCategory.clinic,
        'nearest clinic': NearbyCategory.clinic,
        'hospital terdekat': NearbyCategory.hospital,
        'farmasi berdekatan': NearbyCategory.pharmacy,
        'nearest pharmacy': NearbyCategory.pharmacy,
        'mesin atm terdekat': NearbyCategory.atm,
        'bank terdekat': NearbyCategory.bank,
        'kedai runcit terdekat': NearbyCategory.convenience,
        'nearest 7 eleven': NearbyCategory.convenience,
        'pasar raya terdekat': NearbyCategory.supermarket,
        'nearest shopping mall': NearbyCategory.mall,
        'cuci kereta terdekat': NearbyCategory.carWash,
        'nearest car wash': NearbyCategory.carWash,
        'bengkel terdekat': NearbyCategory.workshop,
        'kereta rosak bengkel dekat sini': NearbyCategory.workshop,
        'kedai tayar terdekat': NearbyCategory.tyres,
        'tayar pancit nearest tyre shop': NearbyCategory.tyres,
        'dobi terdekat': NearbyCategory.laundry,
        'nearest laundry': NearbyCategory.laundry,
        'hotel terdekat': NearbyCategory.hotel,
        'homestay berdekatan': NearbyCategory.hotel,
        'balai polis terdekat': NearbyCategory.police,
        'nearest police station': NearbyCategory.police,
        'pejabat pos terdekat': NearbyCategory.postOffice,
        'nearest post office': NearbyCategory.postOffice,
        'nearest ev charger': NearbyCategory.evCharging,
        'pengecas ev terdekat': NearbyCategory.evCharging,
        'stesen lrt terdekat': NearbyCategory.trainStation,
        'nearest mrt station': NearbyCategory.trainStation,
      };
      cases.forEach((text, expected) {
        expect(cat(text), expected, reason: text);
      });
    });

    test('klinik ialah klinik, bukan hospital', () {
      expect(cat('klinik terdekat'), NearbyCategory.clinic);
      expect(cat('hospital terdekat'), NearbyCategory.hospital);
    });

    test(
      'nama tempat yang mengandungi perkataan kategori kekal carian nama',
      () {
        final i = parseIntent('cari bank islam');
        expect(i, isA<SearchIntent>());
        expect((i! as SearchIntent).query, 'bank islam');
        expect(parseIntent('cari pavilion mall'), isA<SearchIntent>());
        expect(
          parseIntent('cari klinik kesihatan seksyen 7'),
          isA<SearchIntent>(),
        );
      },
    );

    test('"bawa saya ke" kategori terus merancang laluan ke yang terdekat', () {
      final i = parseIntent('bawa saya ke farmasi terdekat');
      expect(i, isA<NearbyIntent>());
      expect((i! as NearbyIntent).navigate, isTrue);
    });
  });
}
