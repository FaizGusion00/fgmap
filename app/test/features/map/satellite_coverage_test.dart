import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/data/satellite_coverage_service.dart';
import 'package:fgmap/features/map/domain/satellite_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

const esri =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
// Jalan Haji Mashudi, Jenjarom (jubin z19 sebenar yang disemak terhadap perkhidmatan Esri).
const jenjarom = GeoPoint(2.8915905, 101.5224066);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody tilemap(int ones, int total) => ResponseBody.fromString(
  jsonEncode({
    'data': [for (var i = 0; i < total; i++) i < ones ? 1 : 0],
    'valid': true,
  }),
  200,
);

SatelliteCoverageService service(FakeAdapter a, {String url = esri}) {
  final dio = Dio()..httpClientAdapter = a;
  return SatelliteCoverageService(tilesUrl: url, dio: dio);
}

void main() {
  group('matematik jubin', () {
    test('Jenjarom z19 = jubin yang disahkan pada perkhidmatan Esri', () {
      final t = SatelliteCoverage.tileOf(jenjarom, 19);
      expect(t.x, 409996);
      expect(t.y, 257931);
    });

    test('z17 dan z18 sepadan dengan keturunan z19', () {
      final z19 = SatelliteCoverage.tileOf(jenjarom, 19);
      final z18 = SatelliteCoverage.tileOf(jenjarom, 18);
      expect(z18.x, z19.x >> 1);
      expect(z18.y, z19.y >> 1);
    });

    test('kutub dan garis tarikh dihad dalam julat sah', () {
      const n = 1 << 19;
      for (final p in const [
        GeoPoint(89.9, 179.999),
        GeoPoint(-89.9, -179.999),
        GeoPoint(0, 0),
      ]) {
        final t = SatelliteCoverage.tileOf(p, 19);
        expect(t.x, inInclusiveRange(0, n - 1));
        expect(t.y, inInclusiveRange(0, n - 1));
      }
    });

    test('titik berdekatan berkongsi sel cache; titik jauh tidak', () {
      final a = SatelliteCoverage.cellKey(jenjarom);
      final near = SatelliteCoverage.cellKey(
        destinationPoint(jenjarom, 90, 20),
      );
      final far = SatelliteCoverage.cellKey(
        destinationPoint(jenjarom, 90, 2000),
      );
      expect(near, a);
      expect(far, isNot(a));
    });
  });

  group('tilemapUri', () {
    test(
      'diterbitkan daripada URL jubin Esri: blok 8x8 berpusat, baris dahulu',
      () {
        final uri = SatelliteCoverage.tilemapUri(esri, jenjarom)!;
        expect(uri.host, 'server.arcgisonline.com');
        expect(
          uri.path,
          '/ArcGIS/rest/services/World_Imagery/MapServer/tilemap/19/'
          '${257931 - 4}/${409996 - 4}/8/8',
        );
        expect(uri.queryParameters['f'], 'json');
      },
    );

    test('token pada URL dikekalkan', () {
      final uri = SatelliteCoverage.tilemapUri('$esri?token=abc', jenjarom)!;
      expect(uri.queryParameters['token'], 'abc');
      expect(uri.queryParameters['f'], 'json');
    });

    test('penyedia bukan Esri: null (kekal pada z18)', () {
      expect(
        SatelliteCoverage.tilemapUri(
          'https://t.example/{z}/{x}/{y}.jpg',
          jenjarom,
        ),
        isNull,
      );
      expect(SatelliteCoverage.tilemapUri('', jenjarom), isNull);
    });
  });

  group('availableFraction dan keputusan', () {
    test('menghitung pecahan jubin yang ada', () {
      expect(
        SatelliteCoverage.availableFraction('{"data":[1,1,1,1],"valid":true}'),
        1,
      );
      expect(
        SatelliteCoverage.availableFraction('{"data":[1,0,0,0],"valid":true}'),
        0.25,
      );
      expect(
        SatelliteCoverage.availableFraction('{"data":[0,0],"valid":true}'),
        0,
      );
    });

    test('jawapan rosak: null, bukan "tiada"', () {
      for (final bad in [
        '',
        'bukan json',
        '[]',
        '{}',
        '{"data":[]}',
        '{"data":"x"}',
        '{"data":[1,"a"]}',
        '{"data":[1],"valid":false}',
      ]) {
        expect(SatelliteCoverage.availableFraction(bad), isNull, reason: bad);
      }
    });

    test('ambang 90%: tepi liputan kekal pada z18', () {
      expect(SatelliteCoverage.hiAvailable(1), isTrue);
      expect(SatelliteCoverage.hiAvailable(0.9), isTrue);
      expect(SatelliteCoverage.hiAvailable(0.89), isFalse);
      expect(SatelliteCoverage.hiAvailable(0), isFalse);
      expect(SatelliteCoverage.hiAvailable(null), isFalse);
    });
  });

  group('SatelliteCoverageService', () {
    test(
      'ada liputan: benar, disimpan, permintaan kedua tiada rangkaian',
      () async {
        final a = FakeAdapter((_) => tilemap(64, 64));
        final s = service(a);
        expect(await s.hiAvailableAt(jenjarom), isTrue);
        expect(
          await s.hiAvailableAt(destinationPoint(jenjarom, 0, 30)),
          isTrue,
        );
        expect(a.requests, hasLength(1));
        expect(s.cachedAt(jenjarom), isTrue);
      },
    );

    test('tiada liputan: palsu dan juga disimpan', () async {
      final a = FakeAdapter((_) => tilemap(0, 64));
      final s = service(a);
      expect(await s.hiAvailableAt(jenjarom), isFalse);
      expect(await s.hiAvailableAt(jenjarom), isFalse);
      expect(a.requests, hasLength(1));
    });

    test('permintaan serentak bagi sel yang sama dikongsi', () async {
      final a = FakeAdapter((_) => tilemap(64, 64));
      final s = service(a);
      final results = await Future.wait([
        s.hiAvailableAt(jenjarom),
        s.hiAvailableAt(jenjarom),
        s.hiAvailableAt(jenjarom),
      ]);
      expect(results, [true, true, true]);
      expect(a.requests, hasLength(1));
    });

    test('rangkaian gagal: null dan TIDAK disimpan (dicuba lagi)', () async {
      var fail = true;
      final a = FakeAdapter((o) {
        if (fail) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        return tilemap(64, 64);
      });
      final s = service(a);
      expect(await s.hiAvailableAt(jenjarom), isNull);
      expect(s.cachedAt(jenjarom), isNull);
      fail = false;
      expect(await s.hiAvailableAt(jenjarom), isTrue);
      expect(a.requests, hasLength(2));
    });

    test('jawapan rosak: null dan tidak disimpan', () async {
      final a = FakeAdapter((_) => ResponseBody.fromString('<html>', 200));
      final s = service(a);
      expect(await s.hiAvailableAt(jenjarom), isNull);
      expect(s.cachedAt(jenjarom), isNull);
    });

    test('penyedia bukan Esri: null tanpa sebarang permintaan', () async {
      final a = FakeAdapter((_) => tilemap(64, 64));
      final s = service(a, url: 'https://t.example/{z}/{x}/{y}.jpg');
      expect(await s.hiAvailableAt(jenjarom), isNull);
      expect(a.requests, isEmpty);
    });

    test('cache terhad: entri tertua dibuang', () async {
      final a = FakeAdapter((_) => tilemap(64, 64));
      final s = SatelliteCoverageService(
        tilesUrl: esri,
        dio: Dio()..httpClientAdapter = a,
        maxEntries: 2,
      );
      const p0 = jenjarom;
      final p1 = destinationPoint(jenjarom, 90, 1000);
      final p2 = destinationPoint(jenjarom, 90, 2000);
      await s.hiAvailableAt(p0);
      await s.hiAvailableAt(p1);
      await s.hiAvailableAt(p2);
      expect(s.cachedAt(p0), isNull);
      expect(s.cachedAt(p1), isTrue);
      expect(s.cachedAt(p2), isTrue);
    });
  });
}
