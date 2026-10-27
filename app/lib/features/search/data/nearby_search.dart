import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kDebugMode;
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
import '../../../core/utils/log.dart';

/// Hasil carian berhampiran.
///
/// - [cachedAt] bukan null apabila pelayan tidak dapat dicapai dan senarai ini ialah simpanan lama.
/// - [refreshing] benar apabila senarai ini sementara: hasil lebih lengkap masih dicari (peringkat radius
///   seterusnya) atau simpanan lama dipaparkan sementara pelayan disemak semula.
class NearbyResult {
  const NearbyResult(this.places, {this.cachedAt, this.refreshing = false});

  final List<Place> places;
  final DateTime? cachedAt;
  final bool refreshing;

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

/// Carian yang menghantar hasil BERPERINGKAT: hasil pertama (kawasan kecil, pantas) dahulu, kemudian
/// yang lebih lengkap. Aliran sentiasa berakhir dengan hasil yang `refreshing == false`, atau ralat jika
/// tiada apa-apa hasil langsung.
abstract interface class ProgressiveNearbySearch implements NearbySearch {
  Stream<NearbyResult> watch(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  });
}

/// Aliran hasil untuk [search]: progresif jika disokong, jika tidak satu hasil sahaja.
Stream<NearbyResult> watchNearby(
  NearbySearch search,
  NearbyCategory category,
  GeoPoint center, {
  required String fallbackName,
  CancelToken? cancel,
}) {
  if (search is ProgressiveNearbySearch) {
    return search.watch(
      category,
      center,
      fallbackName: fallbackName,
      cancel: cancel,
    );
  }
  return Stream.fromFuture(
    search.search(category, center, fallbackName: fallbackName, cancel: cancel),
  );
}

/// Badan respons lebih besar daripada ini dihuraikan dalam isolate supaya UI tidak tersangkut.
const _isolateParseThreshold = 20000;

/// Overpass API (data OSM, percuma tanpa kunci). Dasar penggunaan awam: kurang 10,000 pertanyaan sehari
/// dan UA berpengenalan.
///
/// Laju: peringkat pertama kecil (`[timeout:5]`, 60 hasil, tanpa penapis mahal) dan hasilnya dihantar
/// serta-merta; peringkat lebih luas ([NearbyCategory.radiiM]) berjalan kemudian hanya jika perlu.
/// Setiap peringkat "berlumba" antara cermin: cermin kedua dimulakan jika yang pertama belum membalas
/// dalam [hedgeAfter] (maksimum dua serentak), dan yang pertama berjaya menang. Pertanyaan dihantar
/// secara POST supaya koordinat tidak berada dalam URL.
class OverpassNearbySearch implements ProgressiveNearbySearch {
  OverpassNearbySearch(
    this._dio,
    this._mirrors, {
    this.deadline = const Duration(seconds: 20),
    this.hedgeAfter = const Duration(milliseconds: 1500),
    Stopwatch Function()? stopwatch,
  }) : _newStopwatch = stopwatch ?? Stopwatch.new;

  final Dio _dio;
  final List<String> _mirrors;

  /// Jumlah masa maksimum mencuba cermin untuk satu peringkat radius; selepas ini dianggap gagal.
  final Duration deadline;

  /// Selepas ini tanpa balasan, cermin seterusnya dimulakan serentak.
  final Duration hedgeAfter;
  final Stopwatch Function() _newStopwatch;

  int _preferred = 0;

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) =>
      watch(category, center, fallbackName: fallbackName, cancel: cancel).last;

  @override
  Stream<NearbyResult> watch(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async* {
    var places = const <Place>[];
    var emitted = false;
    var stoppedEarly = false;
    final stages = category.radiiM.length;
    for (var i = 0; i < stages; i++) {
      try {
        places = await _stage(category, center, i, fallbackName, cancel);
      } on GeocodeFailure {
        // Peringkat pertama gagal = gagal. Peringkat lebih luas gagal: kekalkan apa yang sudah ada.
        if (i == 0) rethrow;
        stoppedEarly = true;
        break;
      }
      final done = places.length >= category.enoughResults || i == stages - 1;
      yield NearbyResult(places, refreshing: !done);
      emitted = true;
      if (done) return;
    }
    // Peringkat lebih luas gagal selepas hasil sementara dipaparkan: tutup sebagai muktamad.
    if (emitted && stoppedEarly) yield NearbyResult(places);
  }

  Future<List<Place>> _stage(
    NearbyCategory category,
    GeoPoint center,
    int stage,
    String fallbackName,
    CancelToken? cancel,
  ) {
    final watch = _newStopwatch()..start();
    final query = category.overpassQuery(
      center.lat,
      center.lng,
      category.radiiM[stage],
      fast: stage == 0,
    );
    return _race(query, center, fallbackName, cancel).whenComplete(() {
      if (kDebugMode && _diagnostics) {
        logDiag(
          'FGDIAG nearby ${category.name} peringkat $stage: ${watch.elapsedMilliseconds} ms',
        );
      }
    });
  }

  static const _diagnostics = bool.fromEnvironment('FG_DIAG');

  /// Menghantar [query] kepada cermin dengan lindung nilai (hedge); pulangkan hasil yang pertama berjaya.
  Future<List<Place>> _race(
    String query,
    GeoPoint center,
    String fallbackName,
    CancelToken? cancel,
  ) {
    final completer = Completer<List<Place>>();
    final order = [
      for (var n = 0; n < _mirrors.length; n++)
        (_preferred + n) % _mirrors.length,
    ];
    final tokens = <CancelToken>[];
    final watch = _newStopwatch()..start();
    var next = 0;
    var running = 0;
    GeocodeFailure? lastFailure;
    Timer? hedgeTimer;

    void finish() {
      hedgeTimer?.cancel();
      for (final t in tokens) {
        if (!t.isCancelled) t.cancel('selesai');
      }
    }

    void fail() {
      if (completer.isCompleted) return;
      finish();
      completer.completeError(
        lastFailure ??
            const GeocodeFailure(
              GeocodeFailureKind.unavailable,
              'tiada cermin',
            ),
      );
    }

    void launch() {
      if (completer.isCompleted || next >= order.length) return;
      final index = order[next++];
      running++;
      final token = CancelToken();
      tokens.add(token);
      () async {
        try {
          final text = await _post(_mirrors[index], query, token);
          final places = await _parse(text, center, fallbackName);
          if (completer.isCompleted) return;
          _preferred = index;
          finish();
          completer.complete(places);
        } on DioException catch (e) {
          if (completer.isCompleted) return;
          if (e.type == DioExceptionType.cancel) {
            // Dibatalkan oleh pemanggil (bukan kemenangan cermin lain, yang telah selesai di atas).
            finish();
            completer.completeError(e);
            return;
          }
          lastFailure = geocodeFailureOf(e);
          running--;
          _onAttemptFailed();
        } on GeocodeFailure catch (f) {
          if (completer.isCompleted) return;
          lastFailure = f;
          running--;
          _onAttemptFailed();
        }
      }();
      // Cermin kedua serentak jika yang ini lambat (maksimum dua dalam penerbangan).
      hedgeTimer?.cancel();
      if (next < order.length && running < 2) {
        hedgeTimer = Timer(hedgeAfter, launch);
      }
    }

    // Cermin seterusnya serta-merta apabila satu gagal, selagi masih dalam [deadline].
    _onAttemptFailed = () {
      if (completer.isCompleted) return;
      if (next < order.length && watch.elapsed < deadline) {
        launch();
      } else if (running == 0) {
        fail();
      }
    };

    cancel?.whenCancel.then((_) {
      if (completer.isCompleted) return;
      finish();
      completer.completeError(
        DioException.requestCancelled(
          requestOptions: RequestOptions(),
          reason: 'carian dibatalkan',
        ),
      );
    });

    launch();
    return completer.future;
  }

  void Function() _onAttemptFailed = () {};

  Future<String?> _post(String url, String query, CancelToken token) async {
    final response = await _dio.post<Object>(
      url,
      data: 'data=${Uri.encodeQueryComponent(query)}',
      cancelToken: token,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 7),
        sendTimeout: const Duration(seconds: 5),
      ),
    );
    return responseText(response.data);
  }

  Future<List<Place>> _parse(
    String? text,
    GeoPoint center,
    String fallbackName,
  ) {
    if (text != null && text.length > _isolateParseThreshold) {
      return Isolate.run(
        () => parseOverpassResponse(
          text,
          center: center,
          fallbackName: fallbackName,
        ),
      );
    }
    return Future.value(
      parseOverpassResponse(text, center: center, fallbackName: fallbackName),
    );
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
class FallbackNearbySearch implements ProgressiveNearbySearch {
  FallbackNearbySearch(this.primary, this.secondary);

  final NearbySearch primary;
  final NearbySearch secondary;

  @override
  Future<NearbyResult> search(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) =>
      watch(category, center, fallbackName: fallbackName, cancel: cancel).last;

  @override
  Stream<NearbyResult> watch(
    NearbyCategory category,
    GeoPoint center, {
    required String fallbackName,
    CancelToken? cancel,
  }) async* {
    var emitted = false;
    try {
      await for (final r in watchNearby(
        primary,
        category,
        center,
        fallbackName: fallbackName,
        cancel: cancel,
      )) {
        emitted = true;
        yield r;
      }
    } on GeocodeFailure catch (failure) {
      // Selepas hasil sementara dipaparkan, kegagalan peringkat kemudian tidak membuang apa yang ada.
      if (emitted) return;
      // `yield*` meneruskan ralat terus ke aliran keluaran tanpa boleh ditangkap di sini; guna `await for`.
      try {
        await for (final r in watchNearby(
          secondary,
          category,
          center,
          fallbackName: fallbackName,
          cancel: cancel,
        )) {
          yield r;
        }
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
/// Menggabungkan entri bernama sama dalam 60 m (cth. titik + bangunan masjid yang sama). Kos dikira
/// sekali setiap tempat (bukan dalam pembanding) kerana senarai boleh mencapai 1000 elemen.
List<Place> sortNearby(
  List<Place> places,
  GeoPoint center, {
  Set<Place> unnamed = const {},
  int maxResults = 25,
}) {
  final scored = [
    for (final p in places)
      (
        p,
        distanceMeters(center, p.point) + (unnamed.contains(p) ? 600.0 : 0.0),
      ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final out = <Place>[];
  for (final (p, _) in scored) {
    final name = p.name.toLowerCase();
    final duplicate = out.any(
      (k) =>
          k.name.toLowerCase() == name &&
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
