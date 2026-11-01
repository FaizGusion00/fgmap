import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Nama fail model Qwen3 0.6B (dynamic INT4) yang dimuat turun.
const assistantModelId = 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';

const assistantModelUrl =
    'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
    'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';

/// Arahan sistem: pendek (setiap token diproses pada telefon). Arahan peta biasa ("route to X",
/// "start", cuaca, kiblat) dikendalikan oleh kod sebelum model, jadi model kebanyakannya menjawab
/// soalan umum. Konteks semasa (destinasi, laluan) dihantar dalam mesej, bukan di sini, supaya sesi
/// tidak perlu dibina semula.
const assistantSystemPrompt =
    'You are FG AI, a friendly, professional assistant inside the FGMaps app in '
    'Malaysia. Always answer ONLY the latest user message, in the same language '
    'the user wrote (Bahasa Melayu or English). Be direct and natural: 1-4 short '
    'sentences or a short list. Do not repeat earlier answers, do not restate the '
    'question, and never ask for confirmation of something the user already asked '
    'for. Use tools for live facts (places, routes, weather, Wikipedia); never '
    'invent coordinates, prices, weather or times. If a tool fails, say so '
    'briefly. Never print tool names, <tool_code> tags, JSON schemas, or '
    '"Parameters:" blocks — call tools silently or answer in plain language. '
    'You are not a religious authority.';

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
/// pada telefon. Arahan lain (kiblat, radio, IPU...) dikendalikan oleh penghala arahan.
List<Tool> llmAssistantTools() => [
  for (final t in assistantTools())
    if (const {
      'search_place',
      'plan_route',
      'get_weather',
      'wikipedia_summary',
    }.contains(t.name))
      t,
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
