import 'dart:async';
import 'dart:convert';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/road_quality_service.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/road_quality.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/route_scoring.dart';
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

/// Penilai kualiti jalan palsu: penalti ditentukan oleh bulge laluan (titik tengah).
class _FakeQuality implements RoadQualityService {
  _FakeQuality(this.penaltyFor_);
  final double? Function(RouteOption) penaltyFor_;
  int calls = 0;

  @override
  Future<double?> penaltyFor(RouteOption route) async {
    calls++;
    return penaltyFor_(route);
  }
}

void main() {
  group('roadPenaltyFromClasses', () {
    test('jalan utama sahaja = 0; kampung memberi penalti; dihadkan 0.6', () {
      expect(
        roadPenaltyFromClasses({
          'motorway': 1000,
          'primary': 4000,
          'ramp': 200,
        }),
        0,
      );
      expect(roadPenaltyFromClasses(const {}), 0);
      final mixed = roadPenaltyFromClasses({
        'primary': 6000,
        'tertiary': 3000,
        'residential': 1000,
      });
      // 0.3*0.30 + 0.1*0.50 = 0.14
      expect(mixed, closeTo(0.14, 1e-9));
      expect(roadPenaltyFromClasses({'service_other': 1000}), 0.6);
      // Kelas tidak dikenali tidak dinilai.
      expect(roadPenaltyFromClasses({'primary': 1000, 'aneh': 1000}), 0);
    });
  });

  group('parseRoadClassMeters (respons sebenar bentuk trace_attributes)', () {
    test(
      'mengumpul jarak mengikut kelas; susur dikira utama; baris rosak dilangkau',
      () {
        final body = jsonEncode({
          'edges': [
            {'road_class': 'primary', 'use': 'road', 'length': 2.0},
            {'road_class': 'primary', 'use': 'road', 'length': 1.0},
            {'road_class': 'tertiary', 'use': 'road', 'length': 0.5},
            {'road_class': 'tertiary', 'use': 'ramp', 'length': 0.25},
            {'road_class': 'residential', 'length': 'x'},
            'bukan peta',
          ],
        });
        final out = parseRoadClassMeters(body);
        expect(out['primary'], 3000);
        expect(out['tertiary'], 500);
        expect(out['ramp'], 250);
        expect(out.containsKey('residential'), isFalse);
        expect(parseRoadClassMeters('{"x":1}'), isEmpty);
        expect(parseRoadClassMeters(null), isEmpty);
      },
    );

    test('permintaan hanya meminta kelas, kegunaan dan panjang', () {
      final req = buildRoadClassRequest(
        RouteOption(
          distanceM: 1000,
          durationS: 100,
          hasTolls: false,
          points: _path(0),
        ),
        RouteVehicle.car,
      );
      final attrs = ((req['filters']! as Map)['attributes'] as List)
          .cast<String>();
      expect(
        attrs,
        containsAll(['edge.road_class', 'edge.use', 'edge.length']),
      );
      expect(req['shape_match'], 'map_snap');
      expect(req['encoded_polyline'], isA<String>());
    });
  });

  group('routeScore', () {
    test('penalti kualiti jalan menaikkan skor mengikut masa laluan', () {
      final a = sampleOption(
        durationS: 1000,
        distanceM: 10000,
        points: _path(0),
      );
      final b = a.withRoadPenalty(0.2);
      expect(routeScore(b) - routeScore(a), closeTo(200, 1e-9));
      // Tidak mengubah masa atau jarak yang dipaparkan.
      expect(b.durationS, a.durationS);
      expect(b.distanceM, a.distanceM);
      expect(b.roadPenalty, 0.2);
    });
  });

  group('MultiRoutePlanner dengan kualiti jalan', () {
    // Laluan A: sedikit lebih laju tetapi banyak jalan kampung. Laluan B: 4% lebih lambat, jalan utama.
    RouteOption a() =>
        sampleOption(durationS: 1500, distanceM: 24000, points: _path(0));
    RouteOption b() =>
        sampleOption(durationS: 1560, distanceM: 26000, points: _path(0.07));

    FakeRoutePlanner source() => FakeRoutePlanner((q) async {
      if (q.alternates == 0) return const [];
      return [a(), b()];
    });

    test(
      'laluan Disyorkan ialah jalan utama walaupun beberapa saat lebih lambat',
      () async {
        final quality = _FakeQuality((r) => r.durationS == 1500 ? 0.25 : 0.0);
        final src = source();
        final planner = MultiRoutePlanner(
          primary: src,
          forSource: (_) => src,
          stagger: Duration.zero,
          retryDelay: Duration.zero,
          quality: quality,
        );
        final options = await planner.plan(
          const RouteQuery(origin: klcc, destination: klia),
        );
        final recommended = options.firstWhere(
          (o) => o.label == RouteLabel.recommended,
        );
        expect(recommended.durationS, 1560, reason: 'jalan utama dipilih');
        expect(recommended.roadPenalty, 0.0);
        expect(quality.calls, greaterThan(0));
      },
    );

    test(
      'tanpa penilai: laluan terpantas kekal Disyorkan (tingkah laku asal)',
      () async {
        final src = source();
        final planner = MultiRoutePlanner(
          primary: src,
          forSource: (_) => src,
          stagger: Duration.zero,
          retryDelay: Duration.zero,
        );
        final options = await planner.plan(
          const RouteQuery(origin: klcc, destination: klia),
        );
        expect(
          options
              .firstWhere((o) => o.label == RouteLabel.recommended)
              .durationS,
          1500,
        );
      },
    );

    test(
      'penilai gagal (null atau lontaran): senarai tidak terjejas',
      () async {
        for (final failing in <double? Function(RouteOption)>[
          (_) => null,
          (_) => throw StateError('rangkaian'),
        ]) {
          final src = source();
          final planner = MultiRoutePlanner(
            primary: src,
            forSource: (_) => src,
            stagger: Duration.zero,
            retryDelay: Duration.zero,
            quality: _FakeQuality(failing),
          );
          final options = await planner.plan(
            const RouteQuery(origin: klcc, destination: klia),
          );
          expect(options, isNotEmpty);
          expect(
            options
                .firstWhere((o) => o.label == RouteLabel.recommended)
                .durationS,
            1500,
          );
        }
      },
    );

    test(
      'hanya laluan yang bersaing dinilai dan bilangan permintaan dihadkan',
      () async {
        final slow = sampleOption(
          durationS: 3000,
          distanceM: 30000,
          points: _path(0.1),
        );
        final src = FakeRoutePlanner(
          (q) async => q.alternates == 0 ? const [] : [a(), b(), slow],
        );
        final quality = _FakeQuality((_) => 0.0);
        final planner = MultiRoutePlanner(
          primary: src,
          forSource: (_) => src,
          stagger: Duration.zero,
          retryDelay: Duration.zero,
          quality: quality,
        );
        await planner.plan(const RouteQuery(origin: klcc, destination: klia));
        // 3000 s > 1500 x 1.15: tidak dinilai; dan tidak pernah melebihi bajet.
        expect(
          quality.calls,
          lessThanOrEqualTo(MultiRoutePlanner.maxQualityChecks),
        );
        expect(quality.calls, 2);
      },
    );

    test('permintaan segera (re-route) tidak menilai kualiti jalan', () async {
      final src = source();
      final quality = _FakeQuality((_) => 0.3);
      final planner = MultiRoutePlanner(
        primary: src,
        forSource: (_) => src,
        stagger: Duration.zero,
        retryDelay: Duration.zero,
        quality: quality,
      );
      await planner.plan(
        const RouteQuery(origin: klcc, destination: klia, urgent: true),
      );
      expect(quality.calls, 0);
    });
  });

  test('unawaited import digunakan', () => unawaited(Future<void>.value()));
}
