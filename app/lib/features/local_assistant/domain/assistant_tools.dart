import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Nama fail model Qwen3 0.6B (dynamic INT4) yang dimuat turun.
const assistantModelId = 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';

const assistantModelUrl =
    'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
    'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';

/// Arahan sistem: sembang umum + alat FGMaps; fakta hidup hanya dari alat.
const assistantSystemPrompt =
    'You are FGMaps AI, a helpful on-device assistant. Reply in the user\'s '
    'language (Bahasa Melayu or English). Answer general questions clearly and '
    'briefly. For maps and live facts (places, routes, IPU air quality, weather, '
    'qibla, prayer times, radio, music, speed cameras, places along the route, '
    'Wikipedia), call tools — never invent coordinates, IPU, weather, or prayer '
    'times. If a tool fails, say you do not know. Keep answers short while '
    'driving. Planning a route opens a preview; the user taps Start to drive. '
    'You are not a religious authority; for Islamic rulings, suggest FGMuslim AI '
    'if the user enabled it.';

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
  Tool(
    name: 'plan_route',
    description:
        'Search a destination and open the route preview. Optionally prefer '
        'toll-free or non-highway options when available.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Destination place name'},
        'avoid_tolls': {'type': 'boolean'},
        'avoid_highways': {'type': 'boolean'},
      },
      'required': ['query'],
    },
  ),
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
