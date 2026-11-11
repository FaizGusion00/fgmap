/// Penghurai tag kamera OSM (`direction`, `maxspeed`, `enforcement`) dan arah dalam nama.
library;

const _cardinals = <String, double>{
  'N': 0,
  'NNE': 22.5,
  'NE': 45,
  'ENE': 67.5,
  'E': 90,
  'ESE': 112.5,
  'SE': 135,
  'SSE': 157.5,
  'S': 180,
  'SSW': 202.5,
  'SW': 225,
  'WSW': 247.5,
  'W': 270,
  'WNW': 292.5,
  'NW': 315,
  'NNW': 337.5,
};

/// `direction` OSM kepada darjah [0, 360): nombor (termasuk negatif) atau kardinal (N, NE, ...).
///
/// `forward`/`backward`/`both`/`clockwise`, julat (`90;270`) dan nilai lain = null (tidak diketahui,
/// iaitu amaran untuk semua arah).
double? parseOsmDirection(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.isFinite ? _norm(raw.toDouble()) : null;
  final s = raw.toString().trim();
  if (s.isEmpty || s.contains(';')) return null;
  final n = double.tryParse(s);
  if (n != null) return n.isFinite ? _norm(n) : null;
  return _cardinals[s.toUpperCase()];
}

double _norm(double d) => ((d % 360) + 360) % 360;

final _boundPatterns = <(RegExp, String)>[
  (
    RegExp(r'\bnorth\s*bound\b|\(nb\)|\bnb\b|arah utara', caseSensitive: false),
    'NB',
  ),
  (
    RegExp(
      r'\bsouth\s*bound\b|\(sb\)|\bsb\b|arah selatan',
      caseSensitive: false,
    ),
    'SB',
  ),
  (
    RegExp(r'\beast\s*bound\b|\(eb\)|\beb\b|arah timur', caseSensitive: false),
    'EB',
  ),
  (
    RegExp(r'\bwest\s*bound\b|\(wb\)|\bwb\b|arah barat', caseSensitive: false),
    'WB',
  ),
];

/// `NB`/`SB`/`EB`/`WB` daripada teks seperti "AES Taiping - Northbound" atau "KM 185 (SB)".
String? boundFromText(String? text) {
  if (text == null || text.isEmpty) return null;
  for (final (re, bound) in _boundPatterns) {
    if (re.hasMatch(text)) return bound;
  }
  return null;
}

/// `maxspeed` OSM kepada km/j (`110`, `110 km/h`, `50 mph`); nilai tidak munasabah = null.
int? parseMaxspeedKmh(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return _sane(raw.toDouble());
  final m = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*(mph|km/h|kmh|kph)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw.toString());
  if (m == null) return null;
  var v = double.parse(m.group(1)!);
  if ((m.group(2) ?? '').toLowerCase() == 'mph') v *= 1.609344;
  return _sane(v);
}

int? _sane(double v) {
  final r = v.round();
  return r >= 5 && r <= 200 ? r : null;
}

/// Jenis kamera daripada `enforcement` OSM: `red_light` atau `speed`.
String cameraTypeFromEnforcement(String? enforcement) =>
    switch (enforcement?.toLowerCase()) {
      'traffic_signals' || 'red_light_camera' => 'red_light',
      _ => 'speed',
    };
