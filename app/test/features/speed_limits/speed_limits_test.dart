import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/offline_maps/data/offline_engine_host.dart';
import 'package:fgmap/features/offline_maps/data/offline_map_store.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:fgmap/features/speed_limits/domain/speed_limits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

String _fixture(String n) => File('test/fixtures/$n').readAsStringSync();

class _Engine implements OfflineEngine {
  String? traceResponse;
  Object? traceError;
  final List<String> traceRequests = [];

  @override
  Future<void> open(String tarPath) async {}
  @override
  Future<String> route(String requestJson) async => '{}';
  @override
  Future<String> traceAttributes(String requestJson) async {
    traceRequests.add(requestJson);
    if (traceError != null) throw traceError!;
    return traceResponse ?? '{}';
  }

  @override
  Future<void> close() async {}
}

SpeedLimitSegment _seg(int b, int e, double m, int? limit) => SpeedLimitSegment(
  beginShapeIndex: b,
  endShapeIndex: e,
  lengthM: m,
  limitKmh: limit,
);

void main() {
  group('encodePolyline6', () {
    test(
      'songsangan decodePolyline pada geometri sebenar (rentetan sama bait demi bait)',
      () {
        final shape =
            (jsonDecode(_fixture('valhalla_public_klcc_klia.json'))
                    as Map)['trip']['legs'][0]['shape']
                as String;
        final points = decodePolyline(shape);
        expect(points, hasLength(971));
        expect(encodePolyline6(points), shape);
      },
    );

    test('kosong dan satu titik', () {
      expect(encodePolyline6(const []), '');
      expect(
        decodePolyline(
          encodePolyline6(const [GeoPoint(3.1579, 101.7116)]),
        ).single,
        const GeoPoint(3.1579, 101.7116),
      );
    });

    test('koordinat negatif dan lompatan besar', () {
      const pts = [
        GeoPoint(-33.8688, 151.2093),
        GeoPoint(51.5072, -0.1276),
        GeoPoint(0, 0),
      ];
      final back = decodePolyline(encodePolyline6(pts));
      for (var i = 0; i < pts.length; i++) {
        expect(back[i].lat, closeTo(pts[i].lat, 1e-6));
        expect(back[i].lng, closeTo(pts[i].lng, 1e-6));
      }
    });
  });

  group('buildTraceAttributesRequest', () {
    test(
      'polyline, costing kenderaan, map_snap dan hanya medan diperlukan',
      () {
        final json = buildTraceAttributesRequest(const [
          klcc,
          klia,
        ], RouteVehicle.motorcycle);
        expect(json['costing'], 'motorcycle');
        expect(json['shape_match'], 'map_snap');
        expect(decodePolyline(json['encoded_polyline']! as String), [
          klcc,
          klia,
        ]);
        final filters = json['filters']! as Map;
        expect(filters['action'], 'include');
        expect(filters['attributes'], contains('edge.speed_limit'));
      },
    );
  });

  group('parseSpeedLimits (respons sebenar FOSSGIS KLCC->KLIA)', () {
    late SpeedLimits limits;
    setUpAll(
      () => limits = parseSpeedLimits(
        _fixture('valhalla_trace_attributes_klcc_klia.json'),
      ),
    );

    test(
      '205 segmen bersebelahan menutup seluruh laluan; had diketahui hanya pada sebahagian',
      () {
        expect(limits.segments, hasLength(205));
        for (var i = 1; i < limits.segments.length; i++) {
          expect(
            limits.segments[i].beginShapeIndex,
            limits.segments[i - 1].endShapeIndex,
          );
        }
        expect(
          limits.segments.last.endShapeIndex,
          970,
          reason: '971 titik laluan',
        );
        final known = limits.segments.where((s) => s.limitKmh != null).length;
        expect(known, 134);
        expect(
          limits.segments.map((s) => s.limitKmh).whereType<int>().toSet(),
          {20, 30, 50, 60, 80, 90, 110},
        );
      },
    );

    test('jumlah panjang hampir sama dengan jarak laluan (68.681 km)', () {
      final total = limits.segments.fold<double>(0, (a, s) => a + s.lengthM);
      expect(total, closeTo(68681, 50));
    });

    test(
      'atShapeIndex konsisten dengan segmen dan menolak indeks tidak sah',
      () {
        for (final s in limits.segments.take(40)) {
          expect(
            limits.atShapeIndex(s.beginShapeIndex),
            s.limitKmh,
            reason: 'permulaan ${s.beginShapeIndex}',
          );
        }
        expect(limits.atShapeIndex(-1), isNull);
        expect(
          limits.atShapeIndex(970),
          limits.segments.last.limitKmh,
          reason: 'titik terakhir',
        );
      },
    );

    test('atDistance: permulaan, pertengahan dan melepasi hujung', () {
      expect(limits.atDistance(0), limits.segments.first.limitKmh);
      final mid = limits.segments.fold<double>(0, (a, s) => a + s.lengthM) / 2;
      expect(limits.atDistance(mid), isA<int?>());
      expect(limits.atDistance(1e9), limits.segments.last.limitKmh);
      expect(limits.atDistance(-5), isNull);
    });

    test('lebuh raya mempunyai had tinggi (110) di suatu tempat', () {
      expect(limits.segments.any((s) => s.limitKmh == 110), isTrue);
    });
  });

  group('SpeedLimits (kes tepi)', () {
    final l = SpeedLimits([
      _seg(0, 4, 400, 50),
      _seg(4, 9, 500, null),
      _seg(9, 20, 1100, 90),
    ]);

    test('atShapeIndex pada sempadan segmen mengikut segmen baharu', () {
      expect(l.atShapeIndex(0), 50);
      expect(l.atShapeIndex(3), 50);
      expect(l.atShapeIndex(4), isNull, reason: 'segmen kedua tidak diketahui');
      expect(l.atShapeIndex(9), 90);
      expect(l.atShapeIndex(20), 90);
    });

    test('atDistance pada sempadan', () {
      expect(l.atDistance(399.9), 50);
      expect(l.atDistance(400), isNull);
      expect(l.atDistance(900), 90);
    });

    test('kosong', () {
      expect(SpeedLimits.empty.isEmpty, isTrue);
      expect(SpeedLimits.empty.atShapeIndex(0), isNull);
      expect(SpeedLimits.empty.atDistance(0), isNull);
    });
  });

  group('parseSpeedLimits (data pelik)', () {
    test('unlimited / sifar / negatif / bukan int -> tidak diketahui', () {
      final body = jsonEncode({
        'edges': [
          {
            'begin_shape_index': 0,
            'end_shape_index': 1,
            'length': 0.1,
            'speed_limit': 'unlimited',
          },
          {
            'begin_shape_index': 1,
            'end_shape_index': 2,
            'length': 0.1,
            'speed_limit': 0,
          },
          {
            'begin_shape_index': 2,
            'end_shape_index': 3,
            'length': 0.1,
            'speed_limit': -5,
          },
          {
            'begin_shape_index': 3,
            'end_shape_index': 4,
            'length': 0.1,
            'speed_limit': 60.5,
          },
          {
            'begin_shape_index': 4,
            'end_shape_index': 5,
            'length': 0.1,
            'speed_limit': 70,
          },
        ],
      });
      expect(parseSpeedLimits(body).segments.map((s) => s.limitKmh), [
        null,
        null,
        null,
        null,
        70,
      ]);
    });

    test('tepi rosak dilangkau, bukan melempar', () {
      final body = jsonEncode({
        'edges': [
          'bukan objek',
          {'begin_shape_index': 'a', 'end_shape_index': 1, 'length': 0.1},
          {'begin_shape_index': 0, 'end_shape_index': 1},
          {
            'begin_shape_index': 0,
            'end_shape_index': 1,
            'length': 0.2,
            'speed_limit': 50,
          },
        ],
      });
      expect(parseSpeedLimits(body).segments, hasLength(1));
    });

    test('bentuk salah melempar FormatException', () {
      expect(() => parseSpeedLimits('[1]'), throwsFormatException);
      expect(() => parseSpeedLimits('{}'), throwsFormatException);
      expect(() => parseSpeedLimits('<html>'), throwsFormatException);
    });
  });

  group('SpeedLimitService', () {
    late Directory dir;
    late OfflineMapStore store;
    late _Engine engine;
    late OfflineEngineHost host;
    const route = RouteOption(
      distanceM: 1000,
      durationS: 60,
      hasTolls: false,
      points: [klcc, klia],
    );

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fg_speed_');
      store = OfflineMapStore(dir);
      engine = _Engine()
        ..traceResponse = _fixture('valhalla_trace_attributes_klcc_klia.json');
      host = OfflineEngineHost(engine, store);
    });
    tearDown(() => dir.delete(recursive: true));

    Future<void> installPack() async {
      await store.ensureDir();
      final tmp = File('${dir.path}/x.tmp')..writeAsBytesSync([1, 2, 3, 4]);
      await store.install(tmp, version: '20261026', sizeBytes: 4);
    }

    SpeedLimitService service(HttpClientAdapter adapter) => SpeedLimitService(
      Dio()..httpClientAdapter = adapter,
      'https://v.test/trace_attributes',
      host,
    );

    test(
      'laluan online: guna server awam; enjin offline tidak disentuh',
      () async {
        final adapter = StubAdapter(
          (_) => StubAdapter.text(
            _fixture('valhalla_trace_attributes_klcc_klia.json'),
            status: 200,
            contentType: 'application/json',
          ),
        );
        final limits = await service(adapter).forRoute(route, RouteVehicle.car);
        expect(limits.segments, hasLength(205));
        expect(
          adapter.lastRequest!.uri.toString(),
          'https://v.test/trace_attributes',
        );
        final sent = adapter.lastBody! as Map<String, dynamic>;
        expect(sent['costing'], 'auto');
        expect(engine.traceRequests, isEmpty);
      },
    );

    test('online gagal -> jatuh ke enjin offline jika pek dipasang', () async {
      await installPack();
      final limits = await service(
        FailingAdapter(DioExceptionType.connectionError),
      ).forRoute(route, RouteVehicle.car);
      expect(limits.segments, hasLength(205));
      expect(engine.traceRequests, hasLength(1));
    });

    test(
      'laluan offline: enjin offline dahulu; online tidak disentuh',
      () async {
        await installPack();
        final adapter = StubAdapter((_) => StubAdapter.text('{}', status: 500));
        const offlineRoute = RouteOption(
          distanceM: 1000,
          durationS: 60,
          hasTolls: false,
          points: [klcc, klia],
          source: RouteSource.offline,
        );
        final limits = await service(
          adapter,
        ).forRoute(offlineRoute, RouteVehicle.motorcycle);
        expect(limits.segments, hasLength(205));
        expect(adapter.lastRequest, isNull);
        expect(
          (jsonDecode(engine.traceRequests.single) as Map)['costing'],
          'motorcycle',
        );
      },
    );

    test('semua sumber gagal -> kosong, tidak melempar', () async {
      final limits = await service(
        FailingAdapter(DioExceptionType.connectionError),
      ).forRoute(route, RouteVehicle.car);
      expect(limits.isEmpty, isTrue);
    });

    test(
      'respons rosak daripada online, offline sah -> offline digunakan',
      () async {
        await installPack();
        final adapter = StubAdapter(
          (_) =>
              StubAdapter.text('<html>', status: 200, contentType: 'text/html'),
        );
        final limits = await service(adapter).forRoute(route, RouteVehicle.car);
        expect(limits.segments, hasLength(205));
      },
    );

    test('laluan tanpa titik mencukupi -> kosong tanpa permintaan', () async {
      final adapter = StubAdapter((_) => StubAdapter.text('{}', status: 200));
      const tiny = RouteOption(
        distanceM: 0,
        durationS: 0,
        hasTolls: false,
        points: [klcc],
      );
      expect(
        (await service(adapter).forRoute(tiny, RouteVehicle.car)).isEmpty,
        isTrue,
      );
      expect(adapter.lastRequest, isNull);
    });
  });

  group('overspeedLevel', () {
    test('di bawah, sama dengan, dan di atas had', () {
      expect(overspeedLevel(speedKmh: 49, limitKmh: 50), OverspeedLevel.none);
      expect(overspeedLevel(speedKmh: 50, limitKmh: 50), OverspeedLevel.none);
      expect(
        overspeedLevel(speedKmh: 51, limitKmh: 50),
        OverspeedLevel.warning,
      );
    });

    test('kelajuan dibundar: 50.4 = 50 (tiada amaran), 50.6 = 51 (amaran)', () {
      expect(overspeedLevel(speedKmh: 50.4, limitKmh: 50), OverspeedLevel.none);
      expect(
        overspeedLevel(speedKmh: 50.6, limitKmh: 50),
        OverspeedLevel.warning,
      );
    });

    test('toleransi +5 dan +10', () {
      expect(
        overspeedLevel(speedKmh: 55, limitKmh: 50, toleranceKmh: 5),
        OverspeedLevel.none,
      );
      expect(
        overspeedLevel(speedKmh: 56, limitKmh: 50, toleranceKmh: 5),
        OverspeedLevel.warning,
      );
      expect(
        overspeedLevel(speedKmh: 60, limitKmh: 50, toleranceKmh: 10),
        OverspeedLevel.none,
      );
    });

    test('tiada had diketahui atau data tidak sah -> tiada amaran', () {
      expect(
        overspeedLevel(speedKmh: 200, limitKmh: null),
        OverspeedLevel.none,
      );
      expect(overspeedLevel(speedKmh: 200, limitKmh: 0), OverspeedLevel.none);
      expect(
        overspeedLevel(speedKmh: double.nan, limitKmh: 50),
        OverspeedLevel.none,
      );
      expect(overspeedLevel(speedKmh: -3, limitKmh: 50), OverspeedLevel.none);
    });
  });
}
