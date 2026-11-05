import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'nlu/intents.dart' show AppScreen;

/// Arahan sistem: pendek (setiap token diproses pada telefon). Arahan peta biasa ("route to X",
/// "start", cuaca, kiblat) dikendalikan oleh kod sebelum model, jadi model kebanyakannya menjawab
/// soalan umum. Konteks semasa (destinasi, laluan) dihantar dalam mesej, bukan di sini, supaya sesi
/// tidak perlu dibina semula.
const assistantSystemPrompt =
    'You are FG AI, the assistant inside the FGMaps navigation app in Malaysia, '
    'developed by Faiz Nasir of FG Universal Empire. You run on the user\'s '
    'phone. Answer ONLY the latest user message, in the language the user '
    'wrote (Bahasa Melayu or English). You can talk about any topic: general '
    'knowledge, history, science, culture, current issues, feelings and '
    'advice. Start with the direct answer in the first sentence, then add 2-4 '
    'short supporting points or steps when useful. If the user names a topic '
    'without a specific question, give a short, balanced overview. Be '
    'friendly and professional. Do not repeat earlier answers, do not restate '
    'the question, never greet or introduce yourself unless the user greets '
    'you, and never ask for confirmation. If you are not sure, say so briefly '
    'instead of guessing. You CAN browse the internet with web_search. For '
    'anything that changes over time (news, prices, who holds an office now, '
    'results, today\'s events), or when asked to browse or search online, '
    'call web_search immediately, never ask which topic first (default to '
    'Malaysia top headlines), and answer from its results, citing them like '
    '[1]. Use other tools only for '
    'a place location or the weather. Never invent coordinates, prices, '
    'weather, dates or times. Never print tool names, <tool_code> tags, JSON '
    'schemas, or "Parameters:" blocks. You are not a religious authority.';

/// Skema alat untuk LiteRT / prompt-based function calling.
List<Tool> assistantTools() => const [
  Tool(
    name: 'search_place',
    description: 'Find a place name and its latitude/longitude in Malaysia.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Place name to search'},
      },
      'required': ['query'],
    },
  ),
  _planRouteTool,
  Tool(
    name: 'get_air_quality',
    description: 'Official JAS IPU at GPS or near a named place.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Optional place; omit for current location',
        },
      },
    },
  ),
  Tool(
    name: 'get_weather',
    description: 'Current weather at GPS or a named place (Open-Meteo).',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Optional place; omit for current location',
        },
      },
    },
  ),
  Tool(
    name: 'get_qibla',
    description: 'Qibla bearing in degrees from current GPS toward the Kaaba.',
    parameters: {'type': 'object', 'properties': {}},
  ),
  Tool(
    name: 'get_prayer_times',
    description: 'Today prayer times and the next prayer.',
    parameters: {'type': 'object', 'properties': {}},
  ),
  Tool(
    name: 'play_radio',
    description: 'Search and play a radio station.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'region': {
          'type': 'string',
          'description': 'malaysia, indonesia, japan, or korea',
        },
      },
      'required': ['query'],
    },
  ),
  Tool(
    name: 'play_music',
    description: 'Search and play a song.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
      },
      'required': ['query'],
    },
  ),
  Tool(
    name: 'list_cameras_along_route',
    description: 'Speed cameras near the active route or preview route.',
    parameters: {'type': 'object', 'properties': {}},
  ),
  Tool(
    name: 'list_along_route',
    description: 'Places along the active or preview route.',
    parameters: {
      'type': 'object',
      'properties': {
        'category': {
          'type': 'string',
          'description': 'rest_area, fuel, ev, mosque, or toilets',
        },
      },
      'required': ['category'],
    },
  ),
  Tool(
    name: 'wikipedia_summary',
    description: 'Short public Wikipedia summary for a general question.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'lang': {
          'type': 'string',
          'description': 'ms or en; default matches the query language',
        },
      },
      'required': ['query'],
    },
  ),
  Tool(
    name: 'web_search',
    description:
        'Browse/search the internet for up-to-date facts and news (today, '
        'latest, current, prices, results). Use an empty query for top '
        'Malaysia headlines. Returns numbered results to cite as [n].',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Search words'},
      },
      'required': ['query'],
    },
  ),
  Tool(
    name: 'app_action',
    description:
        'Operate the FGMaps app on screen for the user (they watch it happen). '
        'Use when the user asks to open or show an app screen.',
    parameters: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description':
              'weather, qibla, air_quality, music, prayer_times, '
              'offline_maps, settings, report, recenter, find_place, '
              'masjid_list (directory of mosques and surau in Malaysia), '
              'highway_cctv (live highway CCTV), or toll_calculator '
              '(official LLM toll rates)',
        },
        'place': {
          'type': 'string',
          'description':
              'Place name for weather or find_place, a state/area for '
              'masjid_list, or a highway name for highway_cctv (optional)',
        },
      },
      'required': ['action'],
    },
  ),
];

const _planRouteTool = Tool(
  name: 'plan_route',
  description:
      'Plan a route from the current location to a destination and pick the '
      'option that matches the preference. Set start=true to begin navigation.',
  parameters: {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': 'Destination place name'},
      'preference': {
        'type': 'string',
        'description':
            'recommended, fastest, shortest, no_tolls, no_highways, cheapest, '
            'or safest',
      },
      'start': {'type': 'boolean'},
    },
    'required': ['query'],
  },
);

/// Alat yang diberi kepada MODEL. Sedikit sahaja: setiap skema ialah token prompt yang diproses
/// pada telefon. Arahan lain (laluan, kiblat, radio, IPU...) dikendalikan oleh penghala arahan.
///
/// `plan_route` sengaja TIADA: model 0.6B memanggilnya untuk soalan yang tiada kaitan (cth. "who are
/// you?" ketika pratonton laluan terbuka) dan jawapan menjadi kad laluan lama. Laluan hanya melalui
/// penghala ([parseIntent]), yang memerlukan destinasi yang jelas.
const llmToolNames = {
  'search_place',
  'get_weather',
  'wikipedia_summary',
  'web_search',
  'app_action',
};

List<Tool> llmAssistantTools() => [
  for (final t in assistantTools())
    if (llmToolNames.contains(t.name)) t,
];

/// Nama alat yang dibenarkan (tolak yang lain).
const assistantToolNames = {
  'search_place',
  'plan_route',
  'get_air_quality',
  'get_weather',
  'get_qibla',
  'get_prayer_times',
  'play_radio',
  'play_music',
  'list_cameras_along_route',
  'list_along_route',
  'wikipedia_summary',
  'web_search',
  'app_action',
};

bool isKnownAssistantTool(String name) => assistantToolNames.contains(name);

/// Potong jawapan alat supaya konteks telefon tidak membengkak.
String clipToolResult(String text, {int max = 900}) {
  final t = text.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1)}…';
}

/// `app_action` -> skrin ejen (null jika tidak dikenali: model tidak boleh mereka aksi).
AppScreen? appScreenForAction(String? action) => switch (action?.trim()) {
  'weather' => AppScreen.weather,
  'qibla' => AppScreen.qibla,
  'air_quality' => AppScreen.airQuality,
  'music' => AppScreen.music,
  'prayer_times' => AppScreen.prayerTimes,
  'offline_maps' => AppScreen.offlineMaps,
  'settings' => AppScreen.settings,
  'report' => AppScreen.report,
  'recenter' => AppScreen.recenter,
  'find_place' => AppScreen.findPlace,
  'masjid_list' => AppScreen.masjidDirectory,
  'highway_cctv' => AppScreen.highwayCctv,
  'toll_calculator' => AppScreen.tollCalculator,
  _ => null,
};
