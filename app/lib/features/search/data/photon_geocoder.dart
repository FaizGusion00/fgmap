import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../domain/place.dart';

/// Kotak sempadan Malaysia (barat, selatan, timur, utara) supaya hasil dihadkan kepada Malaysia
/// (cukup luas untuk Semenanjung, Sabah dan Sarawak; sedikit termasuk Singapura dan Brunei, yang
/// juga dalam data peta).
const malaysiaBbox = '99.6,0.8,119.3,7.4';

abstract interface class Geocoder {
  /// Mencari tempat. [near] memberi keutamaan kepada hasil yang hampir (bukan penapis).
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  });
}

/// Carian tempat melalui Photon awam (komoot). Dasar penggunaan wajar: tiada had keras diterbitkan,
/// tetapi pengguna diminta tidak membanjiri; pemanggil mesti debounce dan membatalkan permintaan lapuk.
class PhotonGeocoder implements Geocoder {
  PhotonGeocoder(this._dio, this._url, {this.limit = 8});

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
          'bbox': malaysiaBbox,
          if (near != null) ...{'lat': near.lat, 'lon': near.lng},
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      return parsePhotonResponse(responseText(response.data));
    } on DioException catch (e) {
      throw _failure(e);
    }
  }
}

GeocodeFailure _failure(DioException e) {
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
  final name = s('name') ?? streetLine;
  if (name == null) return null;

  final subtitle = <String>[
    // Jalan hanya jika nama bukan jalan itu sendiri.
    if (s('name') != null && streetLine != null) streetLine,
    ?s('district'),
    ?s('city'),
    ?s('state'),
  ].where((p) => p != name).toSet().join(', ');

  return Place(
    name: name,
    subtitle: subtitle,
    point: GeoPoint(lat, lng),
    category: s('osm_value'),
  );
}

final geocoderProvider = Provider<Geocoder>(
  (ref) => PhotonGeocoder(ref.watch(dioProvider), AppConfig.photonUrl),
);
