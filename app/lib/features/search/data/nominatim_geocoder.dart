import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../domain/place.dart';
import 'photon_geocoder.dart';

/// Carian tempat melalui Nominatim (jsonv2). Hanya sebagai FALLBACK Photon: dasar penggunaan Nominatim
/// awam melarang autocomplete, mewajibkan pengenalan app dan had 1 permintaan sesaat, jadi pemanggil
/// ([FallbackGeocoder]) mengawal kadar dan tidak memanggilnya pada setiap ketukan kekunci.
class NominatimGeocoder implements Geocoder {
  NominatimGeocoder(this._dio, this._url, {this.limit = 10});

  final Dio _dio;
  final String _url;
  final int limit;

  /// Separuh sisi kotak keutamaan di sekitar [near], dalam darjah (~0.5 darjah ≈ 55 km).
  static const _biasDegrees = 0.5;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    try {
      final response = await _dio.get<Object>(
        _url,
        cancelToken: cancel,
        queryParameters: {
          'q': q,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': limit,
          'accept-language': 'en',
          // Keutamaan, bukan penapis: `bounded` tidak dihantar.
          if (near != null)
            'viewbox':
                '${near.lng - _biasDegrees},${near.lat + _biasDegrees},'
                '${near.lng + _biasDegrees},${near.lat - _biasDegrees}',
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return parseNominatimResponse(responseText(response.data));
    } on DioException catch (e) {
      throw geocodeFailureOf(e);
    }
  }
}

/// Menghurai tatasusunan jsonv2 Nominatim. Menolak entri tanpa koordinat sah atau tanpa nama.
List<Place> parseNominatimResponse(String? body) {
  if (body == null || body.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const GeocodeFailure(GeocodeFailureKind.generic, 'bukan JSON');
  }
  if (decoded is! List) {
    throw const GeocodeFailure(GeocodeFailureKind.generic, 'bukan senarai');
  }
  final seen = <Place>{};
  final out = <Place>[];
  for (final item in decoded) {
    final place = _placeOf(item);
    if (place != null && seen.add(place)) out.add(place);
  }
  return out;
}

Place? _placeOf(Object? item) {
  if (item is! Map<String, dynamic>) return null;
  final lat = double.tryParse('${item['lat']}');
  final lng = double.tryParse('${item['lon']}');
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  final displayParts = [
    for (final part in (s(item['display_name']) ?? '').split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
  final name =
      s(item['name']) ?? (displayParts.isEmpty ? null : displayParts.first);
  if (name == null) return null;

  final address = item['address'];
  String? a(String key) =>
      address is Map<String, dynamic> ? s(address[key]) : null;
  final structured = <String>[
    ?a('road'),
    ?(a('suburb') ?? a('neighbourhood')),
    ?(a('city') ?? a('town') ?? a('village') ?? a('county')),
    ?a('state'),
    ?a('postcode'),
    ?a('country'),
  ];
  final seen = {name.toLowerCase()};
  final fromAddress = structured
      .where((p) => seen.add(p.toLowerCase()))
      .join(', ');
  final subtitle = fromAddress.isNotEmpty
      ? fromAddress
      : displayParts.skip(1).take(4).join(', ');

  return Place(
    name: name,
    subtitle: subtitle,
    point: GeoPoint(lat, lng),
    category: s(item['type']),
    osmKey: s(item['category']),
    osmType: switch (s(item['osm_type'])) {
      'node' => 'N',
      'way' => 'W',
      'relation' => 'R',
      _ => null,
    },
    osmId: item['osm_id'] is int ? item['osm_id'] as int : null,
    extentDiagonalM: _boundingBoxDiagonalM(item['boundingbox']),
    countryCode: a('country_code')?.toUpperCase(),
  );
}

/// Nominatim: `[selatan, utara, barat, timur]` sebagai rentetan.
double? _boundingBoxDiagonalM(Object? box) {
  if (box is! List || box.length < 4) return null;
  final v = [for (final e in box) double.tryParse('$e')];
  if (v.any((e) => e == null)) return null;
  final d = distanceMeters(GeoPoint(v[1]!, v[2]!), GeoPoint(v[0]!, v[3]!));
  return d.isFinite && d > 0 ? d : null;
}
