import 'package:fgmap/features/local_assistant/domain/intent_router.dart';
import 'package:fgmap/features/route_preview/domain/route_preference.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Korpus rujukan faham-arahan: ayat pengguna sebenar (BM/English/rojak/salah taip) -> intent jangkaan.
/// Tambah baris di sini setiap kali ada ayat baharu yang gagal difahami di lapangan.
typedef Check = bool Function(AssistantIntent? i);

class CorpusRow {
  const CorpusRow(this.text, this.check, [this.ctx]);

  final String text;
  final Check check;
  final ConversationContext? ctx;
}

Check route(String dest, {RoutePreference? pref, bool? auto}) =>
    (i) =>
        i is RouteIntent &&
        i.destination == dest &&
        (pref == null || i.preference == pref) &&
        (auto == null || i.autoStart == auto);

Check nearby(NearbyCategory c, {bool? navigate}) =>
    (i) =>
        i is NearbyIntent &&
        i.category == c &&
        (navigate == null || i.navigate == navigate);

Check search(String q, {bool? speculative}) =>
    (i) =>
        i is SearchIntent &&
        i.query == q &&
        (speculative == null || i.speculative == speculative);

Check isType<T>() =>
    (i) => i is T;
Check isNull() =>
    (i) => i == null;
Check chat(ChatKind k) =>
    (i) => i is ChatIntent && i.kind == k;
Check trip(TripInfoKind k) =>
    (i) => i is TripInfoIntent && i.kind == k;
Check saved(SavedSlot s) =>
    (i) => i is GoSavedPlaceIntent && i.slot == s;

const _withRoute = ConversationContext(hasRoute: true, offeredStart: true);
const _routeNoOffer = ConversationContext(hasRoute: true);
const _navigating = ConversationContext(navActive: true);
const _afterResults = ConversationContext(resultCount: 3);
const _asked = ConversationContext(pendingDestination: true);

void main() {
  final rows = <CorpusRow>[
    // --- laluan: slang / SMS / rojak / salah taip ---
    CorpusRow('nk g klcc', route('klcc')),
    CorpusRow('cmne nk gi klcc', route('klcc')),
    CorpusRow('bawak saya ke klcc', route('klcc', auto: true)),
    CorpusRow('rute ke klcc', route('klcc')),
    CorpusRow('g klcc', route('klcc')),
    CorpusRow('nak pegi pavilion', route('pavilion')),
    CorpusRow('macam mana nak pergi ipoh', route('ipoh')),
    CorpusRow('macam mana nak sampai ke ipoh', route('ipoh')),
    CorpusRow('how to reach klcc', route('klcc')),
    CorpusRow('how do i get to klcc', route('klcc')),
    CorpusRow('how far is klcc', route('klcc')),
    CorpusRow('berapa jauh ke ipoh', route('ipoh')),
    CorpusRow(
      'xnak tol, bawa saya ke penang',
      route('penang', pref: RoutePreference.noTolls, auto: true),
    ),
    CorpusRow(
      'route to penang x nak tol',
      route('penang', pref: RoutePreference.noTolls),
    ),
    CorpusRow(
      'navigate to penang no toll',
      route('penang', pref: RoutePreference.noTolls),
    ),
    CorpusRow('navigte to klcc', route('klcc', auto: true)),
    CorpusRow('navigatw to klcc', route('klcc', auto: true)),
    CorpusRow(
      'route to jalan kampung baru',
      route('jalan kampung baru', pref: null),
    ),
    CorpusRow('i wanna go to klcc', route('klcc')),
    CorpusRow('im on my way to ipoh', route('ipoh')),
    CorpusRow('take me to klcc please', route('klcc', auto: true)),
    CorpusRow('pergi ke masjid negara', route('masjid negara')),
    CorpusRow('jom ke sunway pyramid', route('sunway pyramid')),
    // --- kategori vs nama ---
    CorpusRow(
      'bawa saya ke stesen minyak terdekat',
      nearby(NearbyCategory.fuel, navigate: true),
    ),
    CorpusRow(
      'take me to the nearest petrol station',
      nearby(NearbyCategory.fuel, navigate: true),
    ),
    CorpusRow('nak ke tandas', nearby(NearbyCategory.toilets, navigate: true)),
    CorpusRow('surau terdekat', nearby(NearbyCategory.mosque, navigate: false)),
    CorpusRow(
      'nearest petrol station',
      nearby(NearbyCategory.fuel, navigate: false),
    ),
    CorpusRow('cari masjid negara', search('masjid negara')),
    CorpusRow(
      'where is hospital kuala lumpur',
      search('hospital kuala lumpur'),
    ),
    CorpusRow('cari parking klcc', search('parking klcc')),
    CorpusRow('cari tandas', nearby(NearbyCategory.toilets)),
    CorpusRow('find petrol', nearby(NearbyCategory.fuel)),
    // --- nama tempat sahaja ---
    CorpusRow('klcc', search('klcc', speculative: true)),
    CorpusRow('masjid negara', search('masjid negara', speculative: true)),
    CorpusRow('pavilion kl', search('pavilion kl', speculative: true)),
    CorpusRow(
      'Menara Kuala Lumpur',
      search('menara kuala lumpur', speculative: true),
    ),
    // --- cuaca/solat tidak tersalah jadi laluan ---
    CorpusRow('is it going to rain in klcc', isType<WeatherIntent>()),
    CorpusRow('akan hujan ke di ipoh', isType<WeatherIntent>()),
    CorpusRow('cuaca kl', isType<WeatherIntent>()),
    CorpusRow('waktu solat', isType<PrayerTimesIntent>()),
    CorpusRow('arah kiblat', isType<QiblaIntent>()),
    // --- lokasi ---
    CorpusRow('where am i', isType<CurrentLocationIntent>()),
    CorpusRow('saya kat mana', isType<CurrentLocationIntent>()),
    // --- tempat tersimpan ---
    CorpusRow('go home', saved(SavedSlot.home)),
    CorpusRow('balik rumah', saved(SavedSlot.home)),
    CorpusRow('bawa saya balik', saved(SavedSlot.home)),
    CorpusRow('take me home', saved(SavedSlot.home)),
    CorpusRow('navigate to work', saved(SavedSlot.work)),
    CorpusRow('pergi kerja', saved(SavedSlot.work)),
    CorpusRow('nak ke pejabat', saved(SavedSlot.work)),
    CorpusRow('i want to go home', saved(SavedSlot.home)),
    CorpusRow('navigate to home depot', route('home depot')),
    // --- maklumat perjalanan ---
    CorpusRow('how far is it', trip(TripInfoKind.distance)),
    CorpusRow('berapa jauh lagi', trip(TripInfoKind.distance)),
    CorpusRow('how long left', trip(TripInfoKind.timeLeft)),
    CorpusRow('berapa lama lagi', trip(TripInfoKind.timeLeft)),
    CorpusRow('brape lama lg', trip(TripInfoKind.timeLeft)),
    CorpusRow('what time will i arrive', trip(TripInfoKind.arrival)),
    CorpusRow('pukul berapa sampai', trip(TripInfoKind.arrival)),
    CorpusRow('eta', trip(TripInfoKind.arrival)),
    CorpusRow('how much is the toll', trip(TripInfoKind.toll)),
    CorpusRow('berapa tol', trip(TripInfoKind.toll)),
    CorpusRow('ada tol tak', trip(TripInfoKind.toll)),
    CorpusRow('how much petrol will i need', trip(TripInfoKind.fuelCost)),
    CorpusRow('kos minyak', trip(TripInfoKind.fuelCost)),
    CorpusRow('next turn', trip(TripInfoKind.nextTurn)),
    CorpusRow('belok mana', trip(TripInfoKind.nextTurn)),
    CorpusRow('speed limit', trip(TripInfoKind.speedLimit)),
    CorpusRow('had laju berapa', trip(TripInfoKind.speedLimit)),
    // --- kawalan ---
    CorpusRow(
      'tukar ke motosikal',
      (i) => i is ChangeVehicleIntent && i.vehicle == AssistVehicle.motorcycle,
    ),
    CorpusRow(
      'switch to car',
      (i) => i is ChangeVehicleIntent && i.vehicle == AssistVehicle.car,
    ),
    CorpusRow(
      'naik motor',
      (i) => i is ChangeVehicleIntent && i.vehicle == AssistVehicle.motorcycle,
    ),
    CorpusRow('mute', (i) => i is VoiceIntent && !i.enabled),
    CorpusRow('senyap', (i) => i is VoiceIntent && !i.enabled),
    CorpusRow('matikan suara', (i) => i is VoiceIntent && !i.enabled),
    CorpusRow('unmute', (i) => i is VoiceIntent && i.enabled),
    CorpusRow('buka suara', (i) => i is VoiceIntent && i.enabled),
    CorpusRow(
      'dark mode',
      (i) => i is ThemeIntent && i.theme == AssistTheme.dark,
    ),
    CorpusRow(
      'mod gelap',
      (i) => i is ThemeIntent && i.theme == AssistTheme.dark,
    ),
    CorpusRow(
      'light mode',
      (i) => i is ThemeIntent && i.theme == AssistTheme.light,
    ),
    // --- tanya butiran ---
    CorpusRow('navigate', isType<AskSlotIntent>()),
    CorpusRow('nak pergi', isType<AskSlotIntent>()),
    CorpusRow('bawa saya', isType<AskSlotIntent>()),
    CorpusRow('play radio', isType<AskSlotIntent>()),
    CorpusRow('play era fm', isType<PlayRadioIntent>()),
    CorpusRow('start', isType<StartNavigationIntent>()),
    // --- ack / batal tanpa konteks ---
    CorpusRow('ok', chat(ChatKind.ack)),
    CorpusRow('tak jadi', chat(ChatKind.ack)),
    CorpusRow('ok thanks', chat(ChatKind.thanks)),
    CorpusRow('stop', chat(ChatKind.ack)),
    // --- soalan umum MESTI ke model ---
    CorpusRow('what is the best way to learn english', isNull()),
    CorpusRow('apa itu sabar?', isNull()),
    CorpusRow('Explain tolls in Malaysia', isNull()),
    CorpusRow('who is the prime minister of malaysia', isNull()),
    CorpusRow('how does inflation work', isNull()),
    CorpusRow('write me a poem about the sea', isNull()),
    CorpusRow('what is the capital of france', isNull()),
    CorpusRow('kenapa langit biru', isNull()),
    CorpusRow('hello world program in python', isNull()),
    // --- tambahan: ayat lapangan ---
    CorpusRow('nak pergi ke klia', route('klia')),
    CorpusRow('bawa aku ke ipoh', route('ipoh', auto: true)),
    CorpusRow('hantar saya ke kl sentral', route('kl sentral', auto: true)),
    CorpusRow('pergi mid valley', route('mid valley')),
    CorpusRow(
      'navigate me to genting highlands',
      route('genting highlands', auto: true),
    ),
    CorpusRow('directions to klia2', route('klia2')),
    CorpusRow(
      'drive to penang no highway',
      route('penang', pref: RoutePreference.noHighways),
    ),
    CorpusRow(
      'route to johor bahru, avoid tolls',
      route('johor bahru', pref: RoutePreference.noTolls),
    ),
    CorpusRow('take me to the airport', route('airport', auto: true)),
    CorpusRow(
      'i need to go to hospital kuala lumpur',
      route('hospital kuala lumpur'),
    ),
    CorpusRow(
      'nak ke hospital',
      nearby(NearbyCategory.hospital, navigate: true),
    ),
    CorpusRow('ke klcc', route('klcc')),
    CorpusRow('cara nak ke ipoh', route('ipoh')),
    CorpusRow('take me to mcdonalds', route('mcdonalds', auto: true)),
    CorpusRow('drive me home', saved(SavedSlot.home)),
    CorpusRow('nak balik', saved(SavedSlot.home)),
    CorpusRow('balik la', saved(SavedSlot.home)),
    CorpusRow('hujan tak kat ipoh', isType<WeatherIntent>()),
    CorpusRow('cuaca hari ni', (i) => i is WeatherIntent && i.place == null),
    CorpusRow(
      'weather tomorrow in penang',
      (i) => i is WeatherIntent && i.place == 'penang',
    ),
    CorpusRow('bila masuk zohor', isType<PrayerTimesIntent>()),
    CorpusRow('dah masuk zohor ke', isType<PrayerTimesIntent>()),
    CorpusRow('what time is maghrib', isType<PrayerTimesIntent>()),
    CorpusRow('any petrol station near me', nearby(NearbyCategory.fuel)),
    CorpusRow('mana ada masjid', nearby(NearbyCategory.mosque)),
    CorpusRow('ada stesen minyak tak dekat sini', nearby(NearbyCategory.fuel)),
    CorpusRow('where can i eat', nearby(NearbyCategory.food)),
    CorpusRow('im hungry', nearby(NearbyCategory.food)),
    CorpusRow('nak makan', nearby(NearbyCategory.food)),
    CorpusRow('tolong senyap', (i) => i is VoiceIntent && !i.enabled),
    CorpusRow('boleh tak tutup suara', (i) => i is VoiceIntent && !i.enabled),
    CorpusRow('berapa jam lagi', trip(TripInfoKind.timeLeft)),
    CorpusRow('how many km left', trip(TripInfoKind.distance)),
    CorpusRow('where do i turn', trip(TripInfoKind.nextTurn)),
    CorpusRow('naviagte to klcc', route('klcc', auto: true)),
    CorpusRow(
      'wheather in ipoh',
      (i) => i is WeatherIntent && i.place == 'ipoh',
    ),
    CorpusRow('petrl station terdekat', nearby(NearbyCategory.fuel)),
    CorpusRow('masjd terdekat', nearby(NearbyCategory.mosque)),
    CorpusRow('neearest toilet', nearby(NearbyCategory.toilets)),
    CorpusRow('navgate to klcc', route('klcc', auto: true)),

    // --- dengan konteks ---
    CorpusRow('ok', isType<StartNavigationIntent>(), _withRoute),
    CorpusRow('ya', isType<StartNavigationIntent>(), _withRoute),
    CorpusRow('ok', chat(ChatKind.ack), _routeNoOffer),
    CorpusRow('jom', isType<StartNavigationIntent>(), _routeNoOffer),
    CorpusRow('mula', isType<StartNavigationIntent>(), _routeNoOffer),
    CorpusRow('stop', isType<StopNavigationIntent>(), _navigating),
    CorpusRow('stop navigation', isType<StopNavigationIntent>(), _navigating),
    CorpusRow('tamatkan navigasi', isType<StopNavigationIntent>(), _navigating),
    CorpusRow('stop', isType<CancelRouteIntent>(), _routeNoOffer),
    CorpusRow(
      'yang pertama',
      (i) => i is PickResultIntent && i.index == 0,
      _afterResults,
    ),
    CorpusRow(
      'the second one',
      (i) => i is PickResultIntent && i.index == 1,
      _afterResults,
    ),
    CorpusRow(
      'yang ketiga',
      (i) => i is PickResultIntent && i.index == 2,
      _afterResults,
    ),
    CorpusRow(
      'bawa saya ke yang pertama',
      (i) => i is PickResultIntent && i.index == 0 && i.autoStart,
      _afterResults,
    ),
    CorpusRow(
      'satu lagi',
      (i) => i is PickResultIntent && i.other,
      _afterResults,
    ),
    CorpusRow('klcc', route('klcc'), _asked),
    CorpusRow('masjid putra', route('masjid putra'), _asked),
  ];

  for (final r in rows) {
    test('"${r.text}"${r.ctx == null ? '' : ' [konteks]'}', () {
      final got = parseIntent(r.text, context: r.ctx);
      expect(
        r.check(got),
        isTrue,
        reason: '"${r.text}" -> ${got == null ? 'null' : _describe(got)}',
      );
    });
  }
}

String _describe(AssistantIntent i) => switch (i) {
  RouteIntent(:final destination, :final preference, :final autoStart) =>
    'Route($destination, $preference, auto=$autoStart)',
  NearbyIntent(:final category, :final navigate) =>
    'Nearby($category, nav=$navigate)',
  SearchIntent(:final query, :final speculative) =>
    'Search($query, spec=$speculative)',
  _ => i.runtimeType.toString(),
};
