import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/along_route/data/along_route_search.dart';
import 'package:fgmap/features/along_route/domain/along_route_category.dart';
import 'package:fgmap/features/along_route/domain/along_route_projector.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:flutter_test/flutter_test.dart';

/// Laluan lurus ke timur di khatulistiwa sepanjang ~50 km (0.45° ~ 50 km), titik setiap 100 m.
List<GeoPoint> _route({double km = 50}) {
  final n = (km * 10).round();
  return [for (var i = 0; i <= n; i++) GeoPoint(0, i * (km / 111.32) / n)];
}

String _overpass(List<(double, double, String)> places) => jsonEncode({
  'elements': [
    for (var i = 0; i < places.length; i++)
      {
        'type': 'node',
        'id': i + 1,
        'lat': places[i].$1,
        'lon': places[i].$2,
        'tags': {'name': places[i].$3, 'amenity': 'fuel'},
      },
  ],
});

class _Mirror implements HttpClientAdapter {
  _Mirror(this.name, this.handler);

  final String name;
  final Future<ResponseBody> Function(RequestOptions o, Future<void>? cancel)
  handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options, cancelFuture);

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(String body) => ResponseBody.fromString(
  body,
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

/// Satu Dio yang mengarahkan setiap hos ke pengendalinya sendiri dan merekod hos yang dipanggil.
class _Net {
  _Net(this.handlers);

  final Map<String, Future<ResponseBody> Function(Future<void>? cancel)>
  handlers;
  final calls = <String>[];
  final cancelled = <String>[];

  Dio dio() {
    final d = Dio();
    d.httpClientAdapter = _Mirror('net', (o, cancel) {
      final host = o.uri.host;
      calls.add(host);
      cancel?.then((_) => cancelled.add(host));
      return handlers[host]!(cancel);
    });
    return d;
  }
}

const _m1 = 'https://m1.test/api';
const _m2 = 'https://m2.test/api';
const _m3 = 'https://m3.test/api';

void main() {
  group('pertanyaan Overpass', () {
    test(
      'satu penapis polyline setiap selector, bukan satu bulatan setiap sampel',
      () {
        final pts = samplePolyline(_route(), everyM: 500);
        final q = AlongRouteCategory.fuel.overpassQuery(
          pts.map((p) => (p.lat, p.lng)),
        );
        expect(RegExp('around:').allMatches(q), hasLength(1));
        expect(q, contains('nw["amenity"="fuel"](around:620,'));
        expect(q, contains('out tags center qt;'));
        expect(q, contains('[timeout:20]'));
      },
    );

    test('kategori dengan banyak selector: satu penyata setiap selector', () {
      final q = AlongRouteCategory.mosque.overpassQuery(const [
        (3.0, 101.0),
        (3.1, 101.1),
      ]);
      expect(RegExp('around:').allMatches(q), hasLength(3));
    });

    test('koordinat dibulatkan ~1 m: permintaan jauh lebih pendek', () {
      final q = AlongRouteCategory.fuel.overpassQuery(const [
        (3.1234567891234, 101.9876543219876),
        (3.2, 101.3),
      ]);
      expect(q, contains('3.12346,101.98765'));
      expect(q, isNot(contains('3.1234567')));
    });

    test('laluan 300 km dihantar dalam ≤ ~250 titik', () async {
      String? sent;
      final net = _Net({'m1.test': (_) async => _ok(_overpass(const []))});
      final dio = net.dio();
      dio.httpClientAdapter = _Mirror('cap', (o, _) async {
        sent = o.data as String;
        return _ok(_overpass(const []));
      });
      await AlongRouteSearch(dio, const [_m1]).search(
        routePoints: _route(km: 300),
        category: AlongRouteCategory.fuel,
        fallbackName: 'x',
      );
      final coordPairs = RegExp(r'\d+\.\d{5},\d+\.\d{5}').allMatches(sent!);
      expect(coordPairs.length, lessThanOrEqualTo(260));
      expect(coordPairs.length, greaterThan(100));
    });
  });

  group('hasil', () {
    test(
      'diunjur ke laluan, ditapis ikut koridor, diisih ikut jarak',
      () async {
        final net = _Net({
          'm1.test': (_) async => _ok(
            _overpass(const [
              (
                0.001,
                0.30,
                'Jauh ke depan',
              ), // ~111 m dari laluan: dalam koridor 500 m
              (0.0005, 0.10, 'Awal'),
              (0.05, 0.20, 'Terlalu jauh dari laluan'), // ~5.5 km: dibuang
            ]),
          ),
        });
        final pois = await AlongRouteSearch(net.dio(), const [_m1]).search(
          routePoints: _route(),
          category: AlongRouteCategory.fuel,
          fallbackName: 'Stesen',
        );
        expect(pois.map((p) => p.name), ['Awal', 'Jauh ke depan']);
        expect(pois.first.alongM, lessThan(pois.last.alongM));
      },
    );

    test('elemen tanpa nama guna nama sandaran', () async {
      final net = _Net({
        'm1.test': (_) async => _ok(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 1,
                'lat': 0.0,
                'lon': 0.05,
                'tags': {'amenity': 'fuel'},
              },
            ],
          }),
        ),
      });
      final pois = await AlongRouteSearch(net.dio(), const [_m1]).search(
        routePoints: _route(),
        category: AlongRouteCategory.fuel,
        fallbackName: 'Stesen minyak',
      );
      expect(pois.single.name, 'Stesen minyak');
    });
  });

  group('lumba cermin', () {
    test('cermin pertama lambat: yang kedua dimulakan selepas hedge dan menang '
        'tanpa menunggu tamat masa', () async {
      final slow = Completer<ResponseBody>();
      final net = _Net({
        'm1.test': (_) => slow.future, // tidak pernah menjawab
        'm2.test': (_) async => _ok(_overpass(const [(0.0, 0.1, 'Dari m2')])),
      });
      final sw = Stopwatch()..start();
      final pois =
          await AlongRouteSearch(net.dio(), const [
            _m1,
            _m2,
          ], hedgeDelay: const Duration(milliseconds: 80)).search(
            routePoints: _route(),
            category: AlongRouteCategory.fuel,
            fallbackName: 'x',
          );
      expect(pois.single.name, 'Dari m2');
      expect(net.calls, ['m1.test', 'm2.test']);
      // Jauh lebih pantas daripada tamat masa 20-25 s versi lama.
      expect(sw.elapsedMilliseconds, lessThan(2000));
      // Permintaan yang kalah dibatalkan (tidak membebani pelayan percuma).
      await pumpEventQueue();
      expect(net.cancelled, contains('m1.test'));
    });

    test(
      'cermin pertama gagal: yang kedua serta-merta, tanpa menunggu hedge',
      () async {
        final net = _Net({
          'm1.test': (_) async => throw DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.connectionError,
          ),
          'm2.test': (_) async => _ok(_overpass(const [(0.0, 0.1, 'OK')])),
        });
        final sw = Stopwatch()..start();
        final pois =
            await AlongRouteSearch(
              net.dio(),
              const [_m1, _m2],
              hedgeDelay: const Duration(
                seconds: 30,
              ), // jika bergantung pada hedge, ujian ini tamat masa
            ).search(
              routePoints: _route(),
              category: AlongRouteCategory.fuel,
              fallbackName: 'x',
            );
        expect(pois.single.name, 'OK');
        expect(sw.elapsedMilliseconds, lessThan(2000));
      },
    );

    test('cermin pantas menang: cermin lain tidak pernah dimulakan', () async {
      final net = _Net({
        'm1.test': (_) async => _ok(_overpass(const [(0.0, 0.1, 'Cepat')])),
        'm2.test': (_) async => _ok(_overpass(const [])),
      });
      await AlongRouteSearch(net.dio(), const [_m1, _m2]).search(
        routePoints: _route(),
        category: AlongRouteCategory.fuel,
        fallbackName: 'x',
      );
      expect(net.calls, ['m1.test']);
    });

    test('semua cermin gagal: GeocodeFailure', () async {
      Future<ResponseBody> fail(Future<void>? _) async => throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionTimeout,
      );
      final net = _Net({'m1.test': fail, 'm2.test': fail, 'm3.test': fail});
      await expectLater(
        AlongRouteSearch(net.dio(), const [_m1, _m2, _m3]).search(
          routePoints: _route(),
          category: AlongRouteCategory.fuel,
          fallbackName: 'x',
        ),
        throwsA(isA<GeocodeFailure>()),
      );
      expect(net.calls, ['m1.test', 'm2.test', 'm3.test']);
    });

    test('dibatalkan oleh pemanggil: DioException jenis cancel', () async {
      final net = _Net({'m1.test': (_) => Completer<ResponseBody>().future});
      final token = CancelToken();
      final f = AlongRouteSearch(net.dio(), const [_m1]).search(
        routePoints: _route(),
        category: AlongRouteCategory.fuel,
        fallbackName: 'x',
        cancel: token,
      );
      await pumpEventQueue();
      token.cancel();
      await expectLater(
        f,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });
  });

  group('unjuran', () {
    test(
      'along dikira sekali memberi hasil sama seperti dikira setiap kali',
      () {
        final r = _route();
        final along = cumulativeMeters(r);
        const p = GeoPoint(0.0003, 0.2);
        final a = projectOntoPolyline(r, p)!;
        final b = projectOntoPolyline(r, p, along: along)!;
        expect(b.alongM, a.alongM);
        expect(b.crossTrackM, a.crossTrackM);
      },
    );
  });
}
