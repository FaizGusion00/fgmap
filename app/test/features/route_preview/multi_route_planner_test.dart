import 'dart:async';

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
            durationS: 3800,
            distanceM: 64000,
            hasTolls: false,
            points: _path(0.06),
          ),
        ];
      }
      if (q.avoidHighways) {
        return [
          sampleOption(
            durationS: 3700,
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
      stagger: Duration.zero,
      retryDelay: Duration.zero,
    );
  });

  test(
    'semua pilihan terpapar: utama, tanpa tol, tanpa lebuh raya (permintaan dihad)',
    () async {
      final options = await planner.plan(_query);

      expect(
        options.map((o) => o.label),
        containsAll([
          RouteLabel.recommended,
          RouteLabel.noTolls,
          RouteLabel.noHighways,
        ]),
      );
      // Permintaan asas membawa alternatif Valhalla; permintaan tambahan hanya satu laluan.
      expect(online.queries.first.alternates, 2);
      final extra = online.queries.skip(1).toList();
      expect(options.first.label, RouteLabel.recommended);
      expect(extra, hasLength(10), reason: 'dihadkan maxExtra');
      expect(extra.every((q) => q.alternates == 0), isTrue);
      expect(extra.any((q) => q.avoidTolls && !q.avoidHighways), isTrue);
      expect(extra.any((q) => q.avoidHighways && !q.avoidTolls), isTrue);
      expect(extra.any((q) => q.shortest), isTrue);
      expect(extra.where((q) => q.exclusions.isNotEmpty), hasLength(1));
      expect(extra.where((q) => q.via.isNotEmpty), hasLength(6));
    },
  );

  test(
    'berperingkat: laluan biasa dahulu, kemudian setiap alternatif tiba',
    () async {
      final batches = await planner.watch(_query).toList();

      expect(batches.first.done, isFalse);
      expect(
        batches.first.options,
        hasLength(1),
        reason: 'laluan biasa sahaja',
      );
      expect(batches.last.done, isTrue);
      expect(batches.last.options.length, greaterThan(1));
      // Bilangan pilihan tidak pernah berkurang semasa alternatif tiba.
      final counts = [for (final b in batches) b.options.length];
      expect([...counts]..sort(), counts);
      // Hanya kumpulan terakhir ditandakan siap.
      expect(batches.where((b) => b.done), hasLength(1));
    },
  );

  test('titik lalu menghasilkan laluan alternatif yang berbeza', () async {
    online.handler = (q) async {
      if (q.via.isNotEmpty) {
        // Sisi titik lalu (kiri/kanan laluan lurus) menentukan arah lencongan.
        final v = q.via.single;
        final side =
            ((v.lat - klcc.lat) * (klia.lng - klcc.lng) -
                    (v.lng - klcc.lng) * (klia.lat - klcc.lat))
                .sign;
        return [
          sampleOption(
            durationS: 3200,
            distanceM: 63000,
            hasTolls: false,
            points: _path(side > 0 ? 0.05 : -0.05),
          ),
        ];
      }
      return [tolled()];
    };

    final options = await planner.plan(_query);

    // Utama + kedua-dua arah titik lalu (utara/selatan) yang berbeza.
    expect(options.length, greaterThanOrEqualTo(3));
    expect(options.first.label, RouteLabel.recommended);
  });

  test(
    'kegagalan sistem (429) menghentikan permintaan tambahan seterusnya',
    () async {
      planner = MultiRoutePlanner(
        primary: online,
        forSource: (_) => online,
        maxConcurrent: 1,
        stagger: Duration.zero,
      );
      online.handler = (q) async {
        if (q.alternates == 0) {
          throw const RoutingFailure(RoutingFailureKind.rateLimited);
        }
        return [tolled()];
      };

      final batches = await planner.watch(_query).toList();

      // 1 asas + hanya 1 permintaan tambahan sebelum berhenti.
      expect(online.queries, hasLength(2));
      expect(batches.last.done, isTrue);
      expect(batches.last.options, hasLength(1));
    },
  );

  test(
    'tiada laluan untuk satu permintaan (442): yang lain diteruskan',
    () async {
      online.handler = (q) async {
        if (q.shortest) throw const RoutingFailure(RoutingFailureKind.noRoute);
        return [tolled()];
      };

      await planner.plan(_query);

      expect(
        online.queries,
        hasLength(11),
        reason: 'noRoute bukan kegagalan sistem',
      );
    },
  );

  test(
    'kegagalan sementara (timeout) dicuba semula sekali dan berjaya',
    () async {
      var failedOnce = false;
      online.handler = (q) async {
        if (q.via.isNotEmpty && !failedOnce) {
          failedOnce = true;
          throw const RoutingFailure(RoutingFailureKind.timeout);
        }
        return [tolled()];
      };

      await planner.plan(_query);

      expect(
        online.queries,
        hasLength(12),
        reason: '1 asas + 10 tambahan + 1 cuba semula',
      );
    },
  );

  test(
    '3 kegagalan sementara berturutan menghentikan permintaan tambahan',
    () async {
      planner = MultiRoutePlanner(
        primary: online,
        forSource: (_) => online,
        maxConcurrent: 1,
        stagger: Duration.zero,
        retryDelay: Duration.zero,
      );
      online.handler = (q) async {
        if (q.alternates == 0) {
          throw const RoutingFailure(RoutingFailureKind.timeout);
        }
        return [tolled()];
      };

      final batches = await planner.watch(_query).toList();

      // 1 asas + 3 permintaan x 2 percubaan.
      expect(online.queries, hasLength(7));
      expect(batches.last.done, isTrue);
    },
  );

  test('serentak tidak melebihi maxConcurrent', () async {
    var inFlight = 0;
    var peak = 0;
    online.handler = (q) async {
      if (q.alternates == 2) return [tolled()];
      inFlight++;
      if (inFlight > peak) peak = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      inFlight--;
      return [tolled()];
    };

    await planner.plan(_query);

    expect(peak, 2);
  });

  test('membatalkan langganan menghentikan permintaan tambahan', () async {
    planner = MultiRoutePlanner(
      primary: online,
      forSource: (_) => online,
      maxConcurrent: 1,
      stagger: Duration.zero,
    );
    final firstExtra = Completer<void>();
    online.handler = (q) async {
      if (q.alternates == 2) return [tolled()];
      await firstExtra.future;
      return [tolled()];
    };

    final sub = planner.watch(_query).listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    firstExtra.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      online.queries,
      hasLength(2),
      reason: 'tiada permintaan selepas batal',
    );
  });

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
    expect(options.single.label, RouteLabel.recommended);
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
        stagger: Duration.zero,
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
