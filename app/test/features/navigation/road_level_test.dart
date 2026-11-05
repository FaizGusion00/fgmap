import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/data/flyover_service.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/road_level.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jalan lurus ke utara 2 km (titik setiap ~11 m), dengan satu manuver [kind] pada 1 km.
NavRoute _north({int type = 23}) {
  final pts = [
    for (var i = 0; i <= 180; i++) GeoPoint(3.0 + i * 0.0001, 101.7),
  ];
  return NavRoute(
    RouteOption(
      distanceM: 2000,
      durationS: 120,
      hasTolls: false,
      points: pts,
      maneuvers: [
        const Maneuver(
          type: 1,
          streetNames: ['Jalan A'],
          lengthM: 1000,
          timeS: 60,
          beginShapeIndex: 0,
        ),
        Maneuver(
          type: type,
          streetNames: const ['Jalan B'],
          lengthM: 1000,
          timeS: 60,
          beginShapeIndex: 90,
        ),
        const Maneuver(
          type: 4,
          streetNames: [],
          lengthM: 0,
          timeS: 0,
          beginShapeIndex: 180,
        ),
      ],
    ),
  );
}

/// Valhalla: 23 = kekal kanan, 10 = belok kanan.
const _keepRight = 23;
const _turnRight = 10;

void main() {
  group('levelHintsFor', () {
    test('jambatan laluan sendiri bermula selepas cabang: naik jejambat', () {
      final r = _north();
      final at = r.maneuvers[1].startM;
      final hints = levelHintsFor(r, [StructureSpan(at + 60, at + 400)]);
      expect(hints, {1: LevelHint.flyover});
    });

    test('sudah di atas jejambat sebelum cabang: tiada petunjuk baharu', () {
      final r = _north();
      final at = r.maneuvers[1].startM;
      expect(levelHintsFor(r, [StructureSpan(at - 300, at + 400)]), isEmpty);
    });

    test('jambatan kecil (< 80 m, cth. jambatan sungai): diabaikan', () {
      final r = _north();
      final at = r.maneuvers[1].startM;
      expect(levelHintsFor(r, [StructureSpan(at + 50, at + 90)]), isEmpty);
    });

    test('terowong selepas cabang: laluan bawah tanah', () {
      final r = _north();
      final at = r.maneuvers[1].startM;
      expect(
        levelHintsFor(r, [StructureSpan(at + 20, at + 300, tunnel: true)]),
        {1: LevelHint.tunnel},
      );
    });

    test(
      'jejambat OSM selari 20 m di sebelah, laluan kekal bawah: ikut jalan bawah',
      () {
        final r = _north();
        // Garis jambatan selari ke utara, 20 m ke timur, dari ~900 m hingga ~1500 m.
        final bridge = [
          const GeoPoint(3.0081, 101.70018),
          const GeoPoint(3.0135, 101.70018),
        ];
        expect(levelHintsFor(r, const [], osmBridges: [bridge]), {
          1: LevelHint.underFlyover,
        });
      },
    );

    test('jejambat melintang (merentasi jalan): bukan pilihan cabang', () {
      final r = _north();
      final bridge = [
        const GeoPoint(3.0091, 101.6990),
        const GeoPoint(3.0091, 101.7010),
      ];
      expect(levelHintsFor(r, const [], osmBridges: [bridge]), isEmpty);
    });

    test(
      'belok 90 darjah di bawah jejambat: tiada "jalan bawah" (bukan cabang)',
      () {
        final r = _north(type: _turnRight);
        final bridge = [
          const GeoPoint(3.0081, 101.70018),
          const GeoPoint(3.0135, 101.70018),
        ];
        expect(levelHintsFor(r, const [], osmBridges: [bridge]), isEmpty);
      },
    );
  });

  test('satu jejambat hanya untuk manuver pertama yang menujunya', () {
    final pts = [
      for (var i = 0; i <= 180; i++) GeoPoint(3.0 + i * 0.0001, 101.7),
    ];
    final r = NavRoute(
      RouteOption(
        distanceM: 2000,
        durationS: 120,
        hasTolls: false,
        points: pts,
        maneuvers: const [
          Maneuver(
            type: 1,
            streetNames: [],
            lengthM: 1000,
            timeS: 60,
            beginShapeIndex: 0,
          ),
          Maneuver(
            type: 20,
            streetNames: [],
            lengthM: 60,
            timeS: 5,
            beginShapeIndex: 90,
          ),
          Maneuver(
            type: 10,
            streetNames: [],
            lengthM: 900,
            timeS: 55,
            beginShapeIndex: 96,
          ),
          Maneuver(
            type: 4,
            streetNames: [],
            lengthM: 0,
            timeS: 0,
            beginShapeIndex: 180,
          ),
        ],
      ),
    );
    final start = r.maneuvers[2].startM;
    final hints = levelHintsFor(r, [
      StructureSpan(start, start + 200, tunnel: true),
    ]);
    expect(hints, {1: LevelHint.tunnel});
  });

  test('structureSpansFor: tepi bersebelahan dicantum, ikut indeks bentuk', () {
    final r = _north(type: _keepRight);
    final spans = structureSpansFor(r, const [
      (beginShapeIndex: 0, endShapeIndex: 10, bridge: false, tunnel: false),
      (beginShapeIndex: 10, endShapeIndex: 20, bridge: true, tunnel: false),
      (beginShapeIndex: 20, endShapeIndex: 30, bridge: true, tunnel: false),
      (beginShapeIndex: 30, endShapeIndex: 40, bridge: false, tunnel: true),
    ]);
    expect(spans, hasLength(2));
    expect(spans.first.tunnel, isFalse);
    expect(spans.first.startM, closeTo(r.cum[10], 0.01));
    expect(spans.first.endM, closeTo(r.cum[30], 0.01));
    expect(spans.last.tunnel, isTrue);
  });

  test('suara: "Naik jejambat." / "ikut jalan bawah" ditambah pada arahan', () {
    final r = _north();
    final planner = AnnouncementPlanner(
      route: r,
      text: const InstructionText(VoiceLanguage.ms),
    )..levelHints = {1: LevelHint.flyover};
    final far = planner.update(
      alongM: r.maneuvers[1].startM - 500,
      speedMps: 15,
    );
    expect(far.single.text, endsWith('Naik jejambat.'));

    final en = AnnouncementPlanner(
      route: r,
      text: const InstructionText(VoiceLanguage.en),
    )..levelHints = {1: LevelHint.underFlyover};
    final now = en.update(alongM: r.maneuvers[1].startM - 20, speedMps: 10);
    expect(now.single.text, contains('not the flyover'));
  });

  test('Overpass: geometri jambatan dihurai; badan rosak gagal jelas', () {
    final ways = parseBridgeWays(
      '{"elements":[{"type":"way","id":1,"geometry":[{"lat":3.1,"lon":101.7},{"lat":3.11,"lon":101.7}]},'
      '{"type":"way","id":2,"geometry":[{"lat":3.1,"lon":101.7}]},{"type":"node","id":3}]}',
    );
    expect(ways, hasLength(1));
    expect(ways.single.last, const GeoPoint(3.11, 101.7));
    expect(() => parseBridgeWays('x'), throwsFormatException);
    expect(() => parseBridgeWays(''), throwsFormatException);
  });

  test('pertanyaan hanya di titik cabang (bukan belok 90 darjah)', () {
    expect(FlyoverService.forkPoints(_north()), hasLength(1));
    expect(FlyoverService.forkPoints(_north(type: _turnRight)), isEmpty);
    expect(
      FlyoverService.queryFor([const GeoPoint(3.1, 101.7)]),
      contains('way(around:300,3.10000,101.70000)["bridge"]'),
    );
  });
}
