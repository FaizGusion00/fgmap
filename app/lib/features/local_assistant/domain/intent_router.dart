import 'package:flutter/foundation.dart';

import '../../route_preview/domain/route_preference.dart';
import '../../search/domain/nearby_category.dart';

/// Arahan peta yang difahami terus oleh kod (tanpa model): pantas, tepat dan tidak berulang.
/// Teks lain (soalan umum) pergi ke model pada telefon.
@immutable
sealed class AssistantIntent {
  const AssistantIntent();
}

/// "Route to KLCC", "bawa saya ke Kuala Terengganu tanpa tol", "navigate to Ipoh".
class RouteIntent extends AssistantIntent {
  const RouteIntent(
    this.destination, {
    this.preference = RoutePreference.recommended,
    this.autoStart = false,
  });

  final String destination;
  final RoutePreference preference;

  /// Pengguna mahu terus bergerak ("navigate to", "bawa saya ke", "... start now").
  final bool autoStart;
}

/// "Start now", "mula", "jom" — mula navigasi pada laluan yang sedang dipratonton.
class StartNavigationIntent extends AssistantIntent {
  const StartNavigationIntent();
}

/// "Tanpa tol", "paling selamat" tanpa destinasi baharu: tukar pilihan pada laluan semasa.
class RoutePreferenceIntent extends AssistantIntent {
  const RoutePreferenceIntent(this.preference, {this.autoStart = false});

  final RoutePreference preference;
  final bool autoStart;
}

class CancelRouteIntent extends AssistantIntent {
  const CancelRouteIntent();
}

/// "Stesen minyak terdekat", "nearest mosque".
class NearbyIntent extends AssistantIntent {
  const NearbyIntent(this.category);

  final NearbyCategory category;
}

/// "Cari Pavilion", "where is Masjid Putra".
class SearchIntent extends AssistantIntent {
  const SearchIntent(this.query);

  final String query;
}

/// "Search my current location", "where am I", "lokasi saya" — GPS peranti, bukan carian nama tempat.
class CurrentLocationIntent extends AssistantIntent {
  const CurrentLocationIntent();
}

/// "What can I ask offline?", "apa boleh tanya" — FAQ ciri, tanpa skema alat.
class CapabilitiesIntent extends AssistantIntent {
  const CapabilitiesIntent({this.offlineFocused = false});

  /// Pengguna menyebut offline / model pada telefon secara khusus.
  final bool offlineFocused;
}

class WeatherIntent extends AssistantIntent {
  const WeatherIntent([this.place]);

  final String? place;
}

class AirQualityIntent extends AssistantIntent {
  const AirQualityIntent([this.place]);

  final String? place;
}

class QiblaIntent extends AssistantIntent {
  const QiblaIntent();
}

class PrayerTimesIntent extends AssistantIntent {
  const PrayerTimesIntent();
}

/// "R&R sepanjang laluan", "EV charging on the way". [category] ialah nama alat
/// `list_along_route` (rest_area, fuel, ev, mosque, toilets).
class AlongRouteIntent extends AssistantIntent {
  const AlongRouteIntent(this.category);

  final String category;
}

class PlayMusicIntent extends AssistantIntent {
  const PlayMusicIntent(this.query);

  final String query;
}

class PlayRadioIntent extends AssistantIntent {
  const PlayRadioIntent(this.query);

  final String query;
}

/// Teks ringkas untuk padanan: huruf kecil, tanda baca jadi ruang (kecuali `&` untuk "R&R").
String normalizeCommand(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'''[.,!?;:"“”()\[\]{}]'''), ' ')
    .replaceAll(RegExp(r"[’']"), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Teka bahasa daripada mesej (bukan tetapan app): pengguna boleh bertukar bahasa di tengah sembang.
bool looksMalay(String text) {
  final t = ' ${normalizeCommand(text)} ';
  const words = [
    ' ke ',
    ' saya ',
    ' aku ',
    ' nak ',
    ' cari ',
    ' jalan ',
    ' tolong ',
    ' mana ',
    ' cuaca ',
    ' laluan ',
    ' pergi ',
    ' sekarang ',
    ' tanpa ',
    ' apa ',
    ' bila ',
    ' terdekat ',
    ' boleh ',
    ' tak ',
    ' tidak ',
    ' mula ',
    ' bawa ',
    ' hantar ',
    ' kat ',
    ' dekat ',
    ' waktu ',
    ' solat ',
    ' ini ',
    ' itu ',
    ' dan ',
    ' yang ',
    ' untuk ',
    ' berapa ',
    ' kenapa ',
    ' macam ',
    ' jom ',
    ' elak ',
    ' masjid ',
    ' tandas ',
    ' minyak ',
    ' lagu ',
  ];
  return words.any(t.contains);
}

/// Mesej jelas dalam bahasa Inggeris (untuk memilih bahasa jawapan bila bukan BM).
bool looksEnglish(String text) {
  final t = ' ${normalizeCommand(text)} ';
  const words = [
    ' the ',
    ' to ',
    ' is ',
    ' what ',
    ' how ',
    ' where ',
    ' me ',
    ' my ',
    ' route ',
    ' weather ',
    ' please ',
    ' can ',
    ' you ',
    ' i ',
    ' near ',
    ' nearest ',
    ' find ',
    ' start ',
    ' now ',
    ' and ',
    ' of ',
    ' are ',
    ' why ',
    ' when ',
    ' who ',
    ' tell ',
    ' about ',
    ' play ',
    ' go ',
  ];
  return words.any(t.contains);
}

const _prefPatterns = <RoutePreference, String>{
  RoutePreference.noTolls:
      r'(?:no|without|avoid(?:ing)?|skip)\s+tolls?|toll[ -]?free|tanpa\s+tol|elak(?:kan)?\s+tol|bebas\s+tol|tak\s+(?:nak\s+)?(?:lalu\s+)?tol|x\s+nak\s+tol',
  RoutePreference.noHighways:
      r'(?:no|without|avoid(?:ing)?)\s+(?:highways?|expressways?)|(?:tanpa|elak(?:kan)?)\s+(?:lebuh\s*raya|highway|expressway)|jalan\s+kampung|jalan\s+lama',
  RoutePreference.safest:
      r'safest|safe\s+route|most\s+safe|paling\s+selamat|laluan\s+selamat|jalan\s+selamat|lebih\s+selamat',
  RoutePreference.cheapest:
      r'cheapest|cheaper|most\s+economical|paling\s+murah|paling\s+jimat|lebih\s+murah|jimat\s+(?:duit|kos)',
  RoutePreference.shortest:
      r'shortest|shorter|paling\s+(?:pendek|dekat)|terpendek|terdekat\s+jarak|jarak\s+terpendek',
  RoutePreference.fastest:
      r'fastest|quickest|faster|paling\s+(?:cepat|laju|pantas)|terpantas|tercepat|lebih\s+cepat',
};

final _startNow = RegExp(
  r"\b(?:start\s+(?:now|navigation|navigating|nav|the\s+navigation|driving|route|it)|lets\s+go|let\s+us\s+go|go\s+now|begin\s+(?:navigation|now)|navigate\s+now|mula(?:kan)?\s+(?:navigasi|sekarang|perjalanan|jalan)|jom\s+(?:gerak|jalan|pergi)|gerak\s+sekarang|terus\s+(?:mula|jalan|gerak))\b",
);

/// "... and start", "... dan terus gerak": hanya bermakna bersama destinasi.
final _andStart = RegExp(
  r'\b(?:and|dan|then|lepas\s+tu|kemudian)\s+(?:start|mula(?:kan)?|terus|go|gerak|navigate|jalan)\b',
);

const _startAlone = {
  'start',
  'go',
  'mula',
  'mulakan',
  'jom',
  'gerak',
  'ok',
  'okay',
  'yes',
  'ya',
  'yup',
  'boleh',
  'ok start',
  'okay start',
  'yes start',
  'ya mula',
  'start it',
  'begin',
  'navigate',
  'drive',
  'ok go',
  'ok jom',
  'ok mula',
  'start please',
  'tolong mula',
  'proceed',
  'teruskan',
  'go ahead',
};

final _routeVerbs = <({RegExp re, bool autoStart})>[
  (
    re: RegExp(
      r'\b(?:navigate|navigation|drive|take\s+me|bring\s+me|get\s+me|guide\s+me)\s+(?:me\s+)?(?:to|towards|ke)\s+(.+)',
    ),
    autoStart: true,
  ),
  (
    re: RegExp(
      r'\b(?:bawa|hantar|pandu)\s+(?:saya|aku|kami|sy|kita)\s+(?:ke|pergi\s+ke|pergi|menuju)\s+(.+)',
    ),
    autoStart: true,
  ),
  (
    re: RegExp(
      r'\b(?:route|routes|directions?|go|head(?:ing)?|how\s+(?:do\s+i|to)\s+get|show\s+(?:me\s+)?(?:the\s+)?(?:route|way))\s+(?:me\s+)?(?:to|towards)\s+(.+)',
    ),
    autoStart: false,
  ),
  (
    re: RegExp(
      r'(?:^|\b(?:nak|mahu|hendak|jom|laluan|jalan|navigasi|arah|hala|route|tunjuk(?:kan)?(?:\s+jalan)?|macam\s+mana\s+(?:nak\s+)?(?:pergi|ke)|cara))\s*(?:pergi\s+ke|pergi|ke|gi)\s+(.+)',
    ),
    autoStart: false,
  ),
  (re: RegExp(r'^(?:route|navigate)\s+(.+)'), autoStart: false),
];

final _nearbyWords = RegExp(
  r'\b(?:nearest|nearby|near\s+me|closest|around\s+me|terdekat|berdekatan|dekat\s+(?:sini|saya|aku)|sekitar\s+sini|paling\s+dekat)\b',
);

final _alongWords = RegExp(
  r'\b(?:along|on\s+the\s+way|on\s+my\s+(?:way|route)|on\s+route|en\s+route|sepanjang|dalam\s+perjalanan|di\s+laluan|tepi\s+laluan|depan\s+nanti|ahead)\b',
);

/// Kenal pasti arahan peta dalam [text]. Null = biar model menjawab.
/// [hasRoute]: pratonton laluan sedang dipaparkan (untuk "start", "tanpa tol").
AssistantIntent? parseIntent(String text, {bool hasRoute = false}) {
  final t = normalizeCommand(text);
  if (t.isEmpty) return null;

  if (RegExp(
    r'^(?:cancel|stop|end|clear|batal(?:kan)?|henti(?:kan)?|tamat(?:kan)?|padam)\s*(?:the\s+)?(?:route|navigation|nav|laluan|navigasi|perjalanan)?$',
  ).hasMatch(t)) {
    return hasRoute ? const CancelRouteIntent() : null;
  }

  final capabilities = _capabilitiesIntent(t);
  if (capabilities != null) return capabilities;

  if (_isCurrentLocationQuery(t)) {
    return const CurrentLocationIntent();
  }

  final pref = _preferenceIn(t);
  final startNow = _startNow.hasMatch(t);

  for (final verb in _routeVerbs) {
    final m = verb.re.firstMatch(t);
    if (m == null) continue;
    final dest = _cleanDestination(m.group(1)!);
    if (dest == null) continue;
    return RouteIntent(
      dest,
      preference: pref ?? RoutePreference.recommended,
      autoStart: verb.autoStart || startNow || _andStart.hasMatch(t),
    );
  }

  if (startNow || (hasRoute && _startAlone.contains(t))) {
    if (pref != null) {
      return RoutePreferenceIntent(pref, autoStart: true);
    }
    return const StartNavigationIntent();
  }

  final along = _alongCategory(t);
  if (along != null && (_alongWords.hasMatch(t) || hasRoute)) {
    return AlongRouteIntent(along);
  }

  if (pref != null &&
      (hasRoute ||
          RegExp(
            r'\b(?:route|routes|laluan|jalan|pilih|choose|take|guna|use|ambil|tukar|switch|change)\b',
          ).hasMatch(t))) {
    return RoutePreferenceIntent(pref);
  }

  if (RegExp(r'\b(?:qibla|qiblat|kiblat|kiblah|arah\s+kaabah)\b').hasMatch(t)) {
    return const QiblaIntent();
  }

  if (RegExp(
    r'\b(?:waktu\s+(?:solat|sembahyang|azan)|prayer\s+times?|next\s+prayer|solat\s+(?:seterusnya|berikutnya)|azan\s+(?:bila|pukul)|bila\s+(?:subuh|zohor|zuhur|asar|maghrib|isyak|isya|azan)|(?:subuh|zohor|zuhur|asar|maghrib|isyak|isya|fajr|dhuhr|asr|isha)\s+(?:pukul|bila|time|at\s+what))',
  ).hasMatch(t)) {
    return const PrayerTimesIntent();
  }

  final weather = RegExp(
    r'\b(?:weather|cuaca|forecast|ramalan(?:\s+cuaca)?|(?:will\s+it|is\s+it\s+going\s+to)\s+rain|hujan\s+(?:tak|ke|tidak)|nak\s+hujan)\b',
  );
  if (weather.hasMatch(t)) {
    return WeatherIntent(_placeAfter(t, weather));
  }

  final air = RegExp(
    r'\b(?:ipu|aqi|air\s+quality|kualiti\s+udara|jerebu|haze|pencemaran\s+udara)\b',
  );
  if (air.hasMatch(t)) {
    return AirQualityIntent(_placeAfter(t, air));
  }

  final radio = RegExp(
    r'^(?:play|mainkan|main|pasang|putar|buka)\s+(?:radio|stesen(?:\s+radio)?)\s+(.+)',
  ).firstMatch(t);
  if (radio != null) return PlayRadioIntent(radio.group(1)!.trim());
  final music = RegExp(
    r'^(?:play|mainkan|main|pasang|putar)\s+(?:(?:a\s+)?(?:song|songs|music|lagu|muzik)\s+)?(?:by\s+|oleh\s+)?(.+)',
  ).firstMatch(t);
  if (music != null) {
    final q = music.group(1)!.trim();
    if (q.isNotEmpty) return PlayMusicIntent(q);
  }

  final nearby = _nearbyCategory(t);
  if (nearby != null && (_nearbyWords.hasMatch(t) || _searchVerb.hasMatch(t))) {
    return NearbyIntent(nearby);
  }

  final search = _searchVerb.firstMatch(t);
  if (search != null) {
    final q = _cleanDestination(search.group(1)!);
    if (q != null) {
      if (_isCurrentLocationPhrase(q)) return const CurrentLocationIntent();
      return SearchIntent(q);
    }
  }

  return null;
}

final _searchVerb = RegExp(
  r'^(?:please\s+|tolong\s+)?(?:find|search(?:\s+for)?|look\s+for|locate|cari(?:kan)?|where\s+is|wheres|di\s+mana(?:kah)?|kat\s+mana|mana)\s+(.+)',
);

/// "my current location", "lokasi saya", "where am i", "cari lokasi semasa".
bool _isCurrentLocationQuery(String t) {
  if (RegExp(
    r'^(?:where\s+am\s+i|wheres\s+my\s+location|what(?:s|\s+is)\s+my\s+(?:current\s+)?(?:location|position)|lokasi\s+(?:saya|aku|semasa)|mana\s+(?:saya|aku)\s+sekarang|kedudukan\s+(?:saya|aku|semasa))$',
  ).hasMatch(t)) {
    return true;
  }
  if (RegExp(
    r'^(?:please\s+|tolong\s+)?(?:find|search(?:\s+for)?|look\s+for|locate|show|cari(?:kan)?|tunjuk(?:kan)?)\s+(?:for\s+)?(?:my\s+)?(?:current\s+)?(?:location|position|gps|lokasi|kedudukan)(?:\s+(?:saya|aku|semasa|current))?$',
  ).hasMatch(t)) {
    return true;
  }
  return _isCurrentLocationPhrase(t);
}

bool _isCurrentLocationPhrase(String q) {
  final t = q.trim();
  return RegExp(
    r'^(?:my\s+)?(?:current\s+)?(?:location|position|gps)(?:\s+here)?$|^(?:lokasi|kedudukan)(?:\s+(?:saya|aku|semasa|ini))?$|^(?:my\s+)?(?:lokasi|kedudukan)\s+(?:saya|aku)$',
  ).hasMatch(t);
}

CapabilitiesIntent? _capabilitiesIntent(String t) {
  final offline = RegExp(
    r'\b(?:offline|ofline|on[- ]?device|on[- ]?phone|tanpa\s+internet|luar\s+talian|model\s+(?:pada\s+)?(?:telefon|peranti)|local\s+model)\b',
  ).hasMatch(t);
  final asks = RegExp(
    r'\b(?:what\s+can\s+i\s+(?:ask|do|use)|what\s+(?:are\s+)?(?:your|the)\s+(?:offline\s+)?(?:features|tools|commands)|how\s+can\s+you\s+help|apa\s+(?:yang\s+)?(?:boleh|bolehkah)\s+(?:saya\s+)?(?:tanya|minta|gunakan)|ciri(?:an)?\s+(?:offline|ofline)|bantuan\s+(?:offline|ofline))\b',
  ).hasMatch(t);
  final help = RegExp(
    r'^(?:help|bantuan|commands?|arahan|apa\s+boleh\s+buat|what\s+can\s+you\s+do)$',
  ).hasMatch(t);
  if (asks || (help && offline) || (offline && asks)) {
    return CapabilitiesIntent(offlineFocused: offline || asks);
  }
  if (offline &&
      RegExp(
        r'\b(?:features?|tools?|commands?|ask|tanya|gunakan|use)\b',
      ).hasMatch(t)) {
    return const CapabilitiesIntent(offlineFocused: true);
  }
  if (help) return const CapabilitiesIntent();
  return null;
}

RoutePreference? _preferenceIn(String t) {
  for (final e in _prefPatterns.entries) {
    if (RegExp('\\b(?:${e.value})\\b').hasMatch(t)) return e.key;
  }
  return null;
}

final _destinationNoise = <RegExp>[
  for (final p in _prefPatterns.values) RegExp('\\b(?:$p)\\b'),
  _startNow,
  _andStart,
  RegExp(
    r'\b(?:from|starting\s+(?:from|at)|dari|bermula\s+(?:dari|di))\s+(?:my\s+|the\s+)?(?:here|sini|current\s+(?:location|position)|my\s+(?:location|position)|lokasi\s+(?:saya|semasa|aku)|kedudukan\s+(?:saya|semasa)|tempat\s+(?:saya|ni|ini))\b',
  ),
  RegExp(
    r'\b(?:now|right\s+now|please|pls|plz|sekarang|tolong|terus|immediately|asap|segera|ya|yah|okay|ok)\b',
  ),
  RegExp(r'\b(?:using|use|guna|melalui|ikut)\s+(?:route|laluan|jalan)\b'),
  RegExp(r'\b(?:route|laluan|the\s+route|the\s+way)\b$'),
];

/// Buang kata pilihan/masa daripada nama destinasi ("klcc tanpa tol sekarang" -> "klcc").
String? _cleanDestination(String raw) {
  var d = raw;
  final via = RegExp(r'\s(?:via|melalui|lalu)\s').firstMatch(d);
  if (via != null) d = d.substring(0, via.start);
  for (final re in _destinationNoise) {
    d = d.replaceAll(re, ' ');
  }
  d = d
      .replaceAll(
        RegExp(r'\b(?:and|dan|with|dengan|but|tapi|using|guna)\s*$'),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  d = d.replaceAll(RegExp(r'^(?:the|a|an|ke|to)\s+'), '').trim();
  if (d.length < 2) return null;
  if (const {
    'sini',
    'here',
    'there',
    'sana',
    'situ',
    'it',
    'itu',
  }.contains(d)) {
    return null;
  }
  return d;
}

String? _placeAfter(String t, RegExp keyword) {
  final m = keyword.firstMatch(t);
  if (m == null) return null;
  final after = t.substring(m.end).trim();
  final connector = RegExp(
    r'^(?:in|at|for|near|around|di|kat|dekat|untuk|sekitar|kawasan)\s+(.+)',
  ).firstMatch(after);
  final bare = RegExp(
    r'^(?:today|now|hari\s+ini|sekarang|esok|tomorrow|tonight|malam\s+ini)?\s*$',
  );
  String? place;
  if (connector != null) {
    place = connector.group(1);
  } else if (after.isNotEmpty && !bare.hasMatch(after)) {
    place = after;
  } else {
    // "kuala terengganu cuaca", "is it raining in ipoh" sudah ditangkap; cuba sebelum kata kunci.
    final before = RegExp(
      r'(?:in|at|di|kat)\s+([a-z0-9 &-]+?)\s*$',
    ).firstMatch(t.substring(0, m.start).trim());
    place = before?.group(1);
  }
  if (place == null) return null;
  place = place
      .replaceAll(
        RegExp(
          r'\b(?:today|now|right\s+now|hari\s+ini|sekarang|esok|tomorrow|tonight|malam\s+ini|macam\s+mana|how\s+is\s+it|like|camne|bagaimana|ke|tak|tidak|please|tolong)\b',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (place.length < 2 ||
      const {
        'sini',
        'here',
        'saya',
        'me',
        'my location',
        'lokasi saya',
      }.contains(place)) {
    return null;
  }
  return place;
}

String? _alongCategory(String t) {
  if (RegExp(
    r'\b(?:r\s*&\s*r|rnr|r\s+and\s+r|rest\s*(?:area|stop|stops)|hentian\s+rehat|kawasan\s+rehat|tempat\s+rehat)\b',
  ).hasMatch(t)) {
    return 'rest_area';
  }
  if (RegExp(
    r'\b(?:ev|charging|charger|chargers|pengecas|cas\s+kereta|ev\s+charging)\b',
  ).hasMatch(t)) {
    return 'ev';
  }
  if (RegExp(
    r'\b(?:petrol|fuel|gas\s+station|minyak|stesen\s+minyak|isi\s+minyak)\b',
  ).hasMatch(t)) {
    return 'fuel';
  }
  if (RegExp(
    r'\b(?:mosque|mosques|masjid|surau|musolla|prayer\s+room)\b',
  ).hasMatch(t)) {
    return 'mosque';
  }
  if (RegExp(
    r'\b(?:toilet|toilets|tandas|restroom|washroom|bathroom)\b',
  ).hasMatch(t)) {
    return 'toilets';
  }
  return null;
}

NearbyCategory? _nearbyCategory(String t) {
  if (RegExp(
    r'\b(?:petrol|fuel|gas\s+station|minyak|stesen\s+minyak|isi\s+minyak)\b',
  ).hasMatch(t)) {
    return NearbyCategory.fuel;
  }
  if (RegExp(
    r'\b(?:mosque|mosques|masjid|surau|musolla|prayer\s+room)\b',
  ).hasMatch(t)) {
    return NearbyCategory.mosque;
  }
  if (RegExp(
    r'\b(?:toilet|toilets|tandas|restroom|washroom|bathroom)\b',
  ).hasMatch(t)) {
    return NearbyCategory.toilets;
  }
  if (RegExp(
    r'\b(?:parking|parkir|letak\s+kereta|tempat\s+letak)\b',
  ).hasMatch(t)) {
    return NearbyCategory.parking;
  }
  if (RegExp(r'\b(?:hospital|klinik|clinic)\b').hasMatch(t)) {
    return NearbyCategory.hospital;
  }
  if (RegExp(
    r'\b(?:food|makan|makanan|restaurant|restoran|kedai\s+makan|cafe|kafe|mamak|eat)\b',
  ).hasMatch(t)) {
    return NearbyCategory.food;
  }
  return null;
}
