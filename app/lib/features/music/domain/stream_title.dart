/// Membersihkan tajuk aliran ICY (`StreamTitle`, cth. "Spring - Kugapai Cinta") yang dihantar oleh
/// stesen radio supaya boleh dipaparkan sebagai "sedang dimainkan". Banyak stesen menghantar kosong,
/// hanya pemisah, URL, atau mengulang nama stesen semasa iklan dan celahan: semua itu dibuang
/// (null) supaya UI tidak memaparkan sampah.
String? cleanStreamTitle(String? raw, {String? station}) {
  final t = raw?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t == null || t.length < 2) return null;
  if (RegExp(r'^[\s\-|/·.,:]+$').hasMatch(t)) return null;
  if (RegExp(r'^(https?://|www\.)', caseSensitive: false).hasMatch(t)) {
    return null;
  }
  final s = station?.trim().toLowerCase();
  if (s != null && s.isNotEmpty && t.toLowerCase() == s) return null;
  return t;
}
