import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'place.dart';

/// Jenis tempat yang dipaparkan kepada pengguna dan digunakan untuk memberi berat kepada hasil.
enum PlaceKind {
  shopping,
  fuel,
  food,
  worship,
  health,
  parking,
  toilets,
  transit,
  road,
  area,
  address,
  place,
}

PlaceKind placeKindOf(Place place) {
  final key = place.osmKey;
  final value = place.category;
  switch (key) {
    case 'shop':
      return PlaceKind.shopping;
    case 'highway':
      return value == 'bus_stop' || value == 'platform'
          ? PlaceKind.transit
          : PlaceKind.road;
    case 'public_transport' || 'railway':
      return PlaceKind.transit;
    case 'place' || 'boundary':
      return value == 'house' || value == 'plot'
          ? PlaceKind.address
          : PlaceKind.area;
    case 'building':
      return value == 'house' || value == 'residential' || value == 'yes'
          ? PlaceKind.address
          : PlaceKind.place;
  }
  switch (value) {
    case 'fuel':
      return PlaceKind.fuel;
    case 'restaurant' || 'fast_food' || 'cafe' || 'food_court':
      return PlaceKind.food;
    case 'place_of_worship' || 'mosque':
      return PlaceKind.worship;
    case 'hospital' || 'clinic' || 'pharmacy' || 'doctors' || 'dentist':
      return PlaceKind.health;
    case 'parking':
      return PlaceKind.parking;
    case 'toilets':
      return PlaceKind.toilets;
    case 'bus_stop' || 'bus_station' || 'station' || 'halt' || 'platform':
      return PlaceKind.transit;
    case 'mall' || 'supermarket' || 'department_store' || 'convenience':
      return PlaceKind.shopping;
    case 'house' || 'residential' || 'apartments':
      return PlaceKind.address;
  }
  return PlaceKind.place;
}

/// Menyusun semula hasil geocoder supaya tempat yang dimaksudkan pengguna berada di atas.
///
/// Masalah yang diselesaikan: nama yang sama dikongsi oleh kedai dan perhentian bas di
/// seberang jalan ("Lotus Puncak Alam" dan "Lotus Puncak Alam (Opp)"); Photon menyusun mengikut
/// padanan teks sahaja, jadi perhentian bas boleh berada di atas dan menjadi destinasi. Fungsi tulen,
/// menentukan (skor sama mengekalkan susunan asal), tanpa rangkaian.
class PlaceRanker {
  const PlaceRanker();

  /// Kata kunci yang menunjukkan pengguna memang mencari pengangkutan awam.
  static const _transitIntent = {
    'stop',
    'bus',
    'lrt',
    'mrt',
    'ktm',
    'brt',
    'monorail',
    'station',
    'stn',
    'stesen',
    'hentian',
    'terminal',
    'platform',
  };

  /// Perkataan yang menandakan sisi jalan bertentangan.
  static const _oppositeWords = {'opp', 'opposite', 'seberang', 'arah'};

  /// Dua hasil bernama sama dalam jarak ini dianggap satu tempat.
  static const _dedupeRadiusM = 150.0;

  /// Perhentian yang bernama seakan POI sebenar dalam jarak ini dianggap "bayang" POI itu.
  static const _shadowRadiusM = 400.0;

  List<Place> rank(
    List<Place> places,
    String query, {
    GeoPoint? near,
    int maxResults = 10,
  }) {
    if (places.isEmpty) return const [];
    final queryTokens = _tokens(query);
    final wantsTransit = queryTokens.any(_transitIntent.contains);

    final kinds = [for (final p in places) placeKindOf(p)];
    final scored = <_Scored>[];
    for (var i = 0; i < places.length; i++) {
      final place = places[i];
      final kind = kinds[i];
      var score = math.max(0.0, 12 - i * 0.6);
      score += _textScore(place, queryTokens);
      score += _kindWeight(kind, wantsTransit);
      if (place.isArea && place.extentDiagonalM != null) {
        score += math.min(
          6.0,
          math.log(place.extentDiagonalM!) / math.ln10 * 2,
        );
      }
      if (!wantsTransit && isOppositeSide(place.name)) score -= 18;
      if (near != null) {
        final km = distanceMeters(near, place.point) / 1000;
        score -= 3 * math.log(1 + km / 2) / math.ln2;
      }
      scored.add(_Scored(i, place, kind, score));
    }

    if (!wantsTransit) _demoteShadowStops(scored);

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });

    final out = <_Scored>[];
    for (final candidate in scored) {
      final duplicate = out.any(
        (kept) =>
            kept.kind == candidate.kind &&
            _baseName(kept.place.name) == _baseName(candidate.place.name) &&
            distanceMeters(kept.place.point, candidate.place.point) <=
                _dedupeRadiusM,
      );
      if (!duplicate) out.add(candidate);
      if (out.length >= maxResults) break;
    }
    return [for (final s in out) s.place];
  }

  /// Perhentian/platform yang namanya sama atau bermula dengan nama POI sebenar berdekatan
  /// (kedai, pasar raya, hospital...) hampir pasti bukan yang dicari.
  void _demoteShadowStops(List<_Scored> scored) {
    for (final stop in scored.where((s) => s.kind == PlaceKind.transit)) {
      final stopName = _baseName(stop.place.name);
      final shadows = scored.any(
        (poi) =>
            poi.kind != PlaceKind.transit &&
            poi.kind != PlaceKind.road &&
            poi.kind != PlaceKind.area &&
            _namesOverlap(_baseName(poi.place.name), stopName) &&
            distanceMeters(poi.place.point, stop.place.point) <= _shadowRadiusM,
      );
      if (shadows) stop.score -= 12;
    }
  }

  static bool _namesOverlap(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return a.startsWith(b) || b.startsWith(a);
  }

  static double _kindWeight(PlaceKind kind, bool wantsTransit) {
    switch (kind) {
      case PlaceKind.shopping:
      case PlaceKind.fuel:
      case PlaceKind.food:
      case PlaceKind.worship:
      case PlaceKind.health:
      case PlaceKind.place:
        return 14;
      case PlaceKind.area:
        return 8;
      case PlaceKind.parking:
      case PlaceKind.toilets:
      case PlaceKind.address:
        return 6;
      case PlaceKind.road:
        return 4;
      case PlaceKind.transit:
        return wantsTransit ? 20 : -10;
    }
  }

  static double _textScore(Place place, List<String> queryTokens) {
    if (queryTokens.isEmpty) return 0;
    final nameTokens = _tokens(_withoutOpposite(place.name));
    if (nameTokens.isEmpty) return 0;
    final joinedName = nameTokens.join(' ');
    final joinedQuery = queryTokens.join(' ');
    if (joinedName == joinedQuery) return 40;
    if (joinedName.startsWith(joinedQuery)) return 30;
    final allInName = queryTokens.every(
      (q) => nameTokens.any((n) => n.startsWith(q)),
    );
    if (allInName) return 22;
    final haystack = _tokens('${place.name} ${place.subtitle}');
    final allInAddress = queryTokens.every(
      (q) => haystack.any((n) => n.startsWith(q)),
    );
    return allInAddress ? 10 : 0;
  }

  /// Nama menandakan sisi jalan bertentangan, cth. `Lotus Puncak Alam (Opp)`.
  static bool isOppositeSide(String name) =>
      _tokens(name).any(_oppositeWords.contains);

  static String _withoutOpposite(String name) =>
      _tokens(name).where((t) => !_oppositeWords.contains(t)).join(' ');

  static String _baseName(String name) => _withoutOpposite(name);

  /// Huruf kecil, buang diakritik dan tanda baca (`Lotus's` -> `lotuss`), pecah pada ruang.
  static List<String> _tokens(String text) {
    final lower = text.toLowerCase();
    final buf = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(_foldAccent[ch] ?? ch);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r"['’`]"), '')
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static const _foldAccent = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
}

class _Scored {
  _Scored(this.index, this.place, this.kind, this.score);

  final int index;
  final Place place;
  final PlaceKind kind;
  double score;
}
