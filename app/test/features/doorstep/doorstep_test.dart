import 'package:dio/dio.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/doorstep/data/osm_entrances.dart';
import 'package:fgmap/features/doorstep/data/saved_entrances.dart';
import 'package:fgmap/features/doorstep/domain/entrance.dart';
import 'package:fgmap/features/doorstep/presentation/doorstep_controller.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pratonton palsu: planTo hanya merekod destinasi (tiada GPS/rangkaian).
class _Preview extends RoutePreviewController {
  final planned = <(GeoPoint, String?)>[];

  @override
  RoutePreviewState build() => const RouteIdle();

  @override
  Future<void> planTo(
    GeoPoint destination, {
    String? destinationLabel,
    double? radiusM,
    List<GeoPoint> via = const [],
  }) async {
    planned.add((destination, destinationLabel));
    state = RouteLoading(
      destination: destination,
      destinationLabel: destinationLabel,
    );
  }
}

void main() {
  group('classifyEntrance', () {
    test('jenis daripada tag OSM', () {
      expect(classifyEntrance({'entrance': 'main'}), EntranceKind.main);
      expect(
        classifyEntrance({'amenity': 'parking_entrance'}),
        EntranceKind.parking,
      );
      expect(
        classifyEntrance({'entrance': 'service', 'name': 'Loading Bay B'}),
        EntranceKind.loading,
      );
      expect(classifyEntrance({'entrance': 'service'}), EntranceKind.service);
      expect(
        classifyEntrance({'building': 'guardhouse'}),
        EntranceKind.visitor,
      );
      expect(
        classifyEntrance({'barrier': 'lift_gate', 'name': 'Pondok Pengawal'}),
        EntranceKind.visitor,
      );
      expect(classifyEntrance({'barrier': 'gate'}), EntranceKind.gate);
      expect(
        classifyEntrance({'entrance': 'yes', 'ref': 'A'}),
        EntranceKind.door,
      );
    });

    test(
      'kecemasan, keluar sahaja, tangga dalaman dan dilarang: bukan pintu',
      () {
        expect(classifyEntrance({'entrance': 'emergency'}), isNull);
        expect(classifyEntrance({'entrance': 'exit'}), isNull);
        expect(classifyEntrance({'entrance': 'staircase'}), isNull);
        expect(classifyEntrance({'barrier': 'gate', 'access': 'no'}), isNull);
        expect(classifyEntrance({'shop': 'yes'}), isNull);
      },
    );

    test('label blok/tower/nombor', () {
      expect(
        entranceDetail({'name': 'Tower B', 'ref': 'B2', 'addr:unit': 'B2'}),
        'Tower B · B2',
      );
      expect(entranceDetail({}), isNull);
    });
  });

  test(
    'rankEntrances: pintu bangunan destinasi dahulu, pendua dibuang, had setiap jenis',
    () {
      const place = GeoPoint(3.1488, 101.7133);
      Entrance e(double dLat, EntranceKind k, {bool on = false}) => Entrance(
        point: GeoPoint(place.lat + dLat, place.lng),
        kind: k,
        onBuilding: on,
      );
      final ranked = rankEntrances([
        e(0.0003, EntranceKind.parking),
        e(0.0010, EntranceKind.main, on: true),
        e(0.00031, EntranceKind.parking), // < 8 m daripada yang pertama: pendua
        e(0.0005, EntranceKind.parking),
        e(0.0007, EntranceKind.parking), // melebihi had 2 setiap jenis
        e(0.0001, EntranceKind.gate),
      ], place);
      expect(ranked.first.kind, EntranceKind.main);
      expect(ranked.first.onBuilding, isTrue);
      expect(ranked.where((x) => x.kind == EntranceKind.parking), hasLength(2));
      expect(ranked[1].kind, EntranceKind.gate);
      expect(ranked[1].distanceM, closeTo(11, 1));
    },
  );

  test('parseEntrances: bangunan yang MENGANDUNGI pin menandakan pintunya', () {
    const body = '''
{"elements":[
 {"type":"way","id":1,"tags":{"building":"retail","name":"Pavilion"},
  "geometry":[{"lat":3.1490,"lon":101.7130},{"lat":3.1490,"lon":101.7140},{"lat":3.1480,"lon":101.7140},{"lat":3.1480,"lon":101.7130},{"lat":3.1490,"lon":101.7130}]},
 {"type":"way","id":9,"tags":{"building":"yes"},
  "geometry":[{"lat":3.1500,"lon":101.7150},{"lat":3.1500,"lon":101.7160},{"lat":3.1495,"lon":101.7160},{"lat":3.1495,"lon":101.7150},{"lat":3.1500,"lon":101.7150}]},
 {"type":"node","id":2,"lat":3.1490,"lon":101.7130,"tags":{"entrance":"main"}},
 {"type":"node","id":3,"lat":3.1500,"lon":101.7150,"tags":{"amenity":"parking_entrance","name":"P2"}},
 {"type":"way","id":4,"center":{"lat":3.1480,"lon":101.7120},"tags":{"building":"guardhouse"}},
 {"type":"node","id":5,"lat":3.1481,"lon":101.7121,"tags":{"entrance":"emergency"}}
]}''';
    final list = parseEntrances(body, place: const GeoPoint(3.1485, 101.7135));
    expect(list, hasLength(3));
    expect(list[0].kind, EntranceKind.main);
    expect(list[0].onBuilding, isTrue);
    // Pintu bangunan jiran (pin tidak di dalamnya): bukan pintu destinasi.
    expect(list[1].onBuilding, isFalse);
    expect(list[1].detail, 'P2');
    expect(list[2].kind, EntranceKind.visitor);
    // Tanpa pin: tiada penandaan.
    expect(parseEntrances(body).any((e) => e.onBuilding), isFalse);
    expect(() => parseEntrances(''), throwsFormatException);
  });

  test(
    'pertanyaan Overpass: bangunan berhampiran + pintu sekitar (tanpa is_in yang berat)',
    () {
      final q = OsmEntranceSearch.queryFor(const GeoPoint(3.1, 101.7));
      expect(q, isNot(contains('is_in')));
      expect(q, contains('way(around:60,3.100000,101.700000)["building"]'));
      expect(q, contains('node(around:200,3.100000,101.700000)["entrance"]'));
      expect(q, contains('parking_entrance'));
    },
  );

  test(
    'cache telefon: hasil disimpan, dibaca semula tanpa rangkaian, luput 30 hari',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const place = GeoPoint(3.14897, 101.71337);
      const key = '${entranceCachePrefix}3.14897,101.71337';
      await prefs.setString(
        key,
        '{"at":${DateTime(2026, 11, 1).millisecondsSinceEpoch},"e":[{"lat":3.149,"lng":101.713,"k":"main","d":"A","b":true}]}',
      );
      final search = OsmEntranceSearch(Dio(), const [], prefs: prefs);
      final hit = await search.near(place, now: DateTime(2026, 11, 6));
      expect(hit, hasLength(1));
      expect(hit!.single.kind, EntranceKind.main);
      expect(hit.single.onBuilding, isTrue);
      // Luput: cache diabaikan (tiada cermin = carian dimatikan, senarai kosong).
      final stale = OsmEntranceSearch(Dio(), const [], prefs: prefs);
      expect(await stale.near(place, now: DateTime(2027, 1, 1)), isEmpty);
    },
  );

  group('pintu lalai pengguna', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer make() => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routePreviewControllerProvider.overrideWith(_Preview.new),
        osmEntranceSearchProvider.overrideWithValue(
          OsmEntranceSearch(Dio(), const []),
        ),
      ],
    );

    test(
      'disimpan, dipadankan dalam 150 m, kekal selepas mula semula',
      () async {
        const place = GeoPoint(3.0716, 101.4900);
        final c = make();
        addTearDown(c.dispose);
        await c
            .read(savedEntrancesProvider.notifier)
            .save(
              place,
              const Entrance(
                point: GeoPoint(3.0720, 101.4905),
                kind: EntranceKind.saved,
              ),
              placeName: 'Hospital',
            );
        final c2 = make();
        addTearDown(c2.dispose);
        final s = c2.read(savedEntrancesProvider.notifier);
        expect(
          s.forPlace(const GeoPoint(3.0717, 101.4901))?.placeName,
          'Hospital',
        );
        expect(s.forPlace(const GeoPoint(3.0800, 101.4900)), isNull);
        await s.remove(place);
        expect(c2.read(savedEntrancesProvider), isEmpty);
      },
    );

    test(
      'destinasi baharu dengan pintu lalai: laluan terus ke pintu itu',
      () async {
        const place = GeoPoint(3.0716, 101.4900);
        const door = GeoPoint(3.0730, 101.4910);
        final c = make();
        addTearDown(c.dispose);
        await c
            .read(savedEntrancesProvider.notifier)
            .save(place, const Entrance(point: door, kind: EntranceKind.saved));
        c.listen(doorstepProvider, (_, _) {});
        final preview =
            c.read(routePreviewControllerProvider.notifier) as _Preview;
        await preview.planTo(place, destinationLabel: 'Hospital Shah Alam');
        await Future<void>.delayed(Duration.zero);
        expect(preview.planned.last.$1, door);
        expect(preview.planned.last.$2, 'Hospital Shah Alam');
        final state = c.read(doorstepProvider);
        expect(state.place, place);
        expect(state.selected?.point, door);

        // Kembali ke pin: tempat sama, tiada pintu; pintu lalai tidak dipaksa semula.
        await c.read(doorstepProvider.notifier).usePin();
        await Future<void>.delayed(Duration.zero);
        expect(preview.planned.last.$1, place);
        expect(c.read(doorstepProvider).selected, isNull);
      },
    );
  });
}
