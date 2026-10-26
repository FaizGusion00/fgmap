import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
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
}
