import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../domain/place.dart';
import 'fallback_geocoder.dart';
import 'nominatim_geocoder.dart';

abstract interface class Geocoder {
  /// Mencari tempat. [near] memberi keutamaan kepada hasil yang hampir (bukan penapis).
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  });
}

/// Geokod songsang: nama/alamat bagi satu titik (cth. lokasi semasa pengguna).
abstract interface class ReverseGeocoder {
  /// Tempat terdekat pada [point], atau null jika tiada. Titik pada [Place] ialah titik hasil
  /// geokod (alamat terdekat); pemanggil yang mahu mengekalkan titik tepat menggunakan nama sahaja.
  Future<Place?> reverse(GeoPoint point, {CancelToken? cancel});
}

/// Carian tempat melalui Photon awam (komoot). Dasar penggunaan wajar: tiada had keras diterbitkan,
/// tetapi pengguna diminta tidak membanjiri; pemanggil mesti debounce dan membatalkan permintaan lapuk.
class PhotonGeocoder implements Geocoder, ReverseGeocoder {
  PhotonGeocoder(this._dio, this._url, {this.limit = 20});

  final Dio _dio;
  final String _url;
  final int limit;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    try {
      final response = await _dio.get<Object>(
        _url,
        cancelToken: cancel,
        queryParameters: {
          'q': q,
          'limit': limit,
          // Photon hanya menyokong default/en/de/fr/it; "en" memberi nama tempatan jika tiada terjemahan.
          'lang': 'en',
          // Bias lokasi lembut: hasil hampir diutamakan tanpa menyingkirkan yang jauh (bukan `bbox`).
          if (near != null) ...{
            'lat': near.lat,
            'lon': near.lng,
            'zoom': 14,
            'location_bias_scale': 0.35,
          },
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      return parsePhotonResponse(responseText(response.data));
    } on DioException catch (e) {
      throw geocodeFailureOf(e);
    }
  }

  /// Photon: `/reverse?lat=&lon=` (titik akhir berasingan daripada `/api`).
  Uri get _reverseUri {
    final base = Uri.parse(_url);
    var path = base.path.replaceAll(RegExp(r'/+$'), '');
    if (path.endsWith('/api')) path = path.substring(0, path.length - 4);
    return base.replace(path: '$path/reverse', query: '');
  }

  @override
  Future<Place?> reverse(GeoPoint point, {CancelToken? cancel}) async {
    try {
      final response = await _dio.getUri<Object>(
        _reverseUri.replace(
          queryParameters: {
            'lat': '${point.lat}',
            'lon': '${point.lng}',
            'lang': 'en',
            'limit': '1',
          },
        ),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final places = parsePhotonResponse(responseText(response.data));
      return places.isEmpty ? null : places.first;
    } on DioException catch (e) {
      throw geocodeFailureOf(e);
    }
  }
}

GeocodeFailure geocodeFailureOf(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return GeocodeFailure(GeocodeFailureKind.network, e.message);
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      if (status == 429) {
        return const GeocodeFailure(GeocodeFailureKind.rateLimited, 'HTTP 429');
      }
      if (status != null && status >= 500) {
        return GeocodeFailure(GeocodeFailureKind.unavailable, 'HTTP $status');
      }
      return GeocodeFailure(GeocodeFailureKind.generic, 'HTTP $status');
    default:
      return GeocodeFailure(GeocodeFailureKind.generic, e.message);
  }
}

/// Menghurai GeoJSON Photon. Memadam hasil tanpa koordinat sah atau tanpa nama, dan hasil berganda
/// (nama + alamat + titik yang sama).
List<Place> parsePhotonResponse(String? body) {
  if (body == null || body.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const GeocodeFailure(GeocodeFailureKind.generic, 'bukan JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const GeocodeFailure(GeocodeFailureKind.generic, 'bukan objek');
  }
  final features = decoded['features'];
  if (features is! List) return const [];

  final seen = <Place>{};
  final out = <Place>[];
  for (final f in features) {
    final place = _placeOf(f);
    if (place != null && seen.add(place)) out.add(place);
  }
  return out;
}

Place? _placeOf(Object? feature) {
  if (feature is! Map<String, dynamic>) return null;
  final coords = (feature['geometry'] as Map<String, dynamic>?)?['coordinates'];
  if (coords is! List ||
      coords.length < 2 ||
      coords[0] is! num ||
      coords[1] is! num) {
    return null;
  }
  final lng = (coords[0] as num).toDouble();
  final lat = (coords[1] as num).toDouble();
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

  final props = feature['properties'];
  if (props is! Map<String, dynamic>) return null;
  String? s(String key) {
    final v = props[key];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  final street = s('street');
  final house = s('housenumber');
  final streetLine = street == null
      ? null
      : (house == null ? street : '$house $street');
  final name =
      s('name') ??
      streetLine ??
      s('locality') ??
      s('suburb') ??
      s('district') ??
      s('city') ??
      s('county') ??
      s('state');
  if (name == null) return null;

  final subtitleParts = <String>[
    if (s('name') != null) ?streetLine,
    ?s('suburb'),
    ?s('locality'),
    ?s('district'),
    ?s('city'),
    ?s('county'),
    ?s('state'),
    ?s('postcode'),
    ?s('country'),
  ];
  final seen = {name.toLowerCase()};
  final subtitle = subtitleParts
      .where((part) => seen.add(part.toLowerCase()))
      .join(', ');

  return Place(
    name: name,
    subtitle: subtitle,
    point: GeoPoint(lat, lng),
    category: s('osm_value'),
    osmKey: s('osm_key'),
    osmType: _osmType(s('osm_type')),
    osmId: props['osm_id'] is int ? props['osm_id'] as int : null,
    extentDiagonalM: _extentDiagonalM(props['extent']),
    countryCode: s('countrycode')?.toUpperCase(),
  );
}

String? _osmType(String? raw) {
  final t = raw?.toUpperCase();
  return t == 'N' || t == 'W' || t == 'R' ? t : null;
}

/// Pepenjuru kotak sempadan Photon `[barat, utara, timur, selatan]` dalam meter.
double? _extentDiagonalM(Object? extent) {
  if (extent is! List || extent.length < 4 || extent.any((v) => v is! num)) {
    return null;
  }
  final v = extent.cast<num>();
  final d = distanceMeters(
    GeoPoint(v[1].toDouble(), v[0].toDouble()),
    GeoPoint(v[3].toDouble(), v[2].toDouble()),
  );
  return d.isFinite && d > 0 ? d : null;
}

final reverseGeocoderProvider = Provider<ReverseGeocoder>(
  (ref) => PhotonGeocoder(ref.watch(dioProvider), AppConfig.photonUrl),
);

final geocoderProvider = Provider<Geocoder>((ref) {
  final dio = ref.watch(dioProvider);
  return FallbackGeocoder(
    PhotonGeocoder(dio, AppConfig.photonUrl),
    NominatimGeocoder(dio, AppConfig.nominatimUrl),
  );
});
