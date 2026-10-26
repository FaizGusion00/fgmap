import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/presentation/nav_alternatives.dart';
import 'package:fgmap/features/navigation/presentation/nav_routes_sheet.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _StubNav extends NavigationController {
  _StubNav(this.initial);

  final NavigationState initial;
  final switched = <RouteOption>[];
  bool accept = true;

  @override
  NavigationState build() => initial;

  @override
  bool switchRoute(RouteOption option) {
    switched.add(option);
    return accept;
  }
}

class _StubAlternatives extends NavAlternativesController {
  _StubAlternatives(this.initial);

  final NavAlternativesState initial;
  int loads = 0;

  @override
  NavAlternativesState build() => initial;

  @override
  Future<void> load() async => loads++;
}

RouteOption _option(
  RouteLabel label,
  int durationS, {
  bool tolls = false,
  String? road,
}) => RouteOption(
  distanceM: 12300,
  durationS: durationS,
  hasTolls: tolls,
  points: const [GeoPoint(3, 101), GeoPoint(3.1, 101.1)],
  label: label,
  maneuvers: road == null
      ? const []
      : [
          Maneuver(
            type: 1,
            streetNames: [road],
            lengthM: 12300,
            timeS: durationS,
            beginShapeIndex: 0,
          ),
        ],
);

NavProgress _progress(double remainingS) => NavProgress(
  status: NavStatus.onRoute,
  alongM: 0,
  remainingM: 12000,
  remainingS: remainingS,
  next: null,
  distanceToNextM: null,
  following: null,
  street: null,
  gpsWeak: false,
  position: const GeoPoint(3, 101),
  bearing: 0,
  speedMps: 10,
  accuracyM: 5,
  crossTrackM: 0,
);

void main() {
  late _StubNav nav;
  late _StubAlternatives alt;

  Future<ValueNotifier<Object?>> open(
    WidgetTester tester,
    NavAlternativesState state, {
    Locale locale = const Locale('ms'),
  }) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    nav = _StubNav(
      NavigationState(phase: NavPhase.active, progress: _progress(1200)),
    );
    alt = _StubAlternatives(state);
    final result = ValueNotifier<Object?>('belum');
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async =>
                result.value = await showNavRoutesSheet(context),
            child: const Text('buka'),
          ),
        ),
      ),
      locale: locale,
      overrides: [
        navigationControllerProvider.overrideWith(() => nav),
        navAlternativesProvider.overrideWith(() => alt),
      ],
    );
    await tester.tap(find.text('buka'));
    // Penunjuk memuatkan beranimasi tanpa henti: pumpAndSettle tidak akan selesai.
    if (state.status == NavAlternativesStatus.loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    } else {
      await tester.pumpAndSettle();
    }
    return result;
  }

  final ready = NavAlternativesState(
    status: NavAlternativesStatus.ready,
    currentIndex: 0,
    options: [
      _option(RouteLabel.fastest, 1200, tolls: true, road: 'Jalan Tun Razak'),
      _option(RouteLabel.noTolls, 1500, road: 'Jalan Ampang'),
      _option(RouteLabel.shortest, 1000, road: 'Lebuhraya Baru'),
    ],
  );

  testWidgets('senarai: semasa ditanda, beza masa dengan baki, via dan tol', (
    tester,
  ) async {
    await open(tester, ready);
    expect(find.text('Pilih laluan dari sini'), findsOneWidget);
    expect(find.text('Laluan semasa'), findsOneWidget);
    expect(find.textContaining('melalui Jalan Ampang'), findsOneWidget);
    expect(find.text('5 min lebih lambat'), findsOneWidget);
    expect(find.text('3 min lebih cepat'), findsOneWidget);
    // Pilihan tanpa tol dilabel "Tiada tol"; yang ada tol ditanda dalam baris sub.
    expect(find.text('Tiada tol'), findsOneWidget);
    expect(find.textContaining('Ada tol'), findsOneWidget);
  });

  testWidgets('ketik laluan lain: ditukar dan lembaran ditutup dengan true', (
    tester,
  ) async {
    final result = await open(tester, ready);
    await tester.tap(find.byKey(const ValueKey('nav-route-1')));
    await tester.pumpAndSettle();
    expect(nav.switched.single.label, RouteLabel.noTolls);
    expect(result.value, isTrue);
  });

  testWidgets('ketik laluan semasa: tiada pertukaran, ditutup dengan false', (
    tester,
  ) async {
    final result = await open(tester, ready);
    await tester.tap(find.byKey(const ValueKey('nav-route-0')));
    await tester.pumpAndSettle();
    expect(nav.switched, isEmpty);
    expect(result.value, isFalse);
  });

  testWidgets('pertukaran ditolak (re-route sedang berjalan): false', (
    tester,
  ) async {
    final result = await open(tester, ready);
    nav.accept = false;
    await tester.tap(find.byKey(const ValueKey('nav-route-2')));
    await tester.pumpAndSettle();
    expect(result.value, isFalse);
  });

  testWidgets('memuatkan: penunjuk dan teks; gagal: cuba lagi memanggil load', (
    tester,
  ) async {
    await open(
      tester,
      const NavAlternativesState(status: NavAlternativesStatus.loading),
    );
    expect(find.text('Mencari laluan dari lokasi anda…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('gagal: mesej dan butang cuba lagi', (tester) async {
    await open(
      tester,
      const NavAlternativesState(status: NavAlternativesStatus.failed),
    );
    expect(
      find.text('Tidak dapat mencari laluan lain sekarang.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cuba lagi'));
    await tester.pump();
    expect(alt.loads, 1);
  });

  testWidgets('hanya laluan semasa: mesej tiada laluan lain', (tester) async {
    await open(
      tester,
      NavAlternativesState(
        status: NavAlternativesStatus.ready,
        currentIndex: 0,
        options: [_option(RouteLabel.fastest, 1200)],
      ),
    );
    expect(find.text('Tiada laluan lain dari sini.'), findsOneWidget);
  });

  testWidgets('English + teks 2x tidak melimpah', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, ready, locale: const Locale('en'));
    expect(find.text('Current route'), findsOneWidget);
    expect(find.text('5 min slower'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
