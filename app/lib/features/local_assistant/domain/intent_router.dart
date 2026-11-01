import 'package:flutter/foundation.dart';

import '../../route_preview/domain/route_preference.dart';
import '../../search/domain/nearby_category.dart';
import 'nlu/fuzzy.dart';
import 'nlu/intents.dart';
import 'nlu/normalizer.dart';

export 'nlu/intents.dart';

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

/// Kata fungsi (bukan nama tempat: "masjid", "minyak", "tandas" dikecualikan kerana muncul dalam nama tempat
/// pada ayat Inggeris) untuk menilai bahasa jawapan.
const _malayFunctionWords = {
  'ke',
  'saya',
  'aku',
  'nak',
  'cari',
  'mana',
  'tolong',
  'boleh',
  'tak',
  'tidak',
  'bawa',
  'hantar',
  'kat',
  'dekat',
  'dan',
  'yang',
  'untuk',
  'berapa',
  'kenapa',
  'macam',
  'jom',
  'elak',
  'apa',
  'bila',
  'sekarang',
  'tanpa',
  'pergi',
  'mula',
  'ini',
  'itu',
  'laluan',
  'jalan',
  'cuaca',
  'waktu',
  'terdekat',
  'dari',
  'dengan',
  'lokasi',
  'beritahu',
  'bagitahu',
  'tunjuk',
  'awak',
  'kamu',
  'sana',
  'situ',
  'ada',
  'lah',
  'kot',
};

const _englishFunctionWords = {
  'the',
  'to',
  'is',
  'what',
  'how',
  'where',
  'me',
  'my',
  'route',
  'please',
  'can',
  'could',
  'you',
  'i',
  'im',
  'near',
  'nearest',
  'find',
  'start',
  'now',
  'and',
  'of',
  'are',
  'why',
  'when',
  'who',
  'tell',
  'about',
  'play',
  'go',
  'going',
  'heading',
  'do',
  'get',
  'there',
  'that',
  'this',
  'current',
  'location',
  'want',
  'need',
  'take',
  'show',
  'navigate',
  'with',
  'for',
  'from',
  'it',
  'in',
  'on',
  'at',
  'am',
  'will',
  'would',
  'should',
};

/// Bahasa jawapan untuk [text]: skor kata fungsi Melayu vs Inggeris. Nama tempat ("masjid", "ke" dalam nama)
/// tidak menjadikan ayat Inggeris sebagai Melayu. Seri/tiada petunjuk -> ikut bahasa UI ([uiMalay]).
bool replyIsMalay(String text, {required bool uiMalay}) {
  final words = normalizeCommand(text).split(' ');
  var malay = 0;
  var english = 0;
  for (final w in words) {
    if (_malayFunctionWords.contains(w)) malay++;
    if (_englishFunctionWords.contains(w)) english++;
  }
  if (malay == english) return uiMalay;
  return malay > english;
}

const _prefPatterns = <RoutePreference, String>{
  RoutePreference.noTolls:
      r'(?:no|without|avoid(?:ing)?|skip)\s+tol(?:l|ls)?|toll[ -]?free|tanpa\s+tol(?:l|ls)?|elak(?:kan)?\s+tol(?:l|ls)?|bebas\s+tol(?:l|ls)?|(?:tak|jangan)\s+(?:nak\s+|mahu\s+)?(?:lalu\s+)?tol(?:l|ls)?|x\s+nak\s+tol(?:l|ls)?',
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

/// Perkataan yang jelas bermaksud "mula" (cukup dengan laluan sedia ada).
const _startExplicit = {
  'start',
  'go',
  'mula',
  'mulakan',
  'jom',
  'gerak',
  'start it',
  'begin',
  'navigate',
  'drive',
  'start please',
  'tolong mula',
  'ok start',
  'okay start',
  'yes start',
  'ya mula',
  'ok go',
  'ok jom',
  'ok mula',
  'go ahead',
  'proceed',
  'teruskan',
};

/// Pengesahan ringkas yang bermaksud "mula" HANYA bila AI baru menawarkannya.
const _startConfirm = {
  'ok',
  'okay',
  'oke',
  'yes',
  'ya',
  'yup',
  'yeah',
  'boleh',
  'sure',
  'baik',
  'baiklah',
  'haah',
  'ok start',
  'okay start',
  'yes start',
  'ya mula',
  'ok go',
  'ok jom',
  'ok mula',
  'go ahead',
  'proceed',
  'teruskan',
  'jom',
  'ya jom',
};

/// "start" sahaja tanpa laluan = tiada apa untuk dimulakan (jawab begitu); "go/navigate/jom" tanpa laluan = tanya destinasi.
const _startVerbOnly = {
  'start',
  'mula',
  'mulakan',
  'begin',
  'start it',
  'start please',
  'tolong mula',
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
      r'\b(?:route|routes|directions?|go|going|head(?:ing)?|driving|travell?ing|walking|riding|how\s+(?:do\s+i|to|can\s+i|should\s+i)\s+(?:get|go|drive|reach)|show\s+(?:me\s+)?(?:the\s+)?(?:route|way))\s+(?:me\s+)?(?:to|towards)\s+(.+)',
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
  (
    re: RegExp(
      r'\bhow\s+(?:do\s+i|to|can\s+i|should\s+i|do\s+we)\s+(?:reach|get\s+to|go\s+to|drive\s+to|find)\s+(.+)',
    ),
    autoStart: false,
  ),
  (
    re: RegExp(
      r'\bmacam\s+mana\s+(?:saya\s+|kita\s+|aku\s+)?(?:nak\s+)?(?:pergi\s+ke|pergi|sampai\s+ke|sampai|ke)\s+(.+)',
    ),
    autoStart: false,
  ),
  (
    re: RegExp(
      r'\b(?:cara|jalan)\s+(?:nak\s+)?(?:pergi\s+ke|pergi|ke|sampai\s+ke)\s+(.+)',
    ),
    autoStart: false,
  ),
];

final _nearbyWords = RegExp(
  r'\b(?:where\s+(?:can|could|do|should)\s+(?:i|we)\s+(?:find|get|eat|park|pray|refuel|fill|charge|buy)|nak\s+(?:makan|isi\s+minyak|letak\s+kereta|buang\s+air)|lapar|hungry|terkucil|nearest|nearby|near\s+me|closest|around\s+me|terdekat|berdekatan|dekat\s+(?:sini|saya|aku)|sekitar\s+sini|paling\s+dekat)\b',
);

final _alongWords = RegExp(
  r'\b(?:along|on\s+the\s+way|on\s+my\s+(?:way|route)|on\s+route|en\s+route|sepanjang|dalam\s+perjalanan|di\s+laluan|tepi\s+laluan|depan\s+nanti|ahead)\b',
);

/// Kenal pasti arahan peta dalam [text]. Null = biar model menjawab.
/// [hasRoute]: pratonton laluan sedang dipaparkan (untuk "start", "tanpa tol"). [context] (jika ada) menggantikannya
/// dan menambah konteks sembang ("ok" hanya bermakna mula bila AI baru menawarkannya).
///
/// Dua lapisan: (1) ayat dipiawaikan (slang/SMS) dan dipadankan; (2) jika tiada padanan, kata arahan yang salah taip
/// dibetulkan dan ayat diuji semula. Nama tempat tidak pernah dibetulkan kerana lapisan 2 hanya berjalan bila lapisan 1
/// gagal sepenuhnya.
AssistantIntent? parseIntent(
  String text, {
  bool hasRoute = false,
  ConversationContext? context,
}) {
  final ctx =
      context ??
      ConversationContext(hasRoute: hasRoute, offeredStart: hasRoute);
  final raw = canonicalizeSlang(normalizeCommand(text));
  if (raw.isEmpty) return null;

  final strict = _restore(_parseCore(raw, ctx));
  if (strict != null) return strict;

  final fixed = fuzzyCorrect(raw);
  if (fixed != null) {
    final second = _restore(_parseCore(fixed, ctx));
    if (second != null) return second;
  }

  // AI baru bertanya "nak ke mana?": jawapan pendek ialah destinasi.
  if (ctx.pendingDestination) {
    final d = _cleanDestination(stripPoliteness(raw));
    if (d != null) return RouteIntent(d.replaceAll('\u0001', ' '));
  }

  return _bareName(text, raw);
}

/// Buang penanda pelindung (`\u0001`) daripada nama destinasi/carian.
AssistantIntent? _restore(AssistantIntent? i) => switch (i) {
  RouteIntent(
    :final destination,
    :final preference,
    :final autoStart,
    :final soft,
  )
      when destination.contains('\u0001') =>
    RouteIntent(
      destination.replaceAll('\u0001', ' '),
      preference: preference,
      autoStart: autoStart,
      soft: soft,
    ),
  SearchIntent(:final query, :final speculative)
      when query.contains('\u0001') =>
    SearchIntent(query.replaceAll('\u0001', ' '), speculative: speculative),
  _ => i,
};

/// Perkataan yang menandakan soalan/perintah umum: teks begini BUKAN nama tempat.
const _notPlaceWords = {
  'what',
  'whats',
  'why',
  'how',
  'who',
  'whom',
  'when',
  'which',
  'where',
  'can',
  'could',
  'would',
  'should',
  'will',
  'shall',
  'do',
  'does',
  'did',
  'is',
  'are',
  'was',
  'were',
  'am',
  'the',
  'a',
  'an',
  'of',
  'to',
  'in',
  'on',
  'at',
  'for',
  'with',
  'and',
  'or',
  'but',
  'my',
  'me',
  'you',
  'your',
  'i',
  'it',
  'this',
  'that',
  'these',
  'those',
  'tell',
  'explain',
  'define',
  'translate',
  'write',
  'give',
  'list',
  'compare',
  'show',
  'make',
  'create',
  'hello',
  'hi',
  'hey',
  'please',
  'help',
  'about',
  'if',
  'not',
  'no',
  'yes',
  'apa',
  'siapa',
  'kenapa',
  'mengapa',
  'bila',
  'bagaimana',
  'macam',
  'mana',
  'boleh',
  'tak',
  'tidak',
  'ada',
  'adakah',
  'itu',
  'ini',
  'yang',
  'untuk',
  'dengan',
  'dan',
  'atau',
  'saya',
  'aku',
  'awak',
  'kamu',
  'tolong',
  'cuba',
  'jelaskan',
  'terangkan',
  'beritahu',
  'bagitahu',
  'kalau',
  'jika',
  'lah',
  'kot',
  'pula',
  'je',
  'sahaja',
  'dah',
  'sudah',
  'belum',
  'nak',
  'mahu',
  'ok',
  'okay',
  'thanks',
  'terima',
  'kasih',
  'berapa',
  'jauh',
  'lama',
  'harga',
  'resepi',
  'cerita',
  'kata',
  'tentang',
  'cara',
  'lawak',
  'bagus',
  'baik',
  'best',
  'good',
  'tips',
  'joke',
  'story',
  'recipe',
  'price',
  'news',
};

/// Nama tempat sahaja ("klcc", "masjid negara", "pavilion kl"): anggap carian tempat. Ketat supaya soalan umum
/// tidak tersalah ditafsir: tiada tanda soal, 1-4 perkataan, tiada kata fungsi.
SearchIntent? _bareName(String original, String canonical) {
  if (original.contains('?')) return null;
  final words = canonical.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty || words.length > 4) return null;
  if (words.any(_notPlaceWords.contains)) return null;
  final q = words.join(' ');
  if (q.length < 3 || RegExp(r'^[\d\s]+$').hasMatch(q)) return null;
  return SearchIntent(q, speculative: true);
}

final _cancelRe = RegExp(
  r'^(?:cancel|stop|end|clear|quit|exit|batal(?:kan)?|henti(?:kan)?|berhenti|tamat(?:kan)?|padam|tak\s+jadi|tak\s+payah|tak\s+perlu|forget\s+it|never\s*mind|nevermind|lupakan)\s*(?:the\s+|this\s+|my\s+)?(?:route|navigation|navigating|nav|trip|journey|drive|driving|laluan|navigasi|perjalanan|jalan)?(?:\s+(?:now|please|lah|la|ya|sekarang))*$',
);

final _ackRe = RegExp(
  r'^(?:ok(?:ay|e)?|k+|kk|sure|noted|fine|baik(?:lah)?|alright|all\s+right|great|nice|good|mantap|best|ya+|yes|yup|yeah|haah|hmm+|got\s+it|faham|dah\s+faham|understood|cool)(?:\s+(?:thanks|thank\s+you|tq|lah|la|bro|boss))*$',
);

final _strongNavStart = RegExp(
  r'^(?:navigate|navigation|bawa|hantar|pandu|take\s+me|bring\s+me|drive\s+me|guide\s+me|route\s+to|directions?\s+to)\b',
);

AssistantIntent? _parseCore(String raw, ConversationContext ctx) {
  // Pelindung: "jalan kampung/lama" selepas penanda destinasi ialah NAMA jalan, bukan pilihan "elak lebuh raya".
  raw = raw.replaceAllMapped(
    RegExp(r'\b(to|ke|towards|menuju|pergi)\s+jalan\s+(kampung|lama)\b'),
    (m) => '${m[1]} jalan\u0001${m[2]}',
  );

  if (_cancelRe.hasMatch(raw)) {
    if (ctx.navActive) return const StopNavigationIntent();
    if (ctx.hasRoute) return const CancelRouteIntent();
    return const ChatIntent(ChatKind.ack);
  }

  final chat = _chatIntent(raw);
  if (chat != null) return chat;

  final capabilities = _capabilitiesIntent(raw);
  if (capabilities != null) return capabilities;

  // Selebihnya dipadankan selepas pembungkus sopan dibuang ("can you tell me ...", "please", "im heading to ...").
  final t = stripPoliteness(raw);
  if (t.isEmpty) return null;
  if (t != raw) {
    if (_cancelRe.hasMatch(t)) {
      if (ctx.navActive) return const StopNavigationIntent();
      if (ctx.hasRoute) return const CancelRouteIntent();
      return const ChatIntent(ChatKind.ack);
    }
    final chat2 = _chatIntent(t);
    if (chat2 != null) return chat2;
  }

  // "ok", "ya", "boleh": hanya bermakna MULA bila AI baru menawarkannya; selain itu pengesahan ringkas.
  if (_startConfirm.contains(t) || _ackRe.hasMatch(t)) {
    if (ctx.hasRoute && ctx.offeredStart && _startConfirm.contains(t)) {
      return const StartNavigationIntent();
    }
    if (!_startExplicit.contains(t)) return const ChatIntent(ChatKind.ack);
  }

  if (_isCurrentLocationQuery(t)) {
    return const CurrentLocationIntent();
  }

  final followUp = _followUpIntent(t);
  if (followUp != null) return followUp;

  // Kawalan app dan soalan perjalanan: perbendaharaan tersendiri, tidak bertindih dengan destinasi.
  final control = _controlIntent(t, ctx);
  if (control != null) return control;

  final saved = _savedPlaceIntent(t);
  if (saved != null) return saved;

  if (ctx.resultCount > 0) {
    final pick = _pickIntent(t);
    if (pick != null) return pick;
  }

  final pref = _preferenceIn(t);
  final startNow = _startNow.hasMatch(t);

  // Cuaca/solat/IPU yang kebetulan mengandungi "going to" ("is it going to rain in klcc") bukan laluan.
  if (!_strongNavStart.hasMatch(t)) {
    final info = _infoIntent(t);
    if (info != null) return info;
  }

  // "how far is klcc", "berapa jauh ke ipoh": destinasi + soalan jarak -> pratonton laluan (ada jarak/masa/tol).
  final distTo = _distanceToPlace.firstMatch(t);
  if (distTo != null) {
    final dest = _cleanDestination(distTo.group(1)!);
    if (dest != null) return RouteIntent(dest, soft: true);
  }

  for (final verb in _routeVerbs) {
    final m = verb.re.firstMatch(t);
    if (m == null) continue;
    final dest = _cleanDestination(m.group(1)!);
    if (dest == null) continue;
    final auto = verb.autoStart || startNow || _andStart.hasMatch(t);
    // "bawa saya ke stesen minyak terdekat", "nak ke tandas": kategori, bukan nama tempat.
    final cat = _nearbyCategory(dest);
    if (cat != null && _isOnlyCategory(dest)) {
      return NearbyIntent(cat, navigate: true, autoStart: auto);
    }
    return RouteIntent(
      dest,
      preference: pref ?? RoutePreference.recommended,
      autoStart: auto,
      soft: RegExp(r'^(?:how|berapa|macam|bagaimana)\b').hasMatch(t),
    );
  }

  if (startNow ||
      (_startExplicit.contains(t) &&
          (ctx.hasRoute || _startVerbOnly.contains(t)))) {
    if (pref != null) {
      return RoutePreferenceIntent(pref, autoStart: true);
    }
    return const StartNavigationIntent();
  }

  // "navigate", "nak pergi", "bawa saya" tanpa destinasi: tanya, jangan serahkan kepada model.
  if (_bareGo.hasMatch(t)) return const AskSlotIntent(AskSlot.destination);

  final along = _alongCategory(t);
  if (along != null &&
      (_alongWords.hasMatch(t) ||
          (ctx.hasRoute &&
              !_nearbyWords.hasMatch(t) &&
              !_searchVerb.hasMatch(t)))) {
    return AlongRouteIntent(along);
  }

  if (pref != null &&
      (ctx.hasRoute ||
          RegExp(
            r'\b(?:route|routes|laluan|jalan|pilih|choose|take|guna|use|ambil|tukar|switch|change)\b',
          ).hasMatch(t))) {
    return RoutePreferenceIntent(pref);
  }

  if (RegExp(r'\b(?:qibla|qiblat|kiblat|kiblah|arah\s+kaabah)\b').hasMatch(t)) {
    return const QiblaIntent();
  }

  final info = _infoIntent(t);
  if (info != null) return info;

  if (RegExp(
    r'^(?:play|mainkan|main|pasang|putar|buka)\s+(?:radio|stesen(?:\s+radio)?)$',
  ).hasMatch(t)) {
    return const AskSlotIntent(AskSlot.radioStation);
  }
  if (RegExp(
    r'^(?:play|mainkan|main|pasang|putar)(?:\s+(?:a\s+)?(?:song|songs|music|lagu|muzik))?$',
  ).hasMatch(t)) {
    return const AskSlotIntent(AskSlot.musicQuery);
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
    // "play era fm", "pasang hitz fm": stesen radio.
    if (RegExp(r'\bfm$|\bradio$').hasMatch(q)) return PlayRadioIntent(q);
    // "play a music", "mainkan lagu": tiada lagu tertentu -> lagu popular.
    final generic = RegExp(
      r'^(?:a|an|some|any|satu|sebuah)?\s*(?:music|musik|muzik|song|songs|lagu|something|anything|sesuatu|apa\s*apa(?:\s+(?:lagu|muzik))?)(?:\s+(?:please|pls|la|lah|for\s+me|untuk\s+saya))?$',
    );
    if (q.isEmpty || generic.hasMatch(q)) return const PlayMusicIntent('');
    return PlayMusicIntent(q);
  }

  final nearby = _nearbyCategory(t);
  if (nearby != null && (_nearbyWords.hasMatch(t) || _searchVerb.hasMatch(t))) {
    final sv = _searchVerb.firstMatch(t);
    // "cari masjid negara", "where is hospital kuala lumpur": nama tempat menang atas kategori.
    if (sv != null && !_nearbyWords.hasMatch(t)) {
      final q = _cleanDestination(sv.group(1)!);
      if (q != null && !_isOnlyCategory(q)) return SearchIntent(q);
    }
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

  final topic = topicOf(t);
  if (topic != null) return TopicIntent(topic);

  return null;
}

final _topicAbout = RegExp(
  r'\b(?:tell|teach|explain|ask|know|learn|share|talk|hear|read|idea|ideas|info|information|cerita(?:kan)?|terang(?:kan)?|jelas(?:kan)?|tanya|tahu|belajar|bincang|maklumat|huraikan)\b.*?\b(?:about|regarding|pasal|tentang|mengenai|berkenaan)\s+(.+)$',
);

final _topicWhat = RegExp(
  r'^(?:(?:what|who)\s+(?:is|was|are|were)|(?:apa(?:kah)?\s+(?:itu|maksud|erti))|(?:siapa(?:kah)?(?:\s+itu)?)|(?:explain|define|terangkan|jelaskan|huraikan))\s+(.+)$',
);

/// Kata yang bukan topik ensiklopedia: diri sendiri, masa sekarang, perkara perjalanan (penghala),
/// atau soalan nasihat/perbandingan ("best way to…", "cara…") yang lebih sesuai dijawab model.
final _notTopic = RegExp(
  r'^(?:you|u|me|it|this|that|yourself|awak|kamu|anda|saya|aku|dia|ini|itu)$|\b(?:my|your|our|saya|aku|awak|kamu|time|date|today|now|masa|jam|pukul|tarikh|hari\s+ini|sekarang|route|routes|toll|tolls|traffic|laluan|tol|jalan\s+sesak|eta|best|way|ways|how|why|should|difference|between|cara|kenapa|mengapa|bagaimana|patut|beza|terbaik)\b',
);

/// Topik ensiklopedia dalam mesej (sudah dinormalkan), atau null.
String? topicOf(String t) {
  final m = _topicAbout.firstMatch(t) ?? _topicWhat.firstMatch(t);
  if (m == null) return null;
  var topic = m.group(1)!.trim();
  topic = topic
      .replaceFirst(
        RegExp(
          r'\s+(?:please|pls|plz|la|lah|sikit|a\s+bit|for\s+me|kepada\s+saya|kat\s+saya|briefly|ringkas)$',
        ),
        '',
      )
      .replaceFirst(RegExp(r'^(?:the|a|an)\s+'), '')
      .trim();
  if (topic.length < 2 || topic.length > 60) return null;
  if (topic.split(' ').length > 6) return null;
  if (_notTopic.hasMatch(topic)) return null;
  return topic;
}

/// Cuaca, IPU, waktu solat.
AssistantIntent? _infoIntent(String t) {
  if (RegExp(
    r'\b(?:waktu\s+(?:solat|sembahyang|azan)|prayer\s+times?|next\s+prayer|solat\s+(?:seterusnya|berikutnya)|azan\s+(?:bila|pukul)|bila\s+(?:masuk\s+)?(?:waktu\s+)?(?:subuh|zohor|zuhur|asar|maghrib|isyak|isya|azan)|(?:dah\s+)?masuk\s+(?:waktu\s+)?(?:subuh|zohor|zuhur|asar|maghrib|isyak|isya)|what\s+time\s+is\s+(?:the\s+)?(?:subuh|zohor|zuhur|asar|maghrib|isyak|isya|fajr|dhuhr|asr|isha)|(?:subuh|zohor|zuhur|asar|maghrib|isyak|isya|fajr|dhuhr|asr|isha)\s+(?:pukul|bila|time|at\s+what))',
  ).hasMatch(t)) {
    return const PrayerTimesIntent();
  }

  final weather = RegExp(
    r'\b(?:weather|cuaca|forecast|ramalan(?:\s+cuaca)?|(?:will\s+it|is\s+it\s+going\s+to|going\s+to)\s+rain|raining|hujan\s+(?:tak|ke|tidak)|nak\s+hujan|akan\s+hujan)\b',
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
  return null;
}

/// "Pergi ke" tanpa apa-apa selepasnya.
final _bareGo = RegExp(
  r'^(?:navigate|navigation|route|directions?|take\s+me|drive|head\s+out|go|bawa\s+(?:saya|aku)|hantar\s+(?:saya|aku)|pandu\s+(?:saya|aku)|nak\s+pergi|mahu\s+pergi|pergi|nak\s+ke|ke|jom|nak\s+gerak|laluan|navigasi|tunjuk(?:kan)?\s+(?:jalan|laluan))(?:\s+(?:to|ke))?$',
);

final _distanceToPlace = RegExp(
  r'^(?:how\s+far\s+(?:is|to)|how\s+far\s+away\s+is|berapa\s+jauh\s+(?:ke|dari\s+sini\s+ke)?|jauh\s+(?:ke|tak\s+ke)|how\s+long\s+(?:to\s+get\s+to|does\s+it\s+take\s+to\s+(?:get\s+to|go\s+to|drive\s+to|reach)|will\s+it\s+take\s+to\s+(?:get\s+to|go\s+to|reach))|berapa\s+lama\s+(?:nak\s+)?(?:pergi\s+)?ke)\s+(.+)',
);

/// Kategori sahaja ("stesen minyak terdekat", "the nearest toilet") tanpa nama tempat.
final _categoryNoise = RegExp(
  r'\b(?:the|a|an|any|some|nearest|nearby|closest|near|me|my|here|around|sini|saya|aku|terdekat|berdekatan|paling|dekat|sekitar|satu|sebuah|yang|station|stesen|pump|pam|kedai|shop|place|tempat|lot|area|di|kat|in|at|for|to|ke|ada|tak|ya|ni|ini)\b',
);

bool _isOnlyCategory(String q) {
  var r = q;
  for (final c in NearbyCategory.values) {
    r = r.replaceAll(_categoryRegex(c), ' ');
  }
  r = r.replaceAll(_categoryNoise, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return r.isEmpty;
}

/// Kawalan app (suara, tema, kenderaan, henti) dan soalan perjalanan.
AssistantIntent? _controlIntent(String t, ConversationContext ctx) {
  // Suara
  if (RegExp(
    r'^(?:mute|silent|silence|diam|senyap(?:kan)?|(?:mute|turn\s+off|switch\s+off|disable)\s+(?:the\s+)?(?:voice|sound|navigation\s+voice|guidance|audio|speaker)|(?:matikan|tutup|off(?:kan)?)\s+(?:suara|bunyi|voice)|stop\s+(?:talking|speaking)|jangan\s+(?:cakap|bercakap)|tak\s+payah\s+cakap)(?:\s+(?:now|please|lah|la|sekarang))*$',
  ).hasMatch(t)) {
    return const VoiceIntent(enabled: false);
  }
  if (RegExp(
    r'^(?:unmute|(?:turn\s+on|switch\s+on|enable)\s+(?:the\s+)?(?:voice|sound|navigation\s+voice|guidance|audio)|(?:hidupkan|buka|on(?:kan)?)\s+(?:suara|bunyi|voice)|speak\s+again|cakap\s+balik)(?:\s+(?:now|please|lah|la|sekarang))*$',
  ).hasMatch(t)) {
    return const VoiceIntent(enabled: true);
  }

  // Tema
  final theme = RegExp(
    r'^(?:(?:tukar|switch|change|set|guna|use|turn\s+on|buka|hidupkan|pakai)\s+(?:to\s+|ke\s+)?)?(?:the\s+)?(?:(dark|gelap|night|malam)|(light|cerah|terang|day|siang)|(auto(?:matic)?|system|sistem))\s+(?:mode|theme|mod|tema)(?:\s+(?:please|lah|la|sekarang|now))*$|^(?:(?:tukar|switch|change|set|guna|use|turn\s+on|buka|pakai)\s+(?:to\s+|ke\s+)?)?(?:mod|mode|tema|theme)\s+(?:(gelap|dark|malam)|(cerah|terang|light|siang)|(auto|sistem|system))(?:\s+(?:please|lah|la|sekarang|now))*$',
  ).firstMatch(t);
  if (theme != null) {
    if (theme.group(1) != null || theme.group(4) != null) {
      return const ThemeIntent(AssistTheme.dark);
    }
    if (theme.group(2) != null || theme.group(5) != null) {
      return const ThemeIntent(AssistTheme.light);
    }
    return const ThemeIntent(AssistTheme.system);
  }

  // Kenderaan
  final vehicle = RegExp(
    r'^(?:(?:tukar|switch|change|set|guna|use|pakai|ganti|naik|ride|drive|i\s+(?:ride|drive|am\s+(?:on|in|riding|driving))|saya\s+(?:naik|bawa|pakai|guna))\s+(?:a\s+|an\s+|the\s+)?(?:to\s+|ke\s+|jadi\s+)?(?:(motosikal|motorcycle|motorbike|motor|bike|skuter|scooter|moto)|(kereta|car|auto|vehicle))|(?:(motosikal|motorcycle|motorbike|motor|bike|moto)|(kereta|car))\s+(?:mode|mod))(?:\s+(?:please|lah|la|sekarang|now))*$',
  ).firstMatch(t);
  if (vehicle != null) {
    final moto = vehicle.group(1) != null || vehicle.group(3) != null;
    return ChangeVehicleIntent(
      moto ? AssistVehicle.motorcycle : AssistVehicle.car,
    );
  }

  // Henti navigasi (cth. "stop navigation" selepas padanan batal tidak berlaku kerana ada perkataan lain)
  if (ctx.navActive &&
      RegExp(
        r"^(?:i\s+(?:want\s+to\s+|wanna\s+)?(?:stop|end|quit)|(?:stop|end|quit|exit|cancel)\s+(?:the\s+)?(?:navigation|navigating|trip|route|driving)|saya\s+(?:nak\s+)?(?:berhenti|henti)|(?:henti|berhenti|tamat|batal)(?:kan)?\s+(?:navigasi|perjalanan|laluan)|dah\s+sampai|dah\s+tiba|i\s+(?:have\s+)?arrived|we\s+(?:have\s+)?arrived)$",
      ).hasMatch(t)) {
    return const StopNavigationIntent();
  }

  // Soalan perjalanan
  const tail = r'(?:\s+(?:now|please|pls|lah|la|ya|again|sekarang))*$';
  bool m(String body) => RegExp('^(?:$body)$tail').hasMatch(t);

  if (m(
    r'how\s+far(?:\s+(?:is\s+it|is\s+that|are\s+we|more|left|to\s+go|again|away|to\s+(?:get\s+)?there|from\s+here|do\s+i\s+(?:have\s+to\s+)?go|still))*|(?:remaining|distance)\s+(?:distance|left)?|distance\s+(?:left|remaining|to\s+go)|how\s+many\s+(?:km|kilometers|kilometres)(?:\s+(?:left|more|to\s+go))?|berapa\s+jauh(?:\s+(?:lagi|nak\s+sampai|sampai|lagi\s+nak\s+sampai|ke\s+sana|dari\s+sini|tu|itu|ni))*|jauh\s+(?:lagi|tak|ke\s+tak)|baki\s+jarak|berapa\s+km(?:\s+lagi)?',
  )) {
    return const TripInfoIntent(TripInfoKind.distance);
  }
  if (m(
    r'how\s+long(?:\s+(?:more|left|until|till|to\s+(?:get\s+there|arrive|go|reach)|will\s+it\s+take|does\s+it\s+take|do\s+we\s+have|is\s+left|is\s+it|again|still|for\s+me))*|how\s+many\s+(?:minutes|mins|hours)(?:\s+(?:left|more|to\s+go))?|(?:time|duration)\s+(?:left|remaining)|remaining\s+time|berapa\s+lama(?:\s+(?:lagi|nak\s+sampai|sampai|lagi\s+nak\s+sampai|perjalanan|tu|itu|ni))*|lama\s+lagi(?:\s+(?:nak\s+sampai|sampai))?|baki\s+masa|berapa\s+(?:minit|jam)(?:\s+lagi)?',
  )) {
    return const TripInfoIntent(TripInfoKind.timeLeft);
  }
  if (m(
    r'(?:what|which)\s+time\s+(?:will|do|am|shall|would)\s+(?:i|we)\s+(?:arrive|get\s+there|reach|be\s+there)(?:\s+there)?|when\s+(?:will|do|shall)\s+(?:i|we)\s+(?:arrive|get\s+there|reach)(?:\s+there)?|when\s+(?:am\s+i|are\s+we)\s+(?:arriving|getting\s+there)|eta|my\s+eta|arrival\s+time|estimated\s+(?:time\s+of\s+)?arrival|pukul\s+berapa\s+(?:saya\s+|kita\s+|aku\s+)?(?:sampai|tiba)|bila\s+(?:saya\s+|kita\s+|aku\s+)?(?:nak\s+)?(?:sampai|tiba)|sampai\s+(?:pukul|jam)\s+berapa|jam\s+berapa\s+(?:saya\s+|kita\s+)?(?:sampai|tiba)|waktu\s+(?:tiba|sampai)',
  )) {
    return const TripInfoIntent(TripInfoKind.arrival);
  }
  if (m(
    r'how\s+much\s+(?:is\s+|are\s+|will\s+|would\s+)?(?:the\s+|my\s+)?(?:toll|tolls)(?:\s+(?:cost|be|charges?|fees?|for\s+(?:this|the)\s+(?:trip|route|journey)|on\s+this\s+route|in\s+total|total))*|(?:toll|tolls)\s+(?:cost|costs|fee|fees|price|charges?|amount|total|for\s+(?:this|the)\s+(?:trip|route))|(?:any|are\s+there|is\s+there|got|have)\s+(?:any\s+)?(?:toll|tolls)(?:\s+(?:on|in|along)\s+(?:this|the)\s+(?:route|way|trip))?|berapa\s+(?:harga\s+|bayaran\s+|kos\s+)?tol(?:\s+(?:semua|kesemuanya|untuk\s+(?:perjalanan|laluan)\s+ini|ni))?|(?:ada|ada\s+ke|ada\s+tak)\s+tol(?:\s+tak|\s+ke)?|tol\s+(?:berapa|ada\s+tak|ada\s+ke)|kos\s+tol|jumlah\s+tol',
  )) {
    return const TripInfoIntent(TripInfoKind.toll);
  }
  if (m(
    r'how\s+much\s+(?:will\s+|would\s+)?(?:petrol|fuel|gas|gasoline)(?:\s+(?:cost|will\s+(?:i|it)\s+(?:use|need|cost|take)|do\s+i\s+need|is\s+needed|for\s+(?:this|the)\s+(?:trip|route|journey)|to\s+get\s+there))*|(?:petrol|fuel|gas)\s+(?:cost|costs|needed|usage|consumption|estimate)(?:\s+for\s+(?:this|the)\s+(?:trip|route|journey))?|(?:trip|fuel|petrol)\s+cost|how\s+much\s+(?:does|will)\s+(?:this|the)\s+trip\s+cost|berapa\s+(?:banyak\s+)?(?:minyak|petrol|duit\s+minyak|belanja\s+minyak)(?:\s+(?:nak\s+guna|diperlukan|perlu|untuk\s+(?:perjalanan|laluan)\s+ini|guna))*|kos\s+(?:minyak|petrol|bahan\s+api|perjalanan)|minyak\s+berapa|belanja\s+minyak',
  )) {
    return const TripInfoIntent(TripInfoKind.fuelCost);
  }
  if (m(
    r'(?:what(?:s|\s+is)\s+)?(?:the\s+)?next\s+(?:turn|instruction|direction|exit|manoeuvre|maneuver)|where\s+(?:do\s+i|should\s+i)\s+turn(?:\s+next)?|repeat(?:\s+(?:that|the\s+(?:last\s+)?(?:instruction|direction)|last\s+instruction))?|say\s+(?:that|it)\s+again|belok\s+(?:mana|apa|bila|kiri\s+ke\s+kanan)(?:\s+(?:lepas\s+ni|seterusnya|nanti|depan))?|simpang\s+(?:mana|seterusnya|depan)|arahan\s+(?:seterusnya|tadi|terakhir)|ulang(?:\s+(?:arahan|tadi|balik))?|lepas\s+ni\s+(?:belok|ke\s+mana)|nak\s+belok\s+mana',
  )) {
    return const TripInfoIntent(TripInfoKind.nextTurn);
  }
  if (m(
    r'(?:what(?:s|\s+is)\s+)?(?:the\s+)?speed\s+limit(?:\s+(?:here|now|on\s+this\s+road))?|what(?:s|\s+is)\s+the\s+limit(?:\s+here)?|how\s+fast\s+(?:can|may|should)\s+i\s+(?:go|drive)(?:\s+here)?|had\s+(?:laju|kelajuan)(?:\s+(?:berapa|kat\s+sini|sini|sekarang))?|berapa\s+had\s+(?:laju|kelajuan)(?:\s+(?:sini|kat\s+sini))?|had\s+laju\s+berapa',
  )) {
    return const TripInfoIntent(TripInfoKind.speedLimit);
  }
  return null;
}

/// "go home", "balik rumah", "bawa saya ke pejabat", "navigate to work".
_SavedPlaceMatch _savedMatch(String t) {
  final words = t.split(' ').where((w) => w.isNotEmpty).toList();
  const filler = {
    'to',
    'ke',
    'back',
    'my',
    'the',
    'me',
    'saya',
    'aku',
    'kita',
    'our',
    'now',
    'sekarang',
    'please',
    'tolong',
    'lah',
    'la',
    'ya',
    'di',
    'at',
    'tempat',
    'kembali',
    'ni',
    'lagi',
    'and',
    'dan',
    'start',
    'mula',
    'terus',
  };
  const navVerbs = {
    'navigate',
    'drive',
    'take',
    'bring',
    'get',
    'guide',
    'bawa',
    'hantar',
    'pandu',
    'balik',
    'pulang',
    'go',
    'head',
    'route',
    'direction',
    'directions',
    'pergi',
    'jom',
    'nak',
    'mahu',
    'hendak',
    'laluan',
    'navigasi',
    'gerak',
    'return',
  };
  var verbs = 0;
  var autoStart = false;
  final rest = <String>[];
  for (final w in words) {
    if (navVerbs.contains(w)) {
      verbs++;
      if (const {
        'navigate',
        'drive',
        'take',
        'bring',
        'bawa',
        'hantar',
        'pandu',
        'balik',
        'pulang',
        'jom',
      }.contains(w)) {
        autoStart = true;
      }
      continue;
    }
    if (filler.contains(w)) continue;
    rest.add(w);
  }
  return _SavedPlaceMatch(rest.join(' '), verbs, autoStart);
}

class _SavedPlaceMatch {
  const _SavedPlaceMatch(this.rest, this.verbs, this.autoStart);

  final String rest;
  final int verbs;
  final bool autoStart;
}

GoSavedPlaceIntent? _savedPlaceIntent(String t) {
  if (t.split(' ').length > 6) return null;
  final m = _savedMatch(t);
  // "balik" sahaja bermakna pulang ke rumah.
  if (m.rest.isEmpty && RegExp(r'\b(?:balik|pulang)\b').hasMatch(t)) {
    return const GoSavedPlaceIntent(SavedSlot.home, autoStart: true);
  }
  const homeWords = {'home', 'rumah', 'umah', 'house', 'kampung halaman'};
  const workWords = {
    'work',
    'office',
    'kerja',
    'pejabat',
    'workplace',
    'ofis',
    'kerja saya',
  };
  if (homeWords.contains(m.rest) && (m.verbs > 0 || t == m.rest)) {
    return GoSavedPlaceIntent(SavedSlot.home, autoStart: m.autoStart);
  }
  if (workWords.contains(m.rest) && m.verbs > 0) {
    return GoSavedPlaceIntent(SavedSlot.work, autoStart: m.autoStart);
  }
  return null;
}

/// "yang pertama", "the second one", "nearest one", "satu lagi".
PickResultIntent? _pickIntent(String t) {
  if (RegExp(
    r'^(?:the\s+|yang\s+)?(?:other|another|next|lain|seterusnya|satu\s+lagi|lagi\s+satu)(?:\s+(?:one|tu|itu|ni|ini))*$',
  ).hasMatch(t)) {
    return const PickResultIntent(0, other: true);
  }
  final m = RegExp(
    r'^(?:(navigate|take\s+me|bring\s+me|go|route|bawa\s+(?:saya|aku)|hantar\s+(?:saya|aku)|pergi|jom)(?:\s+(?:to|ke))?\s+|(?:choose|pick|select|pilih|ambil|guna)\s+)?(?:(?:the|yang|nombor|number|no|option|pilihan)\s+)*(?:(first|1st|one|1|pertama|satu|nearest|closest|terdekat|paling\s+dekat)|(second|2nd|two|2|kedua|dua)|(third|3rd|three|3|ketiga|tiga)|(fourth|4th|four|4|keempat|empat)|(fifth|5th|five|5|kelima|lima)|(other|another|next|lain|seterusnya|satu\s+lagi|lagi\s+satu))(?:\s+(?:one|tu|itu|ni|ini|sekali))*(?:\s+(?:please|lah|la))*$',
  ).firstMatch(t);
  if (m == null) return null;
  final auto = m.group(1) != null;
  for (var i = 2; i <= 6; i++) {
    if (m.group(i) != null) return PickResultIntent(i - 2, autoStart: auto);
  }
  if (m.group(7) != null) {
    return PickResultIntent(0, other: true, autoStart: auto);
  }
  return null;
}

final _searchVerb = RegExp(
  r'^(?:please\s+|tolong\s+)?(?:find|search(?:\s+for)?|look\s+for|locate|cari(?:kan)?|where\s+is|wheres|di\s+mana(?:kah)?|kat\s+mana|mana)\s+(.+)',
);

/// "my current location", "lokasi saya", "where am i", "cari lokasi semasa", "tell me where are my current location".
bool _isCurrentLocationQuery(String t) {
  if (_currentLocationLoose.hasMatch(t)) return true;
  if (RegExp(
    r'^(?:hey\s+|hi\s+|bro\s+)?(?:where\s+(?:am\s+i|are\s+we|i\s+am)(?:\s+(?:now|right\s+now|currently|at\s+the\s+moment))?|wheres\s+my\s+location|what(?:s|\s+is)\s+my\s+(?:current\s+)?(?:location|position|address)|(?:my\s+)?(?:current\s+)?location\s+(?:now|please)|lokasi\s+(?:saya|aku|semasa)(?:\s+sekarang)?|(?:kat|di|dekat)?\s*mana\s+(?:saya|aku|kita)(?:\s+sekarang)?|(?:saya|aku|kita)\s+(?:kat|di|dekat|berada\s+di)\s+mana(?:\s+(?:sekarang|ni|ini))?|(?:saya|aku)\s+sekarang\s+(?:kat|di|dekat)\s+mana|tanya\s+(?:dekat|kat|di)\s+mana\s+sekarang|kedudukan\s+(?:saya|aku|semasa))$',
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

/// Bentuk bersahaja selepas pembungkus sopan dibuang: "where are my current location", "tell me my location",
/// "whats my location now", "saya kat mana sekarang", "kat mana saya ni".
final _currentLocationLoose = RegExp(
  r'^(?:where\s+(?:am\s+i|i\s+am|are\s+we|we\s+are|exactly\s+am\s+i)(?:\s+(?:now|right\s+now|currently|at))?|where\s+(?:is|are)\s+(?:my|our)\s+(?:current\s+)?(?:location|position)|(?:tell|show|give|send)\s+me\s+(?:my|our|the)\s+(?:current\s+)?(?:location|position|address|coordinates)|(?:what(?:s|\s+is)|whats)\s+(?:my|our|the)\s+(?:current\s+)?(?:location|position|address|coordinates)|(?:my\s+)?current\s+(?:location|position)|(?:saya|aku|sy)\s+(?:kat|di|dekat)\s+mana|(?:kat|di|dekat)\s+mana\s+(?:saya|aku|sy)|lokasi\s+(?:saya|aku|semasa)|(?:beritahu|bagitahu|tunjuk(?:kan)?)\s+(?:saya\s+|aku\s+)?lokasi(?:\s+(?:saya|aku|semasa))?)(?:\s+(?:now|please|sekarang|ni|ini|here|semasa|currently))*$',
);

/// Pembungkus sopan/pengenalan di hadapan arahan sebenar. Dibuang berulang (maks 4 kali):
/// "can you please tell me where am i" -> "where am i"; "im heading to klcc" -> "go to klcc".
final _politeRewrites = <(RegExp, String)>[
  (RegExp(r'^(?:hey|hi|hello|hai|ok|okay|so|um|uh|ya|yo|btw|and|but)\s+'), ''),
  (
    RegExp(
      r'^(?:can|could|would|will)\s+(?:you|u|ya)\s+(?:please\s+|pls\s+|kindly\s+)?(?:(?:help|assist)\s+me\s+(?:to\s+|with\s+)?|tell\s+me\s+|show\s+me\s+|let\s+me\s+know\s+|give\s+me\s+)?',
    ),
    '',
  ),
  (
    RegExp(
      r'^(?:please|pls|plz|kindly|tolong|boleh\s+tak|boleh\s+tolong|boleh)\s+',
    ),
    '',
  ),
  (
    RegExp(
      r'^(?:i|we)\s+(?:really\s+)?(?:want|need|wanna|would\s+like|d\s+like|nak|mahu|hendak)\s+(?:to\s+)?',
    ),
    '',
  ),
  (RegExp(r'^(?:saya|aku|sy|kami)\s+(?:nak|mahu|hendak)\s+'), ''),
  (
    RegExp(
      r'^(?:im|i\s+am|ill|i\s+will|we\s+are|were)\s+(?:currently\s+|now\s+)?(?:heading|going|driving|travell?ing|walking|riding|on\s+my\s+way)\s+(?:to|towards)\s+',
    ),
    'go to ',
  ),
  (
    RegExp(
      r'^(?:i|we)\s+(?:am\s+|are\s+)?(?:wanna|gonna|going\s+to)\s+(?:go|drive|head)\s+(?:to|towards)\s+',
    ),
    'go to ',
  ),
];

/// Buang pembungkus sopan supaya corak berjangkar (`^...$`) berfungsi pada ayat bersahaja.
@visibleForTesting
String stripPoliteness(String normalized) {
  var t = normalized.trim();
  for (var i = 0; i < 4; i++) {
    final before = t;
    for (final (re, rewrite) in _politeRewrites) {
      t = t.replaceFirst(re, rewrite).trim();
    }
    if (t == before) break;
  }
  return t;
}

/// Susulan tanpa destinasi: "how do i get there", "how do i do that", "tell me how", "bawa saya ke sana".
RouteFollowUpIntent? _followUpIntent(String t) {
  if (RegExp(
    r'^(?:(?:take|bring|guide|drive)\s+me\s+(?:there|to\s+(?:it|that\s+place|the\s+place))|navigate\s+(?:there|to\s+(?:it|that))|go\s+there|lets\s+go\s+there|bawa\s+(?:saya|aku)\s+(?:ke\s+)?(?:sana|situ)|hantar\s+(?:saya|aku)\s+(?:ke\s+)?(?:sana|situ)|jom\s+(?:ke\s+)?(?:sana|situ)|pergi\s+(?:ke\s+)?(?:sana|situ))$',
  ).hasMatch(t)) {
    return const RouteFollowUpIntent(autoStart: true);
  }
  if (RegExp(
    r'^(?:(?:tell\s+me\s+)?how(?:\s+(?:do\s+i|can\s+i|should\s+i|to|do\s+we))?(?:\s+(?:get|go|reach|drive|do|get\s+to|go\s+to)(?:\s+(?:there|it|that|this|here))?)?|(?:show|give)\s+me\s+(?:the\s+)?(?:route|way|directions?)(?:\s+there)?|(?:route|directions?)\s+(?:there|please)|directions?|macam\s+mana(?:\s+(?:nak|saya\s+nak))?(?:\s+(?:pergi|ke\s+sana|ke\s+situ|buat(?:\s+(?:tu|itu|macam\s+tu)))?)?|camne(?:\s+nak)?(?:\s+pergi)?|tunjuk(?:kan)?\s+(?:jalan|laluan)(?:\s+ke\s+(?:sana|situ))?)(?:\s+(?:please|pls|ya|ok|okay|lah|la))*$',
  ).hasMatch(t)) {
    return const RouteFollowUpIntent();
  }
  return null;
}

bool _isCurrentLocationPhrase(String q) {
  final t = q.trim();
  return RegExp(
    r'^(?:my\s+)?(?:current\s+)?(?:location|position|gps)(?:\s+here)?$|^(?:lokasi|kedudukan)(?:\s+(?:saya|aku|semasa|ini))?$|^(?:my\s+)?(?:lokasi|kedudukan)\s+(?:saya|aku)$',
  ).hasMatch(t);
}

final _identity = RegExp(
  r'\b(?:who\s+(?:are|r)\s+(?:you|u|ya)|what\s+are\s+you|what\s*(?:s|\s+is)\s+your\s+name|your\s+name|introduce\s+yourself|who\s+(?:made|built|created|developed|owns)\s+(?:you|u|this(?:\s+app)?|fg\s*ai)|siapa\s+(?:awak|kamu|anda|engkau|kau|ko|hang|korang)|(?:awak|kamu|anda|kau|ko|hang)\s+(?:ni\s+)?siapa|(?:apa|siapa)\s+nama\s+(?:awak|kamu|anda|kau|ko|hang)|nama\s+(?:awak|kamu|anda|kau|ko)\s+(?:apa|siapa)|perkenalkan\s+diri|siapa\s+(?:yang\s+)?(?:buat|cipta|bina|bangunkan|develop|reka)\s+(?:awak|kamu|anda|kau|app\s+ni|aplikasi\s+ini|fg\s*ai))\b',
);

final _greeting = RegExp(
  r'^(?:hi+|hello+|helo+|hai+|hey+|hye|yo|salam|assalamualaikum|assalamu\s+alaikum|asalamualaikum|selamat\s+(?:pagi|tengah\s+hari|petang|malam)|good\s+(?:morning|afternoon|evening))(?:\s+(?:there|fg\s*ai|ai|bot|bro|boss|semua))?$',
);

final _thanks = RegExp(
  r'^(?:thanks?|thank\s+(?:you|u)|thx|ty|terima\s*kasih|tq|tqvm|tenkiu|thanks\s+a\s+lot)(?:\s+(?:so\s+much|very\s+much|banyak(?:\s+banyak)?|bro|boss|fg\s*ai))?$',
);

final _ping = RegExp(
  r'^(?:(?:can|could)\s+(?:you|u)\s+(?:answer|hear|reply\s+to|respond\s+to)\s+me|(?:are|r)\s+(?:you|u)\s+(?:there|working|alive|ok|okay)|(?:you|u)\s+there|answer\s+me|why\s+(?:are\s+)?(?:you|u)\s+not\s+(?:answering|replying|responding)|boleh\s+(?:jawab|dengar|balas)(?:\s+(?:tak|ke|x|soalan\s+saya))?|(?:awak|kamu|anda)?\s*ada\s+(?:tak|ke|x)|kenapa\s+(?:tak|tidak|x)\s+(?:jawab|balas)|jawab\s+(?:la|lah|soalan\s+saya))$',
);

ChatIntent? _chatIntent(String t) {
  if (_identity.hasMatch(t)) return const ChatIntent(ChatKind.identity);
  if (_greeting.hasMatch(t)) return const ChatIntent(ChatKind.greeting);
  if (_thanks.hasMatch(t)) return const ChatIntent(ChatKind.thanks);
  if (_ping.hasMatch(t)) return const ChatIntent(ChatKind.ping);
  return null;
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

final _destinationQuestionTail = RegExp(
  r'\s+(?:(?:can|could|would|will|do|did)\s+(?:you|u)\b|how\s+(?:do\s+i|do\s+we|to|can\s+i|should\s+i)\b|how$|tell\s+me\b|show\s+me\b|let\s+me\s+know\b|help\s+me\b|macam\s+mana\b|bagaimana\b|camne\b|cmne\b|boleh\s+(?:tak|tolong|awak|bagitahu)\b|tolong\s+(?:bagitahu|tunjuk|beritahu)\b).*$',
);

/// Buang kata pilihan/masa daripada nama destinasi ("klcc tanpa tol sekarang" -> "klcc").
String? _cleanDestination(String raw) {
  var d = raw;
  final via = RegExp(r'\s(?:via|melalui|lalu)\s').firstMatch(d);
  if (via != null) d = d.substring(0, via.start);
  // Ekor soalan/sopan selepas nama tempat: "masjid x can you tell me how", "klcc macam mana", "ipoh boleh tak".
  d = d
      .replaceFirst(_destinationQuestionTail, '')
      .replaceFirst(
        RegExp(
          r'\s+(?:how|ya|yah|eh|lah|la|kan|kot|please|pls|ok|okay|thanks|tq)$',
        ),
        '',
      )
      .trim();
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
    r'^(?:today|now|hari\s+(?:ini|ni)|sekarang|esok|tomorrow|tonight|malam\s+(?:ini|ni))?\s*$',
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
          r'\b(?:today|now|right\s+now|hari\s+ini|hari\s+ni|sekarang|esok|tomorrow|tonight|malam\s+ini|malam\s+ni|macam\s+mana|how\s+is\s+it|like|camne|bagaimana|ke|tak|tidak|please|tolong)\b',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  place = place.replaceFirst(
    RegExp(r'^(?:in|at|for|near|around|di|kat|dekat|untuk|sekitar)\s+'),
    '',
  );
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

final _categoryPatterns = <NearbyCategory, RegExp>{
  NearbyCategory.fuel: RegExp(
    r'\b(?:petrol|fuel|gas\s+station|minyak|stesen\s+minyak|isi\s+minyak)\b',
  ),
  NearbyCategory.mosque: RegExp(
    r'\b(?:mosque|mosques|masjid|surau|musolla|prayer\s+room)\b',
  ),
  NearbyCategory.toilets: RegExp(
    r'\b(?:toilet|toilets|tandas|restroom|washroom|bathroom|buang\s+air|terkucil)\b',
  ),
  NearbyCategory.parking: RegExp(
    r'\b(?:parking|parkir|letak\s+kereta|tempat\s+letak)\b',
  ),
  NearbyCategory.hospital: RegExp(r'\b(?:hospital|klinik|clinic)\b'),
  NearbyCategory.food: RegExp(
    r'\b(?:food|makan|makanan|restaurant|restoran|kedai\s+makan|cafe|kafe|mamak|eat|lapar|hungry)\b',
  ),
};

RegExp _categoryRegex(NearbyCategory c) => _categoryPatterns[c]!;

NearbyCategory? _nearbyCategory(String t) {
  for (final e in _categoryPatterns.entries) {
    if (e.value.hasMatch(t)) return e.key;
  }
  return null;
}
