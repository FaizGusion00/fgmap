import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

List<GeoPoint> _path(double bulge) => [
  for (var i = 0; i < 40; i++)
    GeoPoint(
      klcc.lat +
          (klia.lat - klcc.lat) * i / 39 +
          bulge * 4 * (i / 39) * (1 - i / 39),
      klcc.lng +
          (klia.lng - klcc.lng) * i / 39 +
          bulge * 4 * (i / 39) * (1 - i / 39),
    ),
];

const _query = RouteQuery(origin: klcc, destination: klia);

void main() {
  late FakeRoutePlanner online;
  late FakeRoutePlanner offline;
  late MultiRoutePlanner planner;

  RouteOption tolled() =>
      sampleOption(durationS: 3000, distanceM: 60000, points: _path(0));

  setUp(() {
    online = FakeRoutePlanner((q) async {
      if (q.avoidTolls) {
        return [
          sampleOption(
            durationS: 3900,
            distanceM: 64000,
            hasTolls: false,
            points: _path(0.06),
          ),
        ];
      }
      if (q.avoidHighways) {
        return [
          sampleOption(
            durationS: 4300,
            distanceM: 70000,
            hasTolls: false,
            points: _path(-0.06),
          ),
        ];
      }
      return [tolled()];
    });
    offline = FakeRoutePlanner((_) async => [tolled()]);
    planner = MultiRoutePlanner(
      primary: online,
      forSource: (s) => s == RouteSource.online ? online : offline,
    );
  });

  test(
    'semua pilihan terpapar dalam satu panggilan: terpantas, tanpa tol, tanpa lebuh raya',
    () async {
      final options = await planner.plan(_query);

      expect(options.map((o) => o.label), [
        RouteLabel.fastest,
        RouteLabel.noTolls,
        RouteLabel.noHighways,
      ]);
      // Permintaan asas membawa alternatif Valhalla; permintaan tambahan hanya satu laluan.
      expect(online.queries.first.alternates, 2);
      final extra = online.queries.skip(1).toList();
      expect(extra, hasLength(2));
      expect(extra.every((q) => q.alternates == 0), isTrue);
      expect(extra.any((q) => q.avoidTolls && !q.avoidHighways), isTrue);
      expect(extra.any((q) => q.avoidHighways && !q.avoidTolls), isTrue);
    },
  );

  test(
    'tiada permintaan tanpa tol bila laluan asas memang bebas tol',
    () async {
      online.handler = (q) async => [
        sampleOption(
          durationS: 3000,
          distanceM: 60000,
          hasTolls: false,
          points: _path(0),
        ),
      ];

      await planner.plan(_query);

      expect(online.queries.where((q) => q.avoidTolls), isEmpty);
    },
  );

  test('perjalanan pendek tidak meminta laluan tanpa lebuh raya', () async {
    online.handler = (q) async => [
      sampleOption(durationS: 400, distanceM: 2500, points: _path(0)),
    ];

    await planner.plan(_query);

    expect(online.queries.where((q) => q.avoidHighways), isEmpty);
  });

  test('kegagalan permintaan tambahan tidak menggagalkan pratonton', () async {
    online.handler = (q) async {
      if (q.avoidTolls || q.avoidHighways) {
        throw const RoutingFailure(RoutingFailureKind.rateLimited);
      }
      return [tolled()];
    };

    final options = await planner.plan(_query);

    expect(options, hasLength(1));
    expect(options.single.label, RouteLabel.fastest);
  });

  test('kegagalan laluan asas dilempar kepada pemanggil', () async {
    online.handler = (_) async =>
        throw const RoutingFailure(RoutingFailureKind.noRoute);

    expect(
      planner.plan(_query),
      throwsA(
        isA<RoutingFailure>().having(
          (f) => f.kind,
          'kind',
          RoutingFailureKind.noRoute,
        ),
      ),
    );
  });

  test(
    'permintaan tambahan guna sumber yang sama dengan laluan asas (offline kekal offline)',
    () async {
      final fromPack = sampleOption(
        durationS: 3000,
        distanceM: 60000,
        points: _path(0),
        source: RouteSource.offline,
      );
      final primary = FakeRoutePlanner((_) async => [fromPack]);
      offline.handler = (_) async => [
        sampleOption(
          durationS: 3800,
          distanceM: 63000,
          hasTolls: false,
          points: _path(0.06),
          source: RouteSource.offline,
        ),
      ];
      planner = MultiRoutePlanner(
        primary: primary,
        forSource: (s) => s == RouteSource.online ? online : offline,
      );

      final options = await planner.plan(
        _query.copyWith(vehicle: RouteVehicle.motorcycle),
      );

      expect(
        online.queries,
        isEmpty,
        reason: 'tidak mencuba rangkaian bila asas datang dari pek offline',
      );
      expect(
        offline.queries.every((q) => q.vehicle == RouteVehicle.motorcycle),
        isTrue,
      );
      expect(options.every((o) => o.source == RouteSource.offline), isTrue);
    },
  );
}
