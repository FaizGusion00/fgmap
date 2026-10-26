import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../domain/nearby_category.dart';
import '../domain/place.dart';
import 'nearby_cache.dart';
import 'nominatim_geocoder.dart';
import 'photon_geocoder.dart';

/// Hasil carian berhampiran. [cachedAt] bukan null apabila pelayan tidak dapat dicapai dan senarai
/// ini ialah simpanan lama dalam peranti.
class NearbyResult {
  const NearbyResult(this.places, {this.cachedAt});

  final List<Place> places;
  final DateTime? cachedAt;

  bool get fromCache => cachedAt != null;
}

/// Mencari tempat mengikut KATEGORI di sekitar satu titik (stesen minyak, makan, surau...).
abstract interface class NearbySearch {
  /// Hasil tersusun dari yang paling dekat. [fallbackName] dipakai untuk tempat tanpa nama dalam OSM
  /// (cth. tandas atau parkir awam).
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  });
}

/// Overpass API (data OSM, percuma tanpa kunci). Dasar penggunaan awam: kurang 10,000 pertanyaan sehari
/// dan UA berpengenalan; satu permintaan pada satu masa (tiada selari) dan jatuh ke cermin seterusnya
/// hanya apabila yang pertama gagal. Cermin yang terakhir berjaya dicuba dahulu pada carian seterusnya.
/// Radius diperluas berperingkat ([NearbyCategory.radiiM]) hanya jika hasil belum mencukupi.
class OverpassNearbySearch implements NearbySearch {
  OverpassNearbySearch(
    this._dio,
    this._mirrors, {
    this.deadline = const Duration(seconds: 20),
    Stopwatch Function()? stopwatch,
  }) : _newStopwatch = stopwatch ?? Stopwatch.new;

  final Dio _dio;
  final List<String> _mirrors;

  /// Jumlah masa maksimum mencuba cermin untuk satu peringkat radius; selepas ini dianggap gagal.
  final Duration deadline;
  final Stopwatch Function() _newStopwatch;

  int _preferred = 0;

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    var places = const <Place>[];
    GeocodeFailure? widenFailure;
    for (var i = 0; i < category.radiiM.length; i++) {
      try {
        places = await _query(
          category,
          center,
          category.radiiM[i],
          fallbackName,
          cancel,
        );
      } on GeocodeFailure catch (f) {
        // Peringkat pertama gagal = gagal. Peringkat lebih luas gagal: kekalkan apa yang sudah ada.
        if (i == 0) rethrow;
        widenFailure = f;
        break;
      }
      if (places.length >= category.enoughResults) break;
    }
    if (places.isEmpty && widenFailure != null) throw widenFailure;
    return NearbyResult(places);
  }

  Future<List<Place>> _query(
    NearbyCategory category,
    GeoPoint center,
    int radius,
    String fallbackName,
    CancelToken? cancel,
  ) async {
    final watch = _newStopwatch()..start();
    GeocodeFailure? last;
    for (var n = 0; n < _mirrors.length; n++) {
      if (n > 0 && watch.elapsed >= deadline) break;
      final index = (_preferred + n) % _mirrors.length;
      try {
        final response = await _dio.get<Object>(
          _mirrors[index],
          cancelToken: cancel,
          queryParameters: {
            'data': category.overpassQuery(center.lat, center.lng, radius),
          },
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final places = parseOverpassResponse(
          responseText(response.data),
          center: center,
          fallbackName: fallbackName,
        );
        _preferred = index;
        return places;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        last = geocodeFailureOf(e);
      } on GeocodeFailure catch (f) {
        last = f;
      }
    }
    throw last ??
        const GeocodeFailure(GeocodeFailureKind.unavailable, 'tiada cermin');
  }
}

/// Nominatim "frasa khas" dengan `bounded=1` sebagai fallback apabila semua cermin Overpass gagal.
class NominatimNearbySearch implements NearbySearch {
  NominatimNearbySearch(this._dio, this._url);

  final Dio _dio;
  final String _url;

  /// Separuh sisi kotak (darjah); ~0.08 darjah ≈ 9 km.
  static const _halfDegrees = 0.08;

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    final found = <Place>[];
    GeocodeFailure? failure;
    for (final phrase in category.nominatimPhrases) {
      try {
        final response = await _dio.get<Object>(
          _url,
          cancelToken: cancel,
          queryParameters: {
            'q': phrase,
            'format': 'jsonv2',
            'addressdetails': 1,
            'limit': 40,
            'accept-language': 'en',
            'bounded': 1,
            'viewbox':
                '${center.lng - _halfDegrees},${center.lat + _halfDegrees},'
                '${center.lng + _halfDegrees},${center.lat - _halfDegrees}',
          },
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        found.addAll(
          parseNominatimResponse(
            responseText(response.data),
          ).where((p) => category.acceptsNominatim(p.osmKey, p.category)),
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        failure = geocodeFailureOf(e);
        break;
      }
    }
    // Satu frasa gagal tetapi yang lain berjaya: pulangkan apa yang ada. Semua gagal: lapor gagal.
    if (found.isEmpty && failure != null) throw failure;
    return NearbyResult(sortNearby(found, center));
  }
}

/// Overpass dahulu; jika semua cermin gagal, Nominatim. Kosong daripada Overpass ialah jawapan sah
/// (tiada tempat sedemikian dalam OSM berdekatan), bukan sebab untuk fallback.
class FallbackNearbySearch implements NearbySearch {
  FallbackNearbySearch(this.primary, this.secondary);

  final NearbySearch primary;
  final NearbySearch secondary;

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async {
    try {
      return await primary.search(
        category,
        center,
        fallbackName: fallbackName,
        cancel: cancel,
      );
    } on GeocodeFailure catch (failure) {
      try {
        return await secondary.search(
          category,
          center,
          fallbackName: fallbackName,
          cancel: cancel,
        );
      } on GeocodeFailure {
        throw failure;
      }
    }
  }
}

/// Menghurai respons Overpass `out tags center`. Mencampakkan [GeocodeFailure] jika pelayan
/// melaporkan ralat masa jalan (tamat masa/terlebih beban) walaupun status HTTP 200.
List<Place> parseOverpassResponse(
  String? body, {
  required GeoPoint center,
  required String fallbackName,
}) {
  if (body == null || body.isEmpty) {
    throw const GeocodeFailure(GeocodeFailureKind.unavailable, 'badan kosong');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    // Overpass menghantar HTML apabila terlebih beban.
    throw const GeocodeFailure(GeocodeFailureKind.unavailable, 'bukan JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const GeocodeFailure(GeocodeFailureKind.generic, 'bukan objek');
  }
  final remark = decoded['remark'];
  if (remark is String && remark.contains('runtime error')) {
    throw GeocodeFailure(GeocodeFailureKind.unavailable, remark);
  }
  final elements = decoded['elements'];
  if (elements is! List) return const [];

  final places = <Place>[];
  final unnamed = <Place>{};
  for (final e in elements) {
    if (e is! Map<String, dynamic>) continue;
    final tags = e['tags'];
    if (tags is! Map<String, dynamic>) continue;
    final lat = _num(e['lat']) ?? _num((e['center'] as Map?)?['lat']);
    final lng = _num(e['lon']) ?? _num((e['center'] as Map?)?['lon']);
    if (lat == null || lng == null) continue;

    String? t(String key) {
      final v = tags[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final namedBy = t('name') ?? t('name:en') ?? t('brand') ?? t('operator');
    final name = namedBy ?? fallbackName;
    final street = t('addr:street');
    final house = t('addr:housenumber');
    final area = t('addr:suburb') ?? t('addr:city') ?? t('addr:district');
    final owner = t('brand') ?? t('operator');
    final subtitleParts = <String>[
      if (owner != null && owner.toLowerCase() != name.toLowerCase()) owner,
      if (street != null) house == null ? street : '$house $street',
      ?area,
    ];
    final key = t('amenity') != null ? 'amenity' : 'building';
    final place = Place(
      name: name,
      subtitle: subtitleParts.join(', '),
      point: GeoPoint(lat, lng),
      category: t('amenity') ?? t('building'),
      osmKey: key,
      osmType: switch (e['type']) {
        'node' => 'N',
        'way' => 'W',
        'relation' => 'R',
        _ => null,
      },
      osmId: e['id'] is int ? e['id'] as int : null,
      countryCode: t('addr:country')?.toUpperCase(),
    );
    if (namedBy == null) unnamed.add(place);
    places.add(place);
  }
  return sortNearby(places, center, unnamed: unnamed);
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

/// Paling dekat dahulu; tempat tanpa nama diturunkan 600 m setara supaya yang bernama diutamakan.
/// Menggabungkan entri bernama sama dalam 60 m (cth. titik + bangunan masjid yang sama).
List<Place> sortNearby(
  List<Place> places,
  GeoPoint center, {
  Set<Place> unnamed = const {},
  int maxResults = 25,
}) {
  double cost(Place p) =>
      distanceMeters(center, p.point) + (unnamed.contains(p) ? 600 : 0);
  final sorted = [...places]..sort((a, b) => cost(a).compareTo(cost(b)));
  final out = <Place>[];
  for (final p in sorted) {
    final duplicate = out.any(
      (k) =>
          k.name.toLowerCase() == p.name.toLowerCase() &&
          distanceMeters(k.point, p.point) <= 60,
    );
    if (!duplicate) out.add(p);
    if (out.length >= maxResults) break;
  }
  return out;
}

final nearbySearchProvider = Provider<NearbySearch>((ref) {
  final dio = ref.watch(dioProvider);
  return CachedNearbySearch(
    FallbackNearbySearch(
      OverpassNearbySearch(dio, AppConfig.overpassUrls),
      NominatimNearbySearch(dio, AppConfig.nominatimUrl),
    ),
    ref.watch(sharedPreferencesProvider),
  );
});
