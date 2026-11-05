import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';
import '../domain/route_option.dart';
import '../domain/toll.dart';

/// Mengesan plaza tol di sepanjang satu laluan.
abstract interface class TollPlazaFinder {
  /// Plaza mengikut susunan perjalanan. Melempar [TollLookupFailure] jika data tidak dapat diperoleh.
  Future<List<TollPlaza>> find(RouteOption route);
}

class TollLookupFailure implements Exception {
  const TollLookupFailure([this.detail]);

  final String? detail;

  @override
  String toString() => 'TollLookupFailure(${detail ?? ''})';
}

/// Plaza tol daripada OSM melalui Overpass (`barrier=toll_booth` dan `highway=toll_gantry`) dalam kotak
/// sempadan laluan, dipadankan ke garisan laluan. Pertanyaan POST (koordinat tidak dalam URL); cermin
/// dicuba berturutan. Hasil dicache dalam memori mengikut laluan.
class OverpassTollFinder implements TollPlazaFinder {
  OverpassTollFinder(this._dio, this._mirrors);

  final Dio _dio;
  final List<String> _mirrors;
  final Map<String, List<TollPlaza>> _cache = {};

  static String queryFor(List<GeoPoint> points) {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in points) {
      if (p.lat < s) s = p.lat;
      if (p.lat > n) n = p.lat;
      if (p.lng < w) w = p.lng;
      if (p.lng > e) e = p.lng;
    }
    const pad = 0.002;
    String c(double v) => v.toStringAsFixed(5);
    final box = '${c(s - pad)},${c(w - pad)},${c(n + pad)},${c(e + pad)}';
    return '[out:json][timeout:10];'
        '(node["barrier"="toll_booth"]($box);node["highway"="toll_gantry"]($box););'
        'out body 2000;';
  }

  @override
  Future<List<TollPlaza>> find(RouteOption route) async {
    final key = routeKey(route);
    final cached = _cache[key];
    if (cached != null) return cached;

    final query = queryFor(route.points);
    Object? last;
    for (final mirror in _mirrors) {
      try {
        final response = await _dio.post<Object>(
          mirror,
          data: 'data=${Uri.encodeQueryComponent(query)}',
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final plazas = matchTollPlazas(
          route.points,
          parseTollNodes(responseText(response.data)),
        );
        return _cache[key] = plazas;
      } on DioException catch (e) {
        last = e.type;
      } on TollLookupFailure catch (e) {
        last = e;
      }
    }
    throw TollLookupFailure('$last');
  }
}

/// Nod plaza daripada respons Overpass. Nod tanpa koordinat sah dilangkau; badan rosak -> kegagalan.
List<({String id, GeoPoint point, String? name})> parseTollNodes(String? body) {
  if (body == null || body.isEmpty) throw const TollLookupFailure('kosong');
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const TollLookupFailure('bukan JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const TollLookupFailure('bukan objek');
  }
  final remark = decoded['remark'];
  if (remark is String && remark.contains('runtime error')) {
    throw TollLookupFailure(remark);
  }
  final elements = decoded['elements'];
  if (elements is! List) return const [];
  final out = <({String id, GeoPoint point, String? name})>[];
  for (final e in elements) {
    if (e is! Map<String, dynamic>) continue;
    final lat = e['lat'];
    final lon = e['lon'];
    if (lat is! num || lon is! num) continue;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
    final tags = e['tags'];
    final name = tags is Map<String, dynamic> ? tags['name'] : null;
    out.add((
      id: '${e['id']}',
      point: GeoPoint(lat.toDouble(), lon.toDouble()),
      name: name is String && name.trim().isNotEmpty ? name.trim() : null,
    ));
  }
  return out;
}

/// Plaza daripada dataset kadar yang dibundel (koordinat plaza disahkan): dipadankan terus ke garisan
/// laluan pada peranti. Serta-merta, berfungsi tanpa internet dan tidak membebankan Overpass awam.
class DatasetTollFinder implements TollPlazaFinder {
  DatasetTollFinder(this._rates);

  final Future<TollRates> Function() _rates;

  /// Garisan laluan melalui tengah plaza; 60 m cukup untuk lorong plaza yang lebar tanpa menangkap
  /// plaza di susur keluar yang tidak dilalui.
  static const toleranceM = 60.0;

  @override
  Future<List<TollPlaza>> find(RouteOption route) async {
    // Valhalla kata tiada jalan bertol: plaza yang "dipadankan" hanyalah plaza jalan selari.
    if (!route.hasTolls) return const [];
    final rates = await _rates();
    if (rates.isEmpty || route.points.length < 2) return const [];
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in route.points) {
      if (p.lat < s) s = p.lat;
      if (p.lat > n) n = p.lat;
      if (p.lng < w) w = p.lng;
      if (p.lng > e) e = p.lng;
    }
    const pad = 0.002;
    final nodes = [
      for (final node in rates.plazaNodes)
        if (node.point.lat >= s - pad &&
            node.point.lat <= n + pad &&
            node.point.lng >= w - pad &&
            node.point.lng <= e + pad)
          node,
    ];
    return matchTollPlazas(route.points, nodes, toleranceM: toleranceM);
  }
}

/// Dataset dahulu; Overpass hanya bila dataset tiada plaza tetapi laluan jelas melalui jalan bertol
/// (cth. lebuh raya baharu yang belum ada dalam dataset).
class HybridTollFinder implements TollPlazaFinder {
  HybridTollFinder(this._dataset, this._fallback);

  final TollPlazaFinder _dataset;
  final TollPlazaFinder _fallback;

  @override
  Future<List<TollPlaza>> find(RouteOption route) async {
    final plazas = await _dataset.find(route);
    if (plazas.isNotEmpty || route.tollLengthM < 2000) return plazas;
    return _fallback.find(route);
  }
}

final tollPlazaFinderProvider = Provider<TollPlazaFinder>(
  (ref) => HybridTollFinder(
    DatasetTollFinder(() => ref.read(tollRatesProvider.future)),
    OverpassTollFinder(ref.watch(dioProvider), AppConfig.overpassUrls),
  ),
);

/// Kadar tol yang disahkan, dimuat sekali daripada aset. Gagal memuat -> dataset kosong.
final tollRatesProvider = FutureProvider<TollRates>((ref) async {
  try {
    return TollRates.parse(
      await rootBundle.loadString('assets/tolls/my_tolls.json'),
    );
  } on Object {
    return TollRates.empty;
  }
});

/// Anggaran tol satu laluan daripada dataset sahaja (serta-merta, offline). Untuk paparan di luar
/// pratonton laluan, cth. lembaran "Tukar laluan" semasa navigasi. Null = tiada tol / tiada padanan.
final routeTollEstimateProvider = FutureProvider.autoDispose
    .family<TollEstimate?, ({RouteOption option, RouteVehicle vehicle})>((
      ref,
      key,
    ) async {
      if (!key.option.hasTolls) return null;
      final rates = await ref.watch(tollRatesProvider.future);
      final plazas = await DatasetTollFinder(
        () async => rates,
      ).find(key.option);
      if (plazas.isEmpty) return null;
      return rates.estimate(plazas, key.vehicle, route: key.option);
    });
