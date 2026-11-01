/// Pengembangan pertanyaan MY: singkatan jalan + nama landasan lazim → bentuk yang
/// indeks OSM/offline/Photon lebih kerap padankan.
///
/// Bukan Google Places. Alias landasan ialah nama awam / OSM; lihat juga
/// `tools/places/extra/landmarks_my.geojson` (medan `alt` dalam pek).
library;

/// Singkatan token → bentuk penuh pilihan pertama (untuk Photon/Nominatim).
const abbreviationExpansion = <String, String>{
  'jln': 'jalan',
  'tmn': 'taman',
  'lrg': 'lorong',
  'psn': 'persiaran',
  'kg': 'kampung',
  'bt': 'bukit',
  'stn': 'stesen',
  'hosp': 'hospital',
  'uni': 'universiti',
  'univ': 'universiti',
  'uitm': 'uitm',
  'klia': 'klia',
};

/// Frasa landasan (huruf kecil) → pertanyaan carian yang lebih kaya.
/// Kunci dipadankan sebagai frasa penuh selepas trim.
const landmarkQueryRewrite = <String, String>{
  'klcc': 'Suria KLCC',
  'suria klcc': 'Suria KLCC',
  'twin towers': 'Petronas Twin Towers',
  'petronas twin towers': 'Petronas Twin Towers',
  'menara berkembar petronas': 'Petronas Twin Towers',
  'pavilion': 'Pavilion Kuala Lumpur',
  'pavilion kl': 'Pavilion Kuala Lumpur',
  'pavilion kuala lumpur': 'Pavilion Kuala Lumpur',
  'mid valley': 'Mid Valley Megamall',
  'midvalley': 'Mid Valley Megamall',
  '1 utama': '1 Utama',
  'one utama': '1 Utama',
  'sunway pyramid': 'Sunway Pyramid',
  'kl sentral': 'KL Sentral',
  'kuala lumpur sentral': 'KL Sentral',
  'uitm': 'UiTM Shah Alam',
  'uitm shah alam': 'UiTM Shah Alam',
  'universiti teknologi mara': 'UiTM Shah Alam',
  'um': 'Universiti Malaya',
  'universiti malaya': 'Universiti Malaya',
  'ukm': 'Universiti Kebangsaan Malaysia',
  'upm': 'Universiti Putra Malaysia',
  'usm': 'Universiti Sains Malaysia',
  'utm': 'Universiti Teknologi Malaysia',
  'iium': 'International Islamic University Malaysia',
  'uia': 'International Islamic University Malaysia',
  'klia': 'KLIA',
  'klia2': 'KLIA2',
  'klia 2': 'KLIA2',
  'batu caves': 'Batu Caves',
  'genting': 'Genting Highlands',
  'genting highland': 'Genting Highlands',
  'genting highlands': 'Genting Highlands',
};

/// Alias FTS tambahan (digabung ke `offline_place._ftsTokenAliases`).
const extraFtsTokenAliases = <String, List<String>>{
  'univ': ['universiti', 'university', 'univ', 'uni'],
  'rd': ['road', 'jalan', 'rd'],
  'road': ['road', 'jalan', 'rd'],
  'ave': ['avenue', 'avenues', 'ave'],
  'dr': ['drive', 'dr'],
  'hwy': ['highway', 'lebuhraya', 'hwy'],
  'lebuhraya': ['lebuhraya', 'highway', 'hwy'],
  'hsptl': ['hospital', 'hosp', 'hsptl'],
  'klinik': ['klinik', 'clinic'],
  'clinic': ['klinik', 'clinic'],
  'petrol': ['petrol', 'fuel', 'minyak'],
  'minyak': ['minyak', 'fuel', 'petrol'],
  'fuel': ['fuel', 'petrol', 'minyak'],
  'ev': ['ev', 'charging'],
  'charging': ['charging', 'ev'],
};

/// Pulangkan pertanyaan untuk geocoder dalam talian (satu rentetan).
String expandPlaceQuery(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final landmark = landmarkQueryRewrite[lower];
  if (landmark != null) return landmark;

  // Kembangkan singkatan hanya jika ada token yang dikenali; jangan pecahkan
  // apostrof (McDonald's) atau ubah huruf besar bila tiada singkatan.
  final parts = trimmed
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (parts.isEmpty) return trimmed;
  final needsExpand = parts.any(
    (t) => abbreviationExpansion.containsKey(t.toLowerCase()),
  );
  if (!needsExpand) return trimmed;
  return [
    for (final t in parts) abbreviationExpansion[t.toLowerCase()] ?? t,
  ].join(' ');
}

/// Varian tambahan untuk digabung (landasan): kosong jika tiada.
List<String> landmarkSearchVariants(String raw) {
  final lower = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (lower.isEmpty) return const [];
  final rewritten = landmarkQueryRewrite[lower];
  if (rewritten == null) return const [];
  // Sertakan kunci asal + bentuk kanonik supaya "klcc" masih padan nama pendek OSM.
  return {raw.trim(), rewritten}.toList();
}
