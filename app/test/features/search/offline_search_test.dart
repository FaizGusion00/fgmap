import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/data/offline_geocoder.dart';
import 'package:fgmap/features/search/data/offline_places_db.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/nearby_category.dart';
import 'package:fgmap/features/search/domain/offline_place.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:flutter_test/flutter_test.dart';

const _kl = GeoPoint(3.139, 101.687);

OfflinePlaceRow _row(
  String name, {
  int cat = OfflinePlaceCat.settlement,
  String kind = 'town',
  int rank = 50,
  GeoPoint point = _kl,
  String? area,
}) => OfflinePlaceRow(
  name: name,
  kind: kind,
  cat: cat,
  point: point,
  rank: rank,
  area: area,
);

/// Indeks palsu (tanpa SQLite): carian teks dan kotak ditapis dalam ingatan.
class _FakeDb extends OfflinePlacesDb {
  _FakeDb(this.rows) : super(() async => null);

  final List<OfflinePlaceRow> rows;

  @override
  Future<bool> get available async => rows.isNotEmpty;

  @override
  Future<List<OfflinePlaceRow>> search(
    String text, {
    GeoPoint? near,
    int limit = 20,
  }) async {
    final q = text.toLowerCase();
    return rankOfflinePlaces(
      [
        for (final r in rows)
          if (r.name.toLowerCase().contains(q)) r,
      ],
      text,
      near: near,
      limit: limit,
    );
  }

  @override
  Future<List<OfflinePlaceRow>> inBox(
    List<int> cats,
    (double, double, double, double) box, {
    int limit = 500,
  }) async {
    final (s, w, n, e) = box;
    return [
      for (final r in rows)
        if (cats.contains(r.cat) &&
            r.point.lat >= s &&
            r.point.lat <= n &&
            r.point.lng >= w &&
            r.point.lng <= e)
          r,
    ];
  }
}

class _Online implements Geocoder {
  _Online({this.results = const [], this.fail = false});

  final List<Place> results;
  final bool fail;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
    }
    return results;
  }
}

void main() {
  test('ungkapan FTS: setiap perkataan awalan, tanda baca dibuang', () {
    expect(ftsMatchQuery('Jalan Amp'), '(jalan* OR jln*) amp*');
    expect(ftsMatchQuery('R&R Tapah'), 'r* r* tapah*');
    expect(ftsMatchQuery('stesen kl'), '(stesen* OR station* OR stn*) kl*');
    expect(ftsMatchQuery("McDonald's"), 'mcdonalds*');
    expect(ftsMatchQuery('  ,. '), isNull);
  });

  test('susunan: nama tepat menang, pendua dibuang, jarak dikira', () {
    final rows = [
      _row(
        'Masjid Putra Heights',
        kind: 'mosque',
        cat: 4,
        rank: 40,
        point: const GeoPoint(3.20, 101.70),
      ),
      _row(
        'Masjid Putra',
        kind: 'mosque',
        cat: 4,
        rank: 40,
        point: const GeoPoint(3.141, 101.688),
      ),
      _row(
        'Masjid Putra Heights',
        kind: 'mosque',
        cat: 4,
        rank: 40,
        point: const GeoPoint(3.20, 101.70),
      ),
    ];
    final out = rankOfflinePlaces(rows, 'masjid putra', near: _kl);
    expect(out.first.name, 'Masjid Putra');
    expect(out, hasLength(2));
  });

  test('tanpa internet: hasil daripada indeks offline', () async {
    final g = OfflineAwareGeocoder(
      _Online(fail: true),
      _FakeDb([_row('Kuala Terengganu', kind: 'city', rank: 100)]),
    );
    final out = await g.search('kuala terengganu', near: _kl);
    expect(out.single.name, 'Kuala Terengganu');
  });

  test('tanpa internet dan tanpa indeks: ralat asal dilempar', () async {
    final g = OfflineAwareGeocoder(_Online(fail: true), _FakeDb(const []));
    expect(() => g.search('x'), throwsA(isA<DioException>()));
  });

  test('dalam talian sedikit hasil: tambahan offline tanpa pendua', () async {
    final g = OfflineAwareGeocoder(
      _Online(
        results: const [
          Place(name: 'KLCC', subtitle: 'Kuala Lumpur', point: _kl),
        ],
      ),
      _FakeDb([
        _row('KLCC', rank: 60),
        _row('Suria KLCC', rank: 62, point: const GeoPoint(3.158, 101.712)),
      ]),
    );
    final out = await g.search('klcc', near: _kl);
    expect(out.map((p) => p.name), ['KLCC', 'Suria KLCC']);
    expect(out.last.fromOffline, isTrue);
  });

  test('ambang gabungan 12: hasil dalam talian jarang digabung offline', () async {
    final online = [
      for (var i = 0; i < 8; i++)
        Place(
          name: 'Spot Online $i',
          subtitle: '',
          point: GeoPoint(3.14 + i * 0.01, 101.68),
        ),
    ];
    final offline = [
      for (var i = 0; i < 10; i++)
        _row(
          'Spot Offline $i',
          rank: 40 - i,
          point: GeoPoint(3.20 + i * 0.01, 101.70),
        ),
    ];
    final g = OfflineAwareGeocoder(_Online(results: online), _FakeDb(offline));
    final out = await g.search('spot', near: _kl);
    expect(out.length, 12);
    expect(out.take(8).every((p) => !p.fromOffline), isTrue);
    expect(out.skip(8).every((p) => p.fromOffline), isTrue);
  });

  test('ambang 12: dalam talian cukup tidak digabung', () async {
    final online = [
      for (var i = 0; i < 12; i++)
        Place(
          name: 'Spot Online $i',
          subtitle: '',
          point: GeoPoint(3.14 + i * 0.01, 101.68),
        ),
    ];
    final g = OfflineAwareGeocoder(
      _Online(results: online),
      _FakeDb([_row('Spot Offline X', point: const GeoPoint(4, 102))]),
    );
    final out = await g.search('spot', near: _kl);
    expect(out, hasLength(12));
    expect(out.every((p) => !p.fromOffline), isTrue);
  });

  test('berdekatan offline: kategori dipetakan, disusun ikut jarak', () async {
    final db = _FakeDb([
      _row(
        'Petronas Jauh',
        cat: OfflinePlaceCat.fuel,
        kind: 'fuel',
        point: const GeoPoint(3.16, 101.687),
      ),
      _row(
        '',
        cat: OfflinePlaceCat.fuel,
        kind: 'fuel',
        point: const GeoPoint(3.140, 101.687),
      ),
      _row('Masjid', cat: OfflinePlaceCat.mosque, kind: 'mosque'),
    ]);
    final r = await OfflineNearbySearch(
      db,
    ).search(NearbyCategory.fuel, _kl, fallbackName: 'Stesen minyak');
    expect(r.places.map((p) => p.name), ['Stesen minyak', 'Petronas Jauh']);
    expect(r.places.first.category, 'fuel');
  });
}
