/// Kemaskan jawapan model kecil sebelum dipaparkan: buang token sesat (cth. "." sebelum panggilan
/// alat), tag sisa, dan ayat yang diulang (model 0.6B kerap mengulang ayat yang sama dua kali).
String cleanReply(String raw) {
  var t = raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
      .replaceAll(RegExp(r'</?(?:think|tool_call|tool_response)>'), '')
      .replaceAll('/no_think', '')
      .replaceAll('\r', '');
  // Baris yang hanya tanda baca ("." atau "…") ialah sisa giliran alat.
  t = t
      .split('\n')
      .where((l) => !RegExp(r'^\s*[.。…·,;:!?\-–—]+\s*$').hasMatch(l))
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
      if (!seen.add(key)) continue;
      kept.add(s.startsWith('\n') ? s : s.trim());
    }
    if (kept.isNotEmpty) out.add(_join(kept));
  }
  return out.join('\n\n').trim();
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
