import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/route_preference.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'package:flutter_test/flutter_test.dart';

RouteOption _opt({
  required int min,
  required int km,
  bool tolls = false,
  int turns = 0,
  double roadPenalty = 0,
  bool ferry = false,
  RouteLabel label = RouteLabel.alternative,
}) => RouteOption(
  distanceM: km * 1000,
  durationS: min * 60,
  hasTolls: tolls,
  hasFerry: ferry,
  roadPenalty: roadPenalty,
  label: label,
  points: [GeoPoint(3, 101 + km / 1000), GeoPoint(3.1, 101.1 + min / 1000)],
  maneuvers: [
    for (var i = 0; i < turns; i++)
      const Maneuver(
        type: 10,
        streetNames: [],
        lengthM: 100,
        timeS: 10,
        beginShapeIndex: 0,
      ),
    if (tolls)
      const Maneuver(
        type: 8,
        streetNames: ['E1'],
        lengthM: 50000,
        timeS: 1800,
        beginShapeIndex: 0,
        toll: true,
      ),
  ],
);

void main() {
  final fast = _opt(
    min: 100,
    km: 120,
    tolls: true,
    turns: 30,
    roadPenalty: 0.2,
  );
  final short = _opt(min: 115, km: 100, turns: 40, roadPenalty: 0.3);
  final calm = _opt(min: 110, km: 125, tolls: true, turns: 6);
  final ferry = _opt(min: 104, km: 110, ferry: true, turns: 2);
  final options = [fast, short, calm, ferry];

  test('pantas, pendek dan tanpa tol', () {
    expect(chooseRoute(options, RoutePreference.fastest).index, 0);
    expect(chooseRoute(options, RoutePreference.shortest).index, 1);
    final free = chooseRoute(options, RoutePreference.noTolls);
    expect(options[free.index].hasTolls, isFalse);
    expect(free.reason, RouteChoiceReason.tollFree);
  });

  test('tanpa tol bila semua bertol: tol paling sedikit, sebab dinyatakan', () {
    final allTolled = [fast, calm];
    final c = chooseRoute(allTolled, RoutePreference.noTolls);
    expect(c.reason, RouteChoiceReason.fewestTolls);
  });

  test(
    'selamat: jalan utama dan kurang belokan, tanpa feri, dalam had masa',
    () {
      final c = chooseRoute(options, RoutePreference.safest);
      expect(c.index, 2);
      expect(c.reason, RouteChoiceReason.safest);
    },
  );

  test('selamat tidak memilih lencongan yang jauh lebih lama', () {
    final slowButCalm = _opt(min: 200, km: 180, turns: 1);
    final c = chooseRoute([fast, slowButCalm], RoutePreference.safest);
    expect(c.index, 0);
  });

  test('murah: tol diketahui + minyak', () {
    final tolls = {
      routeKey(fast): const TollEstimate(
        plazaCount: 2,
        unknownCount: 0,
        knownRm: 30,
      ),
      routeKey(calm): const TollEstimate(
        plazaCount: 2,
        unknownCount: 0,
        knownRm: 25,
      ),
    };
    final c = chooseRoute(options, RoutePreference.cheapest, tolls: tolls);
    expect(options[c.index].hasTolls, isFalse);
  });
}
