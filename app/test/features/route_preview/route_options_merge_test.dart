import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/route_options_merge.dart';
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
        expect(merged.single.label, RouteLabel.fastest);
      },
    );

    test('laluan tanpa tol muncul serta-merta bila yang terpantas ada tol', () {
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
        RouteLabel.fastest,
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

    test('tiada label tanpa tol bila yang terpantas sendiri bebas tol', () {
      final merged = mergeRouteCandidates(
        standard: [
          _route(durationS: 3000, distanceM: 60000, points: direct),
          _route(durationS: 3300, distanceM: 61000, points: north),
        ],
      );

      expect(merged.map((r) => r.label), [
        RouteLabel.fastest,
        RouteLabel.alternative,
      ]);
    });

    test('laluan yang mengelak lebuh raya dilabel tanpa lebuh raya', () {
      final merged = mergeRouteCandidates(
        standard: [_route(durationS: 3000, distanceM: 60000, points: direct)],
        noHighways: [_route(durationS: 4200, distanceM: 66000, points: south)],
      );

      expect(merged.map((r) => r.label), [
        RouteLabel.fastest,
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

    test('disusun mengikut masa dengan yang terpantas dahulu', () {
      final merged = mergeRouteCandidates(
        standard: [
          _route(durationS: 3000, distanceM: 60000, points: direct),
          _route(durationS: 4000, distanceM: 70000, points: south),
        ],
        noHighways: [_route(durationS: 3500, distanceM: 66000, points: north)],
      );

      expect(merged.map((r) => r.durationS), [3000, 3500, 4000]);
      expect(merged.first.label, RouteLabel.fastest);
    });

    test('lencongan melampau dibuang', () {
      final merged = mergeRouteCandidates(
        standard: [_route(durationS: 1800, distanceM: 30000, points: direct)],
        noTolls: [_route(durationS: 7200, distanceM: 90000, points: north)],
      );

      expect(merged, hasLength(1));
    });

    test('dihadkan kepada maxOptions', () {
      final merged = mergeRouteCandidates(
        standard: [
          _route(durationS: 3000, distanceM: 60000, points: direct),
          _route(durationS: 3100, distanceM: 61000, points: north),
          _route(durationS: 3200, distanceM: 62000, points: south),
          _route(
            durationS: 3300,
            distanceM: 63000,
            points: _path(klcc, klia, bulge: 0.12),
          ),
          _route(
            durationS: 3400,
            distanceM: 64000,
            points: _path(klcc, klia, bulge: -0.12),
          ),
        ],
      );

      expect(merged, hasLength(4));
      expect(merged.first.durationS, 3000);
    });

    test('tiada calon memulangkan senarai kosong', () {
      expect(mergeRouteCandidates(standard: const []), isEmpty);
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
