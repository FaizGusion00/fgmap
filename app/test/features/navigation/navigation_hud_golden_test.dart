@Tags(['golden'])
library;

import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

NavManeuver maneuver(
  int index,
  ManeuverKind kind,
  double startM, {
  List<String> streets = const [],
  int? exit,
}) => NavManeuver(
  index: index,
  kind: kind,
  startM: startM,
  lengthM: 500,
  timeS: 40,
  streetNames: streets,
  roundaboutExit: exit,
);

NavProgress progress({
  required NavManeuver next,
  NavManeuver? following,
  double distance = 450,
  double speed = 16.7,
  double remainingM = 12800,
  double remainingS = 1260,
  bool gpsWeak = false,
  NavStatus status = NavStatus.onRoute,
}) => NavProgress(
  status: status,
  alongM: 1000,
  remainingM: remainingM,
  remainingS: remainingS,
  next: next,
  distanceToNextM: distance,
  following: following,
  position: const GeoPoint(3.1, 101.6),
  bearing: 90,
  speedMps: speed,
  accuracyM: 5,
  crossTrackM: 2,
  street: 'Jalan Tun Razak',
  gpsWeak: gpsWeak,
);

/// Skrin navigasi tiruan di atas "peta" kosong, untuk memeriksa rupa HUD dalam setiap tema.
class _Frame extends StatelessWidget {
  const _Frame({required this.state, this.arrived = false});

  final NavigationState state;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    final p = state.progress!;
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B2433)
          : const Color(0xFFE8ECF2),
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!arrived) ManeuverBanner(progress: p),
                    NavStatusChip(state: state),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SpeedBubble(speedMps: p.speedMps),
                      const Spacer(),
                      NavSideButtons(
                        voiceEnabled: true,
                        cameraMode: NavCameraMode.auto,
                        onToggleVoice: () {},
                        onCycleCamera: () {},
                        onOverview: () {},
                        onSettings: () {},
                      ),
                    ],
                  ),
                ),
                arrived
                    ? ArrivalCard(onDone: () {})
                    : NavBottomPanel(
                        progress: p,
                        now: DateTime(2026, 10, 26, 14, 5),
                        simulated: state.simulated,
                        onEnd: () {},
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  final right = maneuver(
    1,
    ManeuverKind.right,
    1450,
    streets: ['Jalan Ampang'],
  );
  final left = maneuver(2, ManeuverKind.left, 1600);

  NavigationState stateFor(
    NavProgress p, {
    bool rerouting = false,
    bool sim = false,
  }) => NavigationState(
    phase: NavPhase.active,
    progress: p,
    rerouting: rerouting,
    simulated: sim,
  );

  final scenarios = <String, (NavigationState, bool)>{
    'turn_then': (
      stateFor(progress(next: right, following: left), sim: true),
      false,
    ),
    'roundabout_reroute': (
      stateFor(
        progress(
          next: maneuver(3, ManeuverKind.roundabout, 1450, exit: 2),
          distance: 120,
          speed: 8,
        ),
        rerouting: true,
      ),
      false,
    ),
    'exit_gps_weak': (
      stateFor(
        progress(
          next: maneuver(
            4,
            ManeuverKind.exitRight,
            1450,
            streets: ['Lebuhraya Kuala Lumpur–Seremban', 'E37'],
          ),
          distance: 1800,
          speed: 27.8,
          remainingM: 61000,
          remainingS: 3480,
          gpsWeak: true,
        ),
      ),
      false,
    ),
    'arrived': (
      stateFor(
        progress(
          next: maneuver(5, ManeuverKind.arrive, 1000),
          distance: 0,
          speed: 0,
          remainingM: 0,
          remainingS: 0,
          status: NavStatus.arrived,
        ),
      ),
      true,
    ),
  };

  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};
  for (final theme in themes.entries) {
    for (final scenario in scenarios.entries) {
      testWidgets('HUD navigasi ${scenario.key} (${theme.key})', (
        tester,
      ) async {
        usePhoneSurface(tester);
        reduceMotion(tester);
        await withShadows(() async {
          await pumpApp(
            tester,
            RepaintBoundary(
              key: const ValueKey('frame'),
              child: _Frame(
                state: scenario.value.$1,
                arrived: scenario.value.$2,
              ),
            ),
            theme: theme.value,
          );
          await tester.pump(const Duration(milliseconds: 600));
          await expectLater(
            find.byKey(const ValueKey('frame')),
            matchesGoldenFile('goldens/hud_${scenario.key}_${theme.key}.png'),
          );
        });
      });
    }
  }
}
