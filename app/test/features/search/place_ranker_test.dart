import 'package:flutter_test/flutter_test.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:fgmap/features/search/domain/place_ranker.dart';

// Data SINTETIK yang meniru kes laporan pengguna (Lotus Puncak Alam). Bukan tangkapan Photon sebenar:
// container pembangunan tidak boleh mencapai Photon.
const _ranker = PlaceRanker();
const _user = GeoPoint(3.2290, 101.4260);

Place _place(
  String name,
  GeoPoint point, {
  String subtitle = 'Puncak Alam, Selangor',
  String? key,
  String? value,
  String? type,
  double? extent,
}) => Place(
  name: name,
  subtitle: subtitle,
  point: point,
  category: value,
  osmKey: key,
  osmType: type,
  extentDiagonalM: extent,
);

void main() {
  // Perhentian "(Opp)" paling dekat dengan pengguna dan datang dahulu daripada Photon.
  final oppStop = _place(
    'Lotus Puncak Alam (Opp)',
    const GeoPoint(3.2295, 101.4262),
    key: 'highway',
    value: 'bus_stop',
    type: 'N',
  );
  final stop = _place(
    'Lotus Puncak Alam',
    const GeoPoint(3.2268, 101.4270),
    key: 'highway',
    value: 'bus_stop',
    type: 'N',
  );
  final store = _place(
    "Lotus's Puncak Alam",
    const GeoPoint(3.2262, 101.4278),
    key: 'shop',
    value: 'supermarket',
    type: 'W',
    extent: 220,
  );

  group('placeKindOf', () {
    test('membezakan kedai, perhentian bas, jalan, kawasan dan alamat', () {
      expect(placeKindOf(store), PlaceKind.shopping);
      expect(placeKindOf(stop), PlaceKind.transit);
      expect(
        placeKindOf(_place('Jalan X', _user, key: 'highway', value: 'primary')),
        PlaceKind.road,
      );
      expect(
        placeKindOf(
          _place('Puncak Alam', _user, key: 'place', value: 'suburb'),
        ),
        PlaceKind.area,
      );
      expect(
        placeKindOf(_place('Petronas', _user, key: 'amenity', value: 'fuel')),
        PlaceKind.fuel,
      );
      expect(placeKindOf(_place('Tanpa jenis', _user)), PlaceKind.place);
    });
  });

  group('PlaceRanker', () {
    test('kedai sebenar mengatasi perhentian bas bernama sama', () {
      final ranked = _ranker.rank(
        [oppStop, stop, store],
        'lotus puncak alam',
        near: _user,
      );
      expect(ranked.first, store);
      expect(ranked.indexOf(oppStop), greaterThan(ranked.indexOf(stop)));
    });

    test('perhentian "(Opp)" diturunkan walaupun paling dekat', () {
      final ranked = _ranker.rank(
        [oppStop, stop],
        'lotus puncak alam',
        near: _user,
      );
      expect(ranked.first, stop);
    });

    test('pertanyaan pengangkutan awam mengangkat perhentian', () {
      final ranked = _ranker.rank(
        [store, stop, oppStop],
        'hentian bas lotus',
        near: _user,
      );
      expect(placeKindOf(ranked.first), PlaceKind.transit);
    });

    test('hasil bernama sama dan sejenis dalam 150 m digabung', () {
      final a = _place(
        'Petronas',
        const GeoPoint(3.1360, 101.6907),
        key: 'amenity',
        value: 'fuel',
      );
      final b = _place(
        'Petronas',
        const GeoPoint(3.1361, 101.6908),
        subtitle: 'Seputeh',
        key: 'amenity',
        value: 'fuel',
      );
      final far = _place(
        'Petronas',
        const GeoPoint(3.1373, 101.6731),
        key: 'amenity',
        value: 'fuel',
      );
      final ranked = _ranker.rank([a, b, far], 'petronas');
      expect(ranked, hasLength(2));
    });

    test('hasil lebih dekat diutamakan apabila padanan teks sama', () {
      final near = _place(
        'Petronas',
        const GeoPoint(3.2300, 101.4270),
        key: 'amenity',
        value: 'fuel',
      );
      final far = _place(
        'Petronas',
        const GeoPoint(3.7000, 101.9000),
        key: 'amenity',
        value: 'fuel',
      );
      expect(_ranker.rank([far, near], 'petronas', near: _user).first, near);
    });

    test('menentukan: skor sama mengekalkan susunan asal', () {
      final a = _place('Kopi A', const GeoPoint(3.20, 101.40), value: 'cafe');
      final b = _place('Kopi B', const GeoPoint(3.30, 101.50), value: 'cafe');
      expect(_ranker.rank([a, b], 'kopi'), [a, b]);
      expect(_ranker.rank([a, b], 'kopi'), [a, b]);
    });

    test('menghadkan bilangan dan tahan senarai kosong', () {
      expect(_ranker.rank(const [], 'x'), isEmpty);
      final many = [
        for (var i = 0; i < 30; i++)
          _place('Kedai $i', GeoPoint(3.0 + i * 0.01, 101.0), value: 'cafe'),
      ];
      expect(_ranker.rank(many, 'kedai', maxResults: 10), hasLength(10));
    });
  });
}
