import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/geo.dart';
import '../domain/air_quality.dart';

/// IPU rasmi Jabatan Alam Sekitar (APIMS / EQMS).
///
/// Satu permintaan memulangkan jadual sejam semua stesen; kita ambil bacaan terkini
/// setiap stesen. Tiada kunci API. Soft-fail jika offline.
class JasIpuClient {
  JasIpuClient(this._dio);

  final Dio _dio;
  List<AirStation>? _cache;
  DateTime? _cacheAt;

  static const baseUrl =
      'https://eqms.doe.gov.my/api3/publicportalapims/apitablehourly';

  /// Muat (atau guna cache ≤20 min) senarai stesen dengan IPU terkini.
  Future<List<AirStation>> stations({CancelToken? cancel}) async {
    final cached = _cache;
    final at = _cacheAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 20)) {
      return cached;
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        baseUrl,
        options: Options(
          headers: {'User-Agent': AppConfig.userAgent},
          receiveTimeout: const Duration(seconds: 20),
        ),
        cancelToken: cancel,
      );
      final list = res.data?['api_table_hourly'];
      if (list is! List) return cached ?? const [];
      final latest = <String, AirStation>{};
      for (final row in list) {
        if (row is! Map) continue;
        final station = _parseRow(row);
        if (station == null) continue;
        final prev = latest[station.id];
        if (prev == null || station.observedAt.isAfter(prev.observedAt)) {
          latest[station.id] = station;
        }
      }
      final out = latest.values.toList();
      if (out.isEmpty) return cached ?? const [];
      _cache = out;
      _cacheAt = DateTime.now();
      return out;
    } catch (_) {
      return cached ?? const [];
    }
  }

  /// Stesen terdekat kepada [point] (atau null jika tiada data).
  Future<AirReading?> nearest({
    required GeoPoint point,
    String? placeLabel,
    bool here = false,
    CancelToken? cancel,
  }) async {
    final all = await stations(cancel: cancel);
    if (all.isEmpty) return null;
    AirStation? best;
    var bestM = double.infinity;
    for (final s in all) {
      final d = distanceMeters(point, s.point);
      if (d < bestM) {
        bestM = d;
        best = s;
      }
    }
    if (best == null) return null;
    return AirReading(
      ipu: best.ipu,
      point: point,
      fetchedAt: DateTime.now(),
      stationName: best.name,
      stationDistanceM: bestM,
      placeLabel: placeLabel,
      here: here,
      fromCache:
          _cacheAt != null &&
          DateTime.now().difference(_cacheAt!) > const Duration(seconds: 2),
      observedAt: best.observedAt,
      pollutant: best.pollutant,
    );
  }

  /// Stesen dengan IPU ≥ [threshold] yang paling hampir kepada mana-mana titik sampel.
  Future<AirStation?> alertAlong({
    required List<GeoPoint> samples,
    int threshold = ipuAlertThreshold,
    CancelToken? cancel,
  }) async {
    if (samples.isEmpty) return null;
    final all = await stations(cancel: cancel);
    AirStation? worst;
    var worstScore = -1.0;
    for (final s in all) {
      if (s.ipu < threshold) continue;
      var minD = double.infinity;
      for (final p in samples) {
        final d = distanceMeters(p, s.point);
        if (d < minD) minD = d;
      }
      // Dalam ~40 km koridor laluan; pilih IPU tertinggi, kemudian paling dekat.
      if (minD > 40000) continue;
      final score = s.ipu - minD / 100000;
      if (score > worstScore) {
        worstScore = score;
        worst = s;
      }
    }
    return worst;
  }

  static AirStation? _parseRow(Map row) {
    final id = row['STATION_ID']?.toString();
    final name = (row['STATION_LOCATION'] ?? row['STATION_NAME'])?.toString();
    final lat = (row['LATITUDE'] as num?)?.toDouble();
    final lng = (row['LONGITUDE'] as num?)?.toDouble();
    final api = (row['API'] as num?)?.round();
    final dtRaw = row['DATETIME']?.toString();
    if (id == null ||
        name == null ||
        name.isEmpty ||
        lat == null ||
        lng == null ||
        api == null) {
      return null;
    }
    final observed = DateTime.tryParse(dtRaw ?? '') ?? DateTime.now();
    return AirStation(
      id: id,
      name: name,
      point: GeoPoint(lat, lng),
      ipu: api,
      observedAt: observed,
      pollutant: pollutantFromSymbol(row['PARAM_SYMBOL']?.toString()),
    );
  }
}

final jasIpuClientProvider = Provider(
  (ref) => JasIpuClient(ref.watch(dioProvider)),
);
