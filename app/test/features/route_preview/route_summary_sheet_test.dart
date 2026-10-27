import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/toll.dart';
import 'package:fgmap/features/route_preview/presentation/route_preview_controller.dart';
import 'package:fgmap/features/route_preview/presentation/route_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _query = RouteQuery(origin: klcc, destination: klia);

RouteOption _route(
  int n, {
  RouteLabel label = RouteLabel.alternative,
  int turns = 0,
  bool highway = false,
  bool ferry = false,
}) => RouteOption(
  distanceM: 60000 + n * 1000,
  durationS: 3000 + n * 120,
  hasTolls: n == 0,
  hasHighway: highway,
  hasFerry: ferry,
  points: [klcc, GeoPoint(3.0 + n * 0.01, 101.7), klia],
  label: n == 0 ? RouteLabel.recommended : label,
  maneuvers: [
    for (var i = 0; i < turns; i++)
      const Maneuver(
        type: 10,
        streetNames: [],
        lengthM: 1000,
        timeS: 60,
        beginShapeIndex: 0,
      ),
  ],
);

void main() {
  Future<void> pumpSheet(
    WidgetTester tester,
    RouteReady state, {
    VoidCallback? onShowMore,
    ValueChanged<int>? onSelect,
    VoidCallback? onShare,
    double? fuelCostRm,
    double textScale = 1.0,
    bool settle = true,
  }) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: RouteSummarySheet(
          state: state,
          onSelect: onSelect ?? (_) {},
          onVehicleChanged: (_) {},
          onRetry: () {},
          onClear: () {},
          onShowMore: onShowMore,
          onShare: onShare,
          fuelCostRm: fuelCostRm,
          now: DateTime(2026, 10, 26, 9),
        ),
      ),
    );
    // Penunjuk putaran tidak pernah "selesai": pam berdasarkan masa sahaja.
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    '9 pilihan: 6 kad + "Lagi 3"; ketik "Lagi" memanggil onShowMore',
    (tester) async {
      var more = 0;
      final state = RouteReady(
        query: _query,
        options: [for (var i = 0; i < 9; i++) _route(i, turns: i)],
      );
      await pumpSheet(tester, state.copyWith(), onShowMore: () => more++);
      // Hanya enam kad dipaparkan (ListView ufuk; kad ke-7 tiada).
      expect(find.byKey(const ValueKey('route-option-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-option-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('route-option-6')), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('route-more')));
      await tester.pumpAndSettle();
      expect(find.text('Lagi 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('route-more')));
      expect(more, 1);
    },
  );

  testWidgets('dikembangkan: semua 9 kad, tiada "Lagi"', (tester) async {
    final state = RouteReady(
      query: _query,
      options: [for (var i = 0; i < 9; i++) _route(i)],
      expanded: true,
    );
    await pumpSheet(tester, state);
    expect(find.byKey(const ValueKey('route-more')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('route-option-8')));
    expect(find.byKey(const ValueKey('route-option-8')), findsOneWidget);
  });

  testWidgets('kad menunjukkan label Disyorkan, belokan, lebuh raya dan feri', (
    tester,
  ) async {
    final state = RouteReady(
      query: _query,
      options: [
        _route(0, turns: 12, highway: true),
        _route(1, turns: 1, ferry: true),
      ],
    );
    await pumpSheet(tester, state);
    expect(find.text('Disyorkan'), findsOneWidget);
    expect(find.textContaining('12 belokan'), findsOneWidget);
    expect(find.textContaining('1 belokan'), findsOneWidget);
    expect(find.byIcon(Icons.add_road_rounded), findsOneWidget);
    expect(find.byIcon(Icons.directions_boat_rounded), findsOneWidget);
    // Semantik lengkap untuk pembaca skrin.
    expect(
      find.bySemanticsLabel(RegExp('Disyorkan.*12 belokan.*Lebuh raya')),
      findsOneWidget,
    );
  });

  testWidgets(
    'semasa mencari alternatif: penunjuk dipaparkan; selepas siap hilang',
    (tester) async {
      final loading = RouteReady(
        query: _query,
        options: [_route(0), _route(1)],
        loadingMore: true,
      );
      await pumpSheet(tester, loading, settle: false);
      expect(
        find.byKey(const ValueKey('route-searching-more')),
        findsOneWidget,
      );
      expect(find.text('Mencari laluan lain…'), findsOneWidget);

      await pumpSheet(
        tester,
        loading.copyWith(loadingMore: false),
        settle: false,
      );
      expect(find.byKey(const ValueKey('route-searching-more')), findsNothing);
    },
  );

  testWidgets('teks sistem 2x: enam kad tidak melimpah', (tester) async {
    final state = RouteReady(
      query: _query,
      options: [
        for (var i = 0; i < 8; i++) _route(i, turns: 20, highway: true),
      ],
    );
    await pumpSheet(tester, state, textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mengetuk kad memilihnya', (tester) async {
    int? picked;
    final state = RouteReady(
      query: _query,
      options: [_route(0), _route(1), _route(2)],
    );
    await pumpSheet(tester, state, onSelect: (i) => picked = i);
    await tester.tap(find.byKey(const ValueKey('route-option-1')));
    expect(picked, 1);
  });

  group('tol', () {
    RouteOption tolled() => const RouteOption(
      distanceM: 60000,
      durationS: 3000,
      hasTolls: true,
      points: [klcc, GeoPoint(3.0, 101.7), klia],
      maneuvers: [
        Maneuver(
          type: 8,
          streetNames: ['E20', 'Lebuhraya Maju'],
          lengthM: 20000,
          timeS: 700,
          beginShapeIndex: 0,
          toll: true,
        ),
        Maneuver(
          type: 8,
          streetNames: ['E6'],
          lengthM: 9000,
          timeS: 300,
          beginShapeIndex: 1,
          toll: true,
        ),
      ],
    );

    RouteReady ready(Map<String, TollEstimate> tolls) {
      final route = tolled();
      return RouteReady(
        query: _query,
        options: [route, _route(1)],
        tolls: {for (final e in tolls.entries) routeKey(route): e.value},
      );
    }

    testWidgets(
      'tanpa anggaran: jalan bertol sebenar dipaparkan, tiada harga direka',
      (tester) async {
        await pumpSheet(tester, ready(const {}));
        expect(find.text('Tol: Lebuhraya Maju (E20), E6'), findsOneWidget);
        expect(find.textContaining('RM'), findsNothing);
      },
    );

    testWidgets('anggaran tepat: harga dan penafian kelas', (tester) async {
      await pumpSheet(
        tester,
        ready({
          'x': const TollEstimate(plazaCount: 2, unknownCount: 0, knownRm: 5.5),
        }),
      );
      expect(find.textContaining('Tol RM 5.50'), findsWidgets);
      expect(
        find.text('Anggaran sahaja (kelas 1); semak harga di plaza.'),
        findsOneWidget,
      );
    });

    testWidgets('sebahagian: RM x+ dengan penanda sebahagian', (tester) async {
      await pumpSheet(
        tester,
        ready({
          'x': const TollEstimate(plazaCount: 3, unknownCount: 1, knownRm: 4),
        }),
      );
      expect(find.textContaining('Tol RM 4.00+ (sebahagian)'), findsOneWidget);
      expect(find.text('RM 4.00+'), findsOneWidget, reason: 'ringkas pada kad');
    });

    testWidgets(
      'harga tidak diketahui: bilangan plaza sahaja, tiada RM dan tiada penafian',
      (tester) async {
        await pumpSheet(
          tester,
          ready({
            'x': const TollEstimate(plazaCount: 2, unknownCount: 2, knownRm: 0),
          }),
        );
        expect(
          find.textContaining('2 plaza tol, harga tidak diketahui'),
          findsOneWidget,
        );
        expect(find.text('2 plaza'), findsOneWidget);
        expect(find.textContaining('Anggaran sahaja'), findsNothing);
        expect(find.text('RM 0.00'), findsNothing);
      },
    );

    testWidgets('laluan bebas tol: "Tiada tol"', (tester) async {
      await pumpSheet(
        tester,
        const RouteReady(
          query: _query,
          options: [
            RouteOption(
              distanceM: 1000,
              durationS: 60,
              hasTolls: false,
              points: [klcc, klia],
            ),
          ],
        ),
      );
      expect(find.text('Tiada tol'), findsOneWidget);
    });
  });

  group('kongsi dan minyak', () {
    testWidgets('butang kongsi dipaparkan hanya jika ada panggilan balik', (
      tester,
    ) async {
      var shared = 0;
      final state = RouteReady(query: _query, options: [_route(0)]);
      await pumpSheet(tester, state, onShare: () => shared++);
      await tester.tap(find.byKey(const ValueKey('share-destination')));
      expect(shared, 1);

      await pumpSheet(tester, state);
      expect(find.byKey(const ValueKey('share-destination')), findsNothing);
    });

    testWidgets('kos minyak dipaparkan bila diketahui; tiada bila null', (
      tester,
    ) async {
      final state = RouteReady(query: _query, options: [_route(0)]);
      await pumpSheet(tester, state, fuelCostRm: 12.345);
      expect(find.byKey(const ValueKey('fuel-cost')), findsOneWidget);
      expect(find.text('≈ RM 12.35 minyak'), findsOneWidget);

      await pumpSheet(tester, state);
      expect(find.byKey(const ValueKey('fuel-cost')), findsNothing);
    });

    testWidgets('teks 2x dengan tol, minyak dan kongsi: tiada limpahan', (
      tester,
    ) async {
      final state = RouteReady(query: _query, options: [_route(0), _route(1)]);
      await pumpSheet(
        tester,
        state,
        fuelCostRm: 123.45,
        onShare: () {},
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
