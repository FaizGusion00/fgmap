import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../domain/entrance.dart';

/// Awalan kunci cache pintu masuk OSM (mengandungi destinasi yang pernah dicari); dipadam oleh
/// "Padam semua data saya".
const entranceCachePrefix = 'doorstep.osm.v1:';

/// Pintu masuk OSM di sekitar destinasi (Overpass), dengan cache pada telefon: pintu jarang berubah, jadi
/// destinasi yang pernah dicari muncul serta-merta dan juga tanpa internet.
///
/// Bangunan dalam 60 m turut diambil (bergeometri); bangunan yang MENGANDUNGI pin dikenal pasti dalam app
/// (bukan `is_in` Overpass, yang berat), supaya pintu bangunan destinasi itu sendiri didahulukan.
class OsmEntranceSearch {
  OsmEntranceSearch(this._dio, this._mirrors, {this._prefs});

  final Dio _dio;
  final List<String> _mirrors;
  final SharedPreferences? _prefs;
  final Map<String, List<Entrance>> _cache = {};

  static const radiusM = 200;
  static const cacheTtl = Duration(days: 30);

  static String queryFor(GeoPoint p) {
    final at = '${p.lat.toStringAsFixed(6)},${p.lng.toStringAsFixed(6)}';
    final around = 'around:$radiusM,$at';
    return '[out:json][timeout:25];'
        'way(around:60,$at)["building"]->.b;.b out geom 6;'
        '('
        'node($around)["entrance"];'
        'node($around)["barrier"~"^(gate|lift_gate|sliding_gate|swing_gate|entrance)\$"];'
        'node($around)["amenity"~"^(parking_entrance|loading_dock)\$"];'
        'way($around)["building"="guardhouse"];'
        ');out center tags 150;';
  }

  static String _key(GeoPoint p) =>
      '$entranceCachePrefix${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}';

  /// Pintu masuk berhampiran [place]. Null = tiada cache dan semua cermin gagal (pemanggil boleh cuba lagi).
  Future<List<Entrance>?> near(GeoPoint place, {DateTime? now}) async {
    final key = _key(place);
    final mem = _cache[key];
    if (mem != null) return mem;
    final disk = _readDisk(key, now ?? DateTime.now());
    if (disk != null) return _cache[key] = disk;
    // Tiada cermin = carian dimatikan (bukan kegagalan yang patut dicuba semula).
    if (_mirrors.isEmpty) return const [];
    for (final mirror in _mirrors) {
      try {
        final response = await _dio.post<Object>(
          mirror,
          data: 'data=${Uri.encodeQueryComponent(queryFor(place))}',
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.bytes,
            // Overpass awam boleh lambat: bahagian pintu muncul bila siap, laluan tidak menunggu.
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        final found = parseEntrances(responseText(response.data), place: place);
        await _writeDisk(key, found, now ?? DateTime.now());
        return _cache[key] = found;
      } on DioException catch (e) {
        logDiag('Pintu masuk: ${e.type}');
      } on FormatException catch (e) {
        logDiag('Pintu masuk: $e');
      }
    }
    return null;
  }

  List<Entrance>? _readDisk(String key, DateTime now) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return null;
      final at = j['at'];
      final list = j['e'];
      if (at is! int || list is! List) return null;
      if (now.difference(DateTime.fromMillisecondsSinceEpoch(at)) > cacheTtl) {
        return null;
      }
      return [for (final e in list) ?_entranceFromJson(e)];
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeDisk(String key, List<Entrance> list, DateTime now) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      key,
      jsonEncode({
        'at': now.millisecondsSinceEpoch,
        'e': [for (final e in list) _entranceToJson(e)],
      }),
    );
  }
}

Map<String, Object?> _entranceToJson(Entrance e) => {
  'lat': e.point.lat,
  'lng': e.point.lng,
  'k': e.kind.name,
  if (e.detail != null) 'd': e.detail,
  if (e.onBuilding) 'b': true,
};

Entrance? _entranceFromJson(Object? j) {
  if (j is! Map<String, dynamic>) return null;
  final lat = j['lat'], lng = j['lng'];
  final kind = EntranceKind.values.where((k) => k.name == j['k']).firstOrNull;
  if (lat is! num || lng is! num || kind == null) return null;
  return Entrance(
    point: GeoPoint(lat.toDouble(), lng.toDouble()),
    kind: kind,
    detail: j['d'] is String ? j['d'] as String : null,
    onBuilding: j['b'] == true,
  );
}

/// Titik [p] di dalam poligon [ring] (ray casting; cukup tepat untuk bangunan).
bool _inside(GeoPoint p, List<GeoPoint> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i], b = ring[j];
    if ((a.lat > p.lat) != (b.lat > p.lat) &&
        p.lng < (b.lng - a.lng) * (p.lat - a.lat) / (b.lat - a.lat) + a.lng) {
      inside = !inside;
    }
  }
  return inside;
}

/// Menghurai respons Overpass. Jalan bangunan (bergeometri) yang mengandungi [place] menandakan pintu pada
/// garis luarnya sebagai `onBuilding`; nod/jalan lain diklasifikasikan dengan [classifyEntrance]. Badan
/// rosak -> [FormatException].
List<Entrance> parseEntrances(String? body, {GeoPoint? place}) {
  if (body == null || body.isEmpty) throw const FormatException('kosong');
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('bukan objek');
  }
  final elements = decoded['elements'];
  if (elements is! List) return const [];

  final buildings = <List<GeoPoint>>[];
  final out = <Entrance>[];
  for (final e in elements) {
    if (e is! Map<String, dynamic>) continue;
    final geom = e['geometry'];
    if (e['type'] == 'way' && geom is List) {
      buildings.add([
        for (final g in geom)
          if (g is Map<String, dynamic> && g['lat'] is num && g['lon'] is num)
            GeoPoint(
              (g['lat'] as num).toDouble(),
              (g['lon'] as num).toDouble(),
            ),
      ]);
      continue;
    }
    final rawTags = e['tags'];
    if (rawTags is! Map<String, dynamic>) continue;
    final tags = {
      for (final t in rawTags.entries)
        if (t.value is String) t.key: t.value as String,
    };
    final kind = classifyEntrance(tags);
    if (kind == null) continue;
    final center = e['center'];
    final lat = e['lat'] ?? (center is Map ? center['lat'] : null);
    final lon = e['lon'] ?? (center is Map ? center['lon'] : null);
    if (lat is! num || lon is! num) continue;
    out.add(
      Entrance(
        point: GeoPoint(lat.toDouble(), lon.toDouble()),
        kind: kind,
        detail: entranceDetail(tags),
      ),
    );
  }
  // Bangunan destinasi: yang mengandungi pin; tanpa pin (atau tiada), tiada penandaan.
  final outline = place == null
      ? const <GeoPoint>[]
      : buildings
                .where((b) => b.length >= 4 && _inside(place, b))
                .firstOrNull ??
            const <GeoPoint>[];
  if (outline.isEmpty) return out;
  return [
    for (final e in out)
      outline.any((v) => distanceMeters(v, e.point) < 2)
          ? e.copyWith(onBuilding: true)
          : e,
  ];
}

final osmEntranceSearchProvider = Provider<OsmEntranceSearch>(
  (ref) => OsmEntranceSearch(
    ref.watch(dioProvider),
    AppConfig.overpassUrls,
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);
