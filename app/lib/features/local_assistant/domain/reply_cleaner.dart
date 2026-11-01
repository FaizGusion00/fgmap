/// Kemaskan jawapan model kecil sebelum dipaparkan: buang token sesat (cth. "." sebelum panggilan
/// alat), tag sisa, longgokan skema alat (`<tool_code>`, Parameters JSON), dan ayat yang diulang
/// (model 0.6B kerap mengulang ayat yang sama dua kali).
String cleanReply(String raw) {
  var t = raw.replaceAll('\r', '');

  // Blok pemikiran / panggilan alat (tertutup atau tag terbuka tanpa penutup).
  t = t.replaceAll(
    RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
    '',
  );
  t = _stripTaggedBlocks(t, const [
    'tool_code',
    'tool_call',
    'tool_response',
    'function_call',
    'function',
    'tool',
  ]);
  t = t.replaceAll('/no_think', '');

  // Model 0.6B kerap mencetak skema alat sebagai teks biasa di luar tag:
  // "search_place: Find a place... Parameters: { ... }"
  t = _stripToolSchemaDumps(t);
  t = _stripJsonSchemaObjects(t);

  // Baris yang hanya tanda baca ("." atau "…") ialah sisa giliran alat.
  t = t
      .split('\n')
      .where((l) {
        final line = l.trim();
        if (line.isEmpty) return true;
        if (RegExp(r'^[.。…·,;:!?\-–—]+$').hasMatch(line)) return false;
        if (_isToolSchemaResidue(line)) return false;
        return true;
      })
      .join('\n');
  t = t.replaceFirst(RegExp(r'^[\s.。…·,;:!?\-–—]+'), '');

  final paragraphs = t.split(RegExp(r'\n\s*\n'));
  final seen = <String>{};
  final out = <String>[];
  for (final p in paragraphs) {
    final sentences = _sentences(p);
    final kept = <String>[];
    for (final s in sentences) {
      final key = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9À-ɏ؀-ۿ]+'), '');
      if (key.isEmpty) continue;
      if (_isToolSchemaResidue(s)) continue;
      if (!seen.add(key)) continue;
      kept.add(s.startsWith('\n') ? s : s.trim());
    }
    if (kept.isNotEmpty) out.add(_join(kept));
  }
  return out.join('\n\n').trim();
}

/// True jika teks mentah nampak seperti longgokan skema / markup alat (bukan jawapan pengguna).
bool looksLikeToolLeak(String raw) {
  final t = raw.toLowerCase();
  if (t.contains('<tool_code') ||
      t.contains('<tool_call') ||
      t.contains('<function_call') ||
      t.contains('</tool_code>') ||
      t.contains('</tool_call>')) {
    return true;
  }
  if (_toolSchemaHead.hasMatch(raw)) return true;
  if (_jsonSchemaHint.hasMatch(raw)) return true;
  return false;
}

/// Nama alat yang diketahui (untuk padanan longgokan skema).
const _knownToolNames = [
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
];

final _toolNameAlt = _knownToolNames.join('|');

final _toolSchemaHead = RegExp(
  '\\b(?:$_toolNameAlt)\\s*:\\s*[^\\n{]{0,300}?\\bParameters\\s*:',
  caseSensitive: false,
);

final _jsonSchemaHint = RegExp(
  r'"type"\s*:\s*"object"[\s\S]{0,40}"properties"\s*:',
  caseSensitive: false,
);

String _stripTaggedBlocks(String input, List<String> tags) {
  var t = input;
  for (final tag in tags) {
    t = t.replaceAll(
      RegExp('<$tag\\b[^>]*>[\\s\\S]*?</$tag>', caseSensitive: false),
      '',
    );
    t = t.replaceAll(RegExp('</?$tag\\b[^>]*>', caseSensitive: false), '');
  }
  return t;
}

/// Buang `name: description Parameters: { ... }` termasuk objek JSON berkurung seimbang.
String _stripToolSchemaDumps(String input) {
  final buf = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final next = _toolSchemaHead.firstMatch(input.substring(i));
    if (next == null) {
      buf.write(input.substring(i));
      break;
    }
    buf.write(input.substring(i, i + next.start));
    i = _skipJsonObject(input, i + next.end);
  }
  return buf.toString();
}

/// Majukan indeks melepasi objek `{...}` berkurung seimbang (abaikan string).
int _skipJsonObject(String input, int start) {
  var i = start;
  while (i < input.length && input[i].trim().isEmpty) {
    i++;
  }
  if (i >= input.length || input[i] != '{') return i;
  var depth = 0;
  var inString = false;
  var escape = false;
  for (; i < input.length; i++) {
    final c = input[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (c == r'\') {
        escape = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
      continue;
    }
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return input.length;
}

String _stripJsonSchemaObjects(String input) {
  final buf = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final brace = input.indexOf('{', i);
    if (brace < 0) {
      buf.write(input.substring(i));
      break;
    }
    buf.write(input.substring(i, brace));
    final end = _skipJsonObject(input, brace);
    final slice = input.substring(brace, end);
    if (_jsonSchemaHint.hasMatch(slice) ||
        (slice.contains('"type"') &&
            slice.contains('object') &&
            (slice.contains('properties') || slice.contains('required')))) {
      // Buang objek skema.
    } else {
      buf.write(slice);
    }
    i = end;
  }
  return buf.toString();
}

bool _isToolSchemaResidue(String s) {
  final t = s.trim();
  if (t.isEmpty) return true;
  final lower = t.toLowerCase();
  if (RegExp('^(?:$_toolNameAlt)\\b').hasMatch(lower) &&
      (lower.contains('parameters') ||
          lower.contains('"type"') ||
          lower.contains('properties'))) {
    return true;
  }
  if (lower.contains('"type"') &&
      lower.contains('object') &&
      (lower.contains('properties') || lower.contains('required'))) {
    return true;
  }
  if (t.startsWith('{') && t.contains('"type"') && t.contains('object')) {
    return true;
  }
  return false;
}

/// Pecah perenggan kepada ayat sambil mengekalkan baris senarai sebagai unit tersendiri.
List<String> _sentences(String paragraph) {
  final result = <String>[];
  for (final line in paragraph.split('\n')) {
    if (RegExp(r'^\s*(?:[-*•]|\d+[.)])\s').hasMatch(line)) {
      result.add('\n${line.trim()}');
      continue;
    }
    // Ayat bercantum tanpa ruang ("option.KLCC is") juga dipecahkan.
    final parts = line.split(
      RegExp(r'(?<=[.!?])\s*(?=[A-ZÀ-ɏ])|(?<=[.!?])\s+'),
    );
    for (final part in parts) {
      if (part.trim().isNotEmpty) result.add(part.trim());
    }
  }
  return result;
}

String _join(List<String> sentences) {
  final b = StringBuffer();
  var lastWasItem = false;
  for (final s in sentences) {
    final item = s.startsWith('\n');
    if (b.isNotEmpty) b.write(item || lastWasItem ? '\n' : ' ');
    b.write(item ? s.substring(1) : s);
    lastWasItem = item;
  }
  return b.toString();
}
