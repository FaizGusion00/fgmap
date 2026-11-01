/// Pembetulan salah taip untuk kata arahan sahaja (bukan nama tempat).
///
/// Dipanggil sebagai LAPISAN KEDUA: penghala mencuba ayat asal dahulu; hanya jika tiada padanan barulah kata yang
/// hampir dengan perbendaharaan arahan dibetulkan dan ayat diuji semula. Dengan itu nama tempat yang betul tidak
/// pernah diubah.
library;

/// Kata arahan (huruf kecil, panjang >= 5) yang boleh dibetulkan.
const commandVocabulary = <String>{
  // English
  'navigate',
  'navigation',
  'direction',
  'directions',
  'route',
  'nearest',
  'nearby',
  'closest',
  'weather',
  'forecast',
  'petrol',
  'station',
  'mosque',
  'toilet',
  'toilets',
  'restaurant',
  'hospital',
  'parking',
  'location',
  'current',
  'position',
  'prayer',
  'qibla',
  'search',
  'destination',
  'highway',
  'highways',
  'shortest',
  'fastest',
  'safest',
  'cheapest',
  'distance',
  'arrive',
  'arrival',
  'motorcycle',
  'charging',
  'cancel',
  'please',
  'where',
  'there',
  'heading',
  // Melayu
  'laluan',
  'navigasi',
  'cuaca',
  'terdekat',
  'berdekatan',
  'tandas',
  'masjid',
  'minyak',
  'stesen',
  'solat',
  'kiblat',
  'lokasi',
  'pergi',
  'hantar',
  'tolong',
  'sekarang',
  'rumah',
  'pejabat',
  'motosikal',
  'sepanjang',
  'lebuhraya',
  'ramalan',
  'berapa',
  'lagi',
  'sampai',
  'bawa',
};

/// Jarak suntingan Damerau-Levenshtein (transposisi dikira 1).
int editDistance(String a, String b) {
  if (a == b) return 0;
  final n = a.length;
  final m = b.length;
  if (n == 0) return m;
  if (m == 0) return n;
  final d = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        final t = d[i - 2][j - 2] + 1;
        if (t < v) v = t;
      }
      d[i][j] = v;
    }
  }
  return d[n][m];
}

/// Kata arahan terdekat untuk [token], atau null. Huruf pertama mesti sama (taip salah jarang di huruf pertama)
/// dan kata sasaran sekurang-kurangnya 5 huruf supaya nama pendek tidak ditukar.
String? nearestCommandWord(
  String token, {
  Set<String> vocabulary = commandVocabulary,
}) {
  if (token.length < 4 || vocabulary.contains(token)) return null;
  final maxDist = token.length >= 8 ? 2 : 1;
  String? best;
  var bestD = maxDist + 1;
  for (final w in vocabulary) {
    if (w.length < 4 || w.codeUnitAt(0) != token.codeUnitAt(0)) continue;
    if ((w.length - token.length).abs() > maxDist) continue;
    final dist = editDistance(token, w);
    if (dist < bestD) {
      bestD = dist;
      best = w;
    }
  }
  return bestD <= maxDist ? best : null;
}

/// Ayat dengan kata arahan yang dibetulkan; null jika tiada token berubah.
String? fuzzyCorrect(String normalized) {
  var changed = false;
  final out = <String>[];
  for (final w in normalized.split(' ')) {
    final fix = w.length >= 5 ? nearestCommandWord(w) : null;
    if (fix != null) {
      changed = true;
      out.add(fix);
    } else {
      out.add(w);
    }
  }
  return changed ? out.join(' ') : null;
}
