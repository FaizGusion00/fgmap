import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/domain/route_candidates.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/route_options_merge.dart';
import 'package:fgmap/features/route_preview/domain/route_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

/// Garis lurus [a] -> [b] dengan [n] titik, dengan [bulge] darjah anjakan di tengah (0 = lurus).
List<GeoPoint> _path(GeoPoint a, GeoPoint b, {double bulge = 0, int n = 60}) {
  return [
    for (var i = 0; i < n; i++)
      GeoPoint(
        a.lat + (b.lat - a.lat) * i / (n - 1) + bulge * _hump(i / (n - 1)),
        a.lng + (b.lng - a.lng) * i / (n - 1) + bulge * _hump(i / (n - 1)),
      ),
  ];
}

double _hump(double t) => 4 * t * (1 - t);

/// Salinan [route] dengan manuver sintetik: [turns] belokan kanan dan [uTurns] pusingan-U.
RouteOption _withManeuvers(RouteOption route, {int turns = 0, int uTurns = 0}) {
  return RouteOption(
    distanceM: route.distanceM,
    durationS: route.durationS,
    hasTolls: route.hasTolls,
    points: route.points,
    maneuvers: [
      for (var i = 0; i < turns; i++)
        const Maneuver(
          type: 10,
          streetNames: [],
          lengthM: 1000,
          timeS: 60,
          beginShapeIndex: 0,
        ),
      for (var i = 0; i < uTurns; i++)
        const Maneuver(
          type: 12,
          streetNames: [],
          lengthM: 1000,
          timeS: 60,
          beginShapeIndex: 0,
        ),
    ],
  );
}

RouteOption _route({
  required int durationS,
  required int distanceM,
  required List<GeoPoint> points,
  bool hasTolls = false,
}) => sampleOption(
  durationS: durationS,
  distanceM: distanceM,
  hasTolls: hasTolls,
  points: points,
);

void main() {
  final direct = _path(klcc, klia);
  final north = _path(klcc, klia, bulge: 0.06);
  final south = _path(klcc, klia, bulge: -0.06);

  group('mergeRouteCandidates', () {
    test(
      'laluan yang sama daripada beberapa permintaan digabung menjadi satu',
      () {
        final merged = mergeRouteCandidates(
          standard: [_route(durationS: 3000, distanceM: 60000, points: direct)],
          noTolls: [_route(durationS: 3000, distanceM: 60000, points: direct)],
          noHighways: [
            _route(durationS: 3010, distanceM: 60000, points: direct),
          ],
        );

        expect(merged, hasLength(1));
        expect(merged.single.label, RouteLabel.recommended);
      },
    );

    test('laluan tanpa tol muncul serta-merta bila yang utama ada tol', () {
      final merged = mergeRouteCandidates(
        standard: [
          _route(
            durationS: 3000,
            distanceM: 60000,
            points: direct,
            hasTolls: true,
          ),
        ],
        noTolls: [_route(durationS: 3900, distanceM: 64000, points: north)],
      );

      expect(merged.map((r) => r.label), [
        RouteLabel.recommended,
        RouteLabel.noTolls,
      ]);
      expect(merged.last.hasTolls, isFalse);
    });

    test(
      'laluan bebas tol daripada alternatif Valhalla juga dilabel tanpa tol',
      () {
        final merged = mergeRouteCandidates(
          standard: [
            _route(
              durationS: 3000,
              distanceM: 60000,
              points: direct,
              hasTolls: true,
            ),
            _route(durationS: 3500, distanceM: 63000, points: north),
          ],
        );

        expect(merged[1].label, RouteLabel.noTolls);
      },
    );

    test('tiada label tanpa tol bila laluan utama sendiri bebas tol', () {
      final merged = mergeRouteCandidates(
        standard: [
          _route(durationS: 3000, distanceM: 60000, points: direct),
          _route(durationS: 3300, distanceM: 61000, points: north),
        ],
      );

      expect(merged.map((r) => r.label), [
        RouteLabel.recommended,
        RouteLabel.alternative,
      ]);
    });

    test('laluan yang mengelak lebuh raya dilabel tanpa lebuh raya', () {
      final merged = mergeRouteCandidates(
        standard: [_route(durationS: 3000, distanceM: 60000, points: direct)],
        noHighways: [_route(durationS: 3800, distanceM: 66000, points: south)],
      );

      expect(merged.map((r) => r.label), [
        RouteLabel.recommended,
        RouteLabel.noHighways,
      ]);
    });

    test(
      'laluan yang jelas lebih pendek dilabel terpendek; beza kecil tidak',
      () {
        final shorter = mergeRouteCandidates(
          standard: [
            _route(durationS: 3000, distanceM: 60000, points: direct),
            _route(durationS: 3600, distanceM: 52000, points: north),
          ],
        );
        expect(shorter[1].label, RouteLabel.shortest);

        final barely = mergeRouteCandidates(
          standard: [
            _route(durationS: 3000, distanceM: 60000, points: direct),
            _route(durationS: 3600, distanceM: 59000, points: north),
          ],
        );
        expect(barely[1].label, RouteLabel.alternative);
      },
    );

    group('laluan utama = terbaik dan selamat, bukan sekadar terpantas', () {
      test('beza masa kecil: laluan jauh lebih mudah menjadi utama', () {
        final merged = mergeRouteCandidates(
          standard: [
            // Terpantas tetapi 30 belokan (lorong dan simpang).
            _withManeuvers(
              _route(durationS: 3000, distanceM: 60000, points: direct),
              turns: 30,
            ),
            // 3.3% lebih perlahan, 4 belokan sahaja.
            _withManeuvers(
              _route(durationS: 3100, distanceM: 61000, points: north),
              turns: 4,
            ),
          ],
        );

        expect(merged.first.durationS, 3100);
        expect(merged.first.label, RouteLabel.recommended);
        expect(merged[1].durationS, 3000);
        expect(
          merged[1].label,
          RouteLabel.fastest,
          reason: 'yang terpantas tetap ditunjuk berasingan',
        );
      });

      test(
        'lebih 5% perlahan: yang terpantas kekal utama walau banyak belok',
        () {
          final merged = mergeRouteCandidates(
            standard: [
              _withManeuvers(
                _route(durationS: 3000, distanceM: 60000, points: direct),
                turns: 30,
              ),
              _withManeuvers(
                _route(durationS: 3300, distanceM: 61000, points: north),
                turns: 2,
              ),
            ],
          );

          expect(merged.first.durationS, 3000);
          expect(merged.first.label, RouteLabel.recommended);
        },
      );

      test('pusingan-U dan jalan kecil yang perlahan dihukum', () {
        final plain = _route(durationS: 3000, distanceM: 60000, points: direct);
        final uTurns = _withManeuvers(plain, turns: 0, uTurns: 3);
        expect(routeScore(uTurns), greaterThan(routeScore(plain) + 250));

        final slow = RouteOption(
          distanceM: 60000,
          durationS: 3000,
          hasTolls: false,
          points: direct,
          maneuvers: const [
            // 2 km dalam 600 s = 3.3 m/s (jalan kecil/sesak).
            Maneuver(
              type: 8,
              streetNames: ['Lorong'],
              lengthM: 2000,
              timeS: 600,
              beginShapeIndex: 0,
            ),
          ],
        );
        expect(routeScore(slow), 3000 + 600 * 0.25);
      });

      test(
        'feri dan jalan bersekatan masa dibuang bila ada pilihan bersih',
        () {
          final ferry = _route(
            durationS: 2800,
            distanceM: 50000,
            points: south,
          ).copyWith();
          final merged = mergeRouteCandidates(
            standard: [
              RouteOption(
                distanceM: 50000,
                durationS: 2800,
                hasTolls: false,
                points: south,
                hasFerry: true,
              ),
              _route(durationS: 3000, distanceM: 60000, points: direct),
            ],
          );
          expect(ferry.hasFerry, isFalse);
          expect(merged, hasLength(1));
          expect(merged.single.hasFerry, isFalse);

          // Satu-satunya pilihan: dikekalkan.
          final only = mergeRouteCandidates(
            standard: [
              RouteOption(
                distanceM: 50000,
                durationS: 2800,
                hasTolls: false,
                points: south,
                hasFerry: true,
              ),
            ],
          );
          expect(only.single.hasFerry, isTrue);
        },
      );

      test('label paling mudah untuk belokan jauh lebih sedikit', () {
        final merged = mergeRouteCandidates(
          standard: [
            _withManeuvers(
              _route(durationS: 3000, distanceM: 60000, points: direct),
              turns: 20,
            ),
            _withManeuvers(
              _route(durationS: 3500, distanceM: 62000, points: north),
              turns: 5,
            ),
          ],
        );
        expect(merged[1].label, RouteLabel.simplest);
      });
    });

    test('disusun: utama dahulu, selebihnya mengikut masa', () {
      final merged = mergeRouteCandidates(
        standard: [
          _route(durationS: 3000, distanceM: 60000, points: direct),
          _route(durationS: 3800, distanceM: 70000, points: south),
        ],
        noHighways: [_route(durationS: 3500, distanceM: 66000, points: north)],
      );

      expect(merged.map((r) => r.durationS), [3000, 3500, 3800]);
      expect(merged.first.label, RouteLabel.recommended);
    });

    group('had lencongan', () {
      test('lebih 1.4x atau lebih 15 minit dibuang', () {
        final merged = mergeRouteCandidates(
          standard: [_route(durationS: 1800, distanceM: 30000, points: direct)],
          noTolls: [_route(durationS: 7200, distanceM: 90000, points: north)],
        );
        expect(merged, hasLength(1));
      });

      test('perjalanan panjang: had +15 min (bukan 1.4x)', () {
        final merged = mergeRouteCandidates(
          standard: [
            _route(durationS: 10800, distanceM: 300000, points: direct),
            _route(durationS: 11500, distanceM: 310000, points: north),
            _route(durationS: 12000, distanceM: 320000, points: south),
          ],
        );
        expect(merged.map((r) => r.durationS), [10800, 11500]);
      });

      test('perjalanan sangat pendek mempunyai lantai +3 min', () {
        final merged = mergeRouteCandidates(
          standard: [
            _route(durationS: 120, distanceM: 1500, points: direct),
            _route(durationS: 290, distanceM: 1900, points: north),
          ],
        );
        expect(merged, hasLength(2));
      });
    });

    test('sehingga 10 pilihan; berlebihan dipotong', () {
      final routes = [
        for (var i = 0; i < 14; i++)
          _route(
            durationS: 3000 + i * 20,
            distanceM: 60000 + i * 100,
            points: _path(klcc, klia, bulge: (i - 7) * 0.02 + 0.005),
          ),
      ];
      final merged = mergeRouteCandidates(standard: routes);

      expect(merged, hasLength(10));
      expect(merged.first.label, RouteLabel.recommended);
    });

    test('memo tidak mengubah hasil', () {
      final standard = [
        _route(durationS: 3000, distanceM: 60000, points: direct),
        _route(durationS: 3100, distanceM: 61000, points: north),
        _route(durationS: 3120, distanceM: 61500, points: north),
      ];
      final memo = SameRouteMemo();
      final a = mergeRouteCandidates(standard: standard, memo: memo);
      final b = mergeRouteCandidates(standard: standard, memo: memo);
      expect(a.map((r) => r.durationS), b.map((r) => r.durationS));
      expect(a, hasLength(2), reason: 'dua laluan utara ialah pendua');
    });

    test('tiada calon memulangkan senarai kosong', () {
      expect(mergeRouteCandidates(standard: const []), isEmpty);
    });
  });

  group('skor dan kiraan', () {
    test('turnCountOf mengira belokan sahaja (bukan pusingan-U/teruskan)', () {
      final r = _withManeuvers(
        _route(durationS: 100, distanceM: 1000, points: direct),
        turns: 3,
        uTurns: 2,
      );
      expect(turnCountOf(r), 3);
      expect(uTurnCountOf(r), 2);
    });
  });

  group('planCandidateRequests', () {
    RouteOption mainRoute({int distanceM = 60000, bool tolls = true}) => _route(
      durationS: 3000,
      distanceM: distanceM,
      points: direct,
      hasTolls: tolls,
    );
    const base = RouteQuery(origin: klcc, destination: klia);

    test(
      'perjalanan panjang berbayar tol: tanpa tol, elak lebuh raya, terpendek, lencongan',
      () {
        final requests = planCandidateRequests(base, [mainRoute()]);

        expect(requests.map((r) => r.origin).take(3), [
          RouteCandidateOrigin.noTolls,
          RouteCandidateOrigin.noHighways,
          RouteCandidateOrigin.shortest,
        ]);
        expect(
          requests,
          hasLength(8),
          reason: 'dihadkan 8 permintaan tambahan',
        );
        expect(requests.every((r) => r.query.alternates == 0), isTrue);

        final detours = requests
            .where((r) => r.origin == RouteCandidateOrigin.detour)
            .toList();
        expect(detours, hasLength(5));
        // Bulatan di tengah dahulu; jejari 2% jarak (1200 m), tidak menelan asal/destinasi.
        final first = detours.first.query.exclusions.single;
        expect(first.radiusM, 1200);
        expect(distanceMeters(first.center, klcc), greaterThan(1600));
        expect(distanceMeters(first.center, klia), greaterThan(1600));
        expect(
          distanceMeters(
            first.center,
            GeoPoint((klcc.lat + klia.lat) / 2, (klcc.lng + klia.lng) / 2),
          ),
          lessThan(2000),
        );
      },
    );

    test('bebas tol: tiada permintaan tanpa tol', () {
      final requests = planCandidateRequests(base, [mainRoute(tolls: false)]);
      expect(
        requests.where((r) => r.origin == RouteCandidateOrigin.noTolls),
        isEmpty,
      );
    });

    test(
      'perjalanan pendek: tiada lencongan; sangat pendek: tiada langsung',
      () {
        final medium = planCandidateRequests(base, [
          mainRoute(distanceM: 6000, tolls: false),
        ]);
        expect(
          medium.where((r) => r.origin == RouteCandidateOrigin.noHighways),
          hasLength(1),
        );
        expect(
          medium.where((r) => r.origin == RouteCandidateOrigin.detour).length,
          lessThanOrEqualTo(3),
        );

        expect(
          planCandidateRequests(base, [
            mainRoute(distanceM: 2000, tolls: false),
          ]),
          isEmpty,
        );
      },
    );

    test('jejari bulatan dihadkan 250-1400 m', () {
      final huge = planCandidateRequests(base, [
        mainRoute(distanceM: 400000, tolls: false),
      ]);
      for (final r in huge.where(
        (r) => r.origin == RouteCandidateOrigin.detour,
      )) {
        expect(r.query.exclusions.single.radiusM, 1400);
      }
    });

    test('maxExtra dihormati; tiada laluan asas = tiada permintaan', () {
      expect(
        planCandidateRequests(base, [mainRoute()], maxExtra: 2),
        hasLength(2),
      );
      expect(planCandidateRequests(base, const []), isEmpty);
    });
  });

  group('geometri laluan', () {
    test('isSameRoute: sama bila bertindih, berbeza bila jauh', () {
      final a = _route(durationS: 1, distanceM: 1, points: direct);
      expect(
        isSameRoute(a, _route(durationS: 2, distanceM: 1, points: direct)),
        isTrue,
      );
      expect(
        isSameRoute(a, _route(durationS: 2, distanceM: 1, points: north)),
        isFalse,
      );
    });

    test('nearestRouteIndex memilih laluan terdekat dalam toleransi', () {
      final tapOnNorth = north[north.length ~/ 2];

      expect(
        nearestRouteIndex([direct, north], tapOnNorth, toleranceM: 100),
        1,
      );
      expect(
        nearestRouteIndex(
          [direct, north],
          const GeoPoint(5, 100),
          toleranceM: 100,
        ),
        isNull,
      );
    });
  });

  group('RouteOption.via', () {
    test('jalan dengan jarak terkumpul terpanjang', () {
      const m = [
        Maneuver(
          type: 1,
          streetNames: ['Jalan Ampang'],
          lengthM: 900,
          timeS: 60,
          beginShapeIndex: 0,
        ),
        Maneuver(
          type: 8,
          streetNames: ['Lebuhraya KLIA', 'E6'],
          lengthM: 40000,
          timeS: 1800,
          beginShapeIndex: 5,
        ),
        Maneuver(
          type: 8,
          streetNames: [],
          lengthM: 90000,
          timeS: 10,
          beginShapeIndex: 9,
        ),
      ];
      const option = RouteOption(
        distanceM: 1,
        durationS: 1,
        hasTolls: false,
        points: [],
        maneuvers: m,
      );

      expect(option.via, 'Lebuhraya KLIA');
      expect(sampleOption().via, isNull);
    });
  });

  group('RouteQuery', () {
    test(
      'rerouteFrom mengekalkan kenderaan, pilihan elak dan destinasi; satu laluan sahaja',
      () {
        const query = RouteQuery(
          origin: klcc,
          destination: klia,
          vehicle: RouteVehicle.motorcycle,
          avoidTolls: true,
          avoidHighways: true,
          destinationLabel: 'KLIA',
        );

        final next = query.rerouteFrom(batuCaves, headingDegrees: 45);

        expect(next.origin, batuCaves);
        expect(next.headingDegrees, 45);
        expect(next.destination, klia);
        expect(next.vehicle, RouteVehicle.motorcycle);
        expect(next.avoidTolls, isTrue);
        expect(next.avoidHighways, isTrue);
        expect(next.destinationLabel, 'KLIA');
        expect(next.alternates, 0);
      },
    );
  });
}
