import 'dart:convert';
import 'dart:io';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/valhalla_codec.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

RoutingFailure _parseFailure(Object? body) {
  try {
    parseRouteResponse(body, source: RouteSource.online);
  } on RoutingFailure catch (f) {
    return f;
  }
  fail('dijangka RoutingFailure');
}

void main() {
  group('buildRouteRequest', () {
    test(
      'lalai: auto, 2 alternatif, manuver tanpa teks, tiada heading/costing_options',
      () {
        final json = buildRouteRequest(
          const RouteQuery(origin: klcc, destination: klia),
        );

        expect(json['costing'], 'auto');
        expect(json['alternates'], 2);
        // Mesti di peringkat atas (di dalam directions_options Valhalla mengabaikannya).
        expect(json['directions_type'], 'maneuvers');
        expect(json['directions_options'], {
          'units': 'kilometers',
          'language': 'en-US',
        });
        expect(json.containsKey('costing_options'), isFalse);

        final locations = json['locations']! as List<Object?>;
        expect(locations[0], {'lat': 3.1579, 'lon': 101.7116});
        expect(locations[1], {'lat': 2.7456, 'lon': 101.7072});
      },
    );

    test('heading dihantar hanya untuk asal, dan hanya jika diketahui', () {
      final withHeading = buildRouteRequest(
        const RouteQuery(origin: klcc, destination: klia, headingDegrees: 90),
      );
      final locations = withHeading['locations']! as List<Object?>;
      expect((locations[0]! as Map)['heading'], 90);
      expect((locations[1]! as Map).containsKey('heading'), isFalse);

      final without = buildRouteRequest(
        const RouteQuery(origin: klcc, destination: klia),
      );
      expect(
        ((without['locations']! as List<Object?>)[0]! as Map).containsKey(
          'heading',
        ),
        isFalse,
      );
    });

    test('elak tol menghantar use_tolls = 0 secara eksplisit', () {
      final json = buildRouteRequest(
        const RouteQuery(origin: klcc, destination: klia, avoidTolls: true),
      );
      expect(json['costing_options'], {
        'auto': {'use_tolls': 0},
      });
    });

    test(
      'boleh diserialisasi ke JSON (tiada nilai null atau objek bukan JSON)',
      () {
        final text = jsonEncode(
          buildRouteRequest(
            const RouteQuery(
              origin: klcc,
              destination: klia,
              headingDegrees: 0,
              avoidTolls: true,
            ),
          ),
        );
        expect(text, isNot(contains('null')));
        // heading 0 (utara) ialah nilai sah dan MESTI dihantar (bukan dianggap "tiada").
        expect(text, contains('"heading":0'));
      },
    );
  });

  group('parseRouteResponse (respons sebenar Valhalla 3.5.1 tempatan)', () {
    late List<RouteOption> routes;
    setUpAll(
      () => routes = parseRouteResponse(
        _fixture('valhalla_klcc_klia.json'),
        source: RouteSource.offline,
      ),
    );

    test('laluan utama + alternatif, bertanda sumber', () {
      expect(routes, hasLength(2));
      expect(routes.every((r) => r.source == RouteSource.offline), isTrue);
    });

    test('ringkasan: 67.049 km, 3477 s, tol', () {
      final main = routes.first;
      expect(main.distanceM, 67049);
      expect(main.durationS, 3477);
      expect(main.hasTolls, isTrue);
    });

    test('geometri polyline6 dinyahkod: 1402 titik KLCC -> KLIA', () {
      final points = routes.first.points;
      expect(points, hasLength(1402));
      expect(points.first.lat, closeTo(3.1579, 0.01));
      expect(points.last.lat, closeTo(2.7456, 0.01));
    });

    test(
      'manuver: 31, nama jalan, indeks bermula menaik dan dalam julat titik',
      () {
        final m = routes.first.maneuvers;
        expect(m, hasLength(31));
        expect(m.first.type, 1);
        expect(m.first.streetNames, ['Lorong Kuda']);
        expect(m.first.lengthM, 390);

        var prev = -1;
        for (final mv in m) {
          expect(mv.beginShapeIndex, greaterThanOrEqualTo(prev));
          expect(mv.beginShapeIndex, lessThan(routes.first.points.length));
          expect(mv.streetNames, isA<List<String>>());
          prev = mv.beginShapeIndex;
        }
        // Jumlah panjang manuver hampir sama dengan jarak laluan (beza hanya pembundaran).
        final sum = m.fold<int>(0, (a, b) => a + b.lengthM);
        expect((sum - routes.first.distanceM).abs(), lessThan(50));
      },
    );

    test('alternatif ialah laluan berbeza', () {
      expect(routes[1].points.length, isNot(routes.first.points.length));
      expect(routes[1].distanceM, greaterThan(routes.first.distanceM));
    });
  });

  group('parseRouteResponse (respons sebenar server awam FOSSGIS)', () {
    test('format sama; 3 laluan; data lebih segar memberi ETA berbeza', () {
      final routes = parseRouteResponse(
        _fixture('valhalla_public_klcc_klia.json'),
        source: RouteSource.online,
      );
      expect(routes, hasLength(3));
      expect(routes.first.maneuvers, isNotEmpty);
      expect(routes.first.distanceM, closeTo(68681, 1));
    });
  });

  group('parseRouteResponse: ralat', () {
    final cases = {
      171: RoutingFailureKind
          .noRoute, // tiada jalan berhampiran (laut/luar liputan)
      170: RoutingFailureKind.noRoute, // wilayah tidak bersambung
      154: RoutingFailureKind.noRoute, // jarak melebihi had
      442: RoutingFailureKind
          .noRoute, // tiada laluan (server awam, destinasi di laut)
      110: RoutingFailureKind
          .invalidRequest, // parameter tidak mencukupi: bug permintaan kita
    };
    cases.forEach((code, kind) {
      test('error_code $code -> $kind', () {
        final failure = _parseFailure(
          jsonEncode({'error_code': code, 'error': 'x', 'status_code': 400}),
        );
        expect(failure.kind, kind);
      });
    });

    test('badan bukan JSON -> generic, bukan FormatException', () {
      expect(
        _parseFailure('<html>Bad gateway</html>').kind,
        RoutingFailureKind.generic,
      );
    });

    test('JSON bukan objek -> generic', () {
      expect(_parseFailure('[1,2]').kind, RoutingFailureKind.generic);
      expect(_parseFailure(null).kind, RoutingFailureKind.generic);
    });

    test('trip tanpa leg atau medan hilang -> generic', () {
      expect(
        _parseFailure('{"trip":{"legs":[],"summary":{}}}').kind,
        RoutingFailureKind.generic,
      );
      expect(_parseFailure('{"trip":{}}').kind, RoutingFailureKind.generic);
      expect(_parseFailure('{}').kind, RoutingFailureKind.generic);
    });

    test('geometri rosak -> generic', () {
      final body = jsonEncode({
        'trip': {
          'summary': {'length': 1.0, 'time': 60.0, 'has_toll': false},
          'legs': [
            {
              'shape': 'abc def',
              'summary': <String, Object>{},
              'maneuvers': <Object>[],
            },
          ],
        },
      });
      expect(_parseFailure(body).kind, RoutingFailureKind.generic);
    });

    test('menerima Map yang sudah dinyahkod (bukan hanya String)', () {
      final map = jsonDecode(_fixture('valhalla_klcc_klia.json'));
      expect(parseRouteResponse(map, source: RouteSource.online), hasLength(2));
    });
  });

  group('valhallaErrorCodeFromText', () {
    test('mengeluarkan kod daripada mesej pengecualian enjin', () {
      expect(
        valhallaErrorCodeFromText(
          'ValhallaException: {"error_code":171,"error":"No suitable edges"}',
        ),
        171,
      );
      expect(valhallaErrorCodeFromText('{"error_code": 442}'), 442);
    });

    test('null jika tiada kod', () {
      expect(valhallaErrorCodeFromText('NullPointerException: boom'), isNull);
      expect(valhallaErrorCodeFromText(''), isNull);
    });
  });

  test('GeoPoint digunakan oleh RouteQuery kekal sama nilai', () {
    expect(const GeoPoint(1, 2), const GeoPoint(1, 2));
  });
}
