import 'package:flutter_edge_ai/flutter_edge_ai.dart';

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
    'advice. If the user names a topic without a specific question, give a '
    'short, balanced overview of it. Be direct, friendly and professional: 2-5 '
    'short sentences or a short list. Do not repeat earlier answers, do not '
    'restate the question, never greet or introduce yourself unless the user '
    'greets you, and never ask for confirmation. Answer greetings and chit-chat '
    'from your own knowledge without tools. Use a tool only when the user asks '
    'for a place location, the weather, or facts about a named topic you are '
    'unsure of. Never invent coordinates, prices, weather or times. Never print '
    'tool names, <tool_code> tags, JSON schemas, or "Parameters:" blocks. You '
    'are not a religious authority.';

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
const llmToolNames = {'search_place', 'get_weather', 'wikipedia_summary'};

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
};

bool isKnownAssistantTool(String name) => assistantToolNames.contains(name);

/// Potong jawapan alat supaya konteks telefon tidak membengkak.
String clipToolResult(String text, {int max = 900}) {
  final t = text.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1)}…';
}
