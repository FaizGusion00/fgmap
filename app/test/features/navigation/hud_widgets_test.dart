import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_hud.dart';
import 'package:fgmap/features/navigation/presentation/roundabout_exit_icon.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

NavManeuver m(
  int i,
  ManeuverKind k,
  double start, {
  List<String> streets = const [],
  int? roundaboutExit,
}) => NavManeuver(
  index: i,
  kind: k,
  startM: start,
  lengthM: 100,
  timeS: 10,
  streetNames: streets,
  roundaboutExit: roundaboutExit,
);

NavProgress progress({
  NavManeuver? next,
  NavManeuver? following,
  double distance = 300,
  double speed = 13.9,
  bool gpsWeak = false,
  bool signalLost = false,
  NavStatus status = NavStatus.onRoute,
}) => NavProgress(
  status: status,
  alongM: 0,
  remainingM: 5400,
  remainingS: 600,
  next: next,
  distanceToNextM: next == null ? null : distance,
  following: following,
  position: const GeoPoint(3, 101),
  bearing: 0,
  speedMps: speed,
  accuracyM: 5,
  crossTrackM: 0,
  street: 'Jalan A',
  gpsWeak: gpsWeak,
  signalLost: signalLost,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('ms'),
  }) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await pumpApp(
      tester,
      Scaffold(body: Center(child: child)),
      locale: locale,
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('ManeuverBanner', () {
    testWidgets('jarak, tindakan, jalan dan ikon', (tester) async {
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(1, ManeuverKind.right, 300, streets: ['Jalan Ampang']),
            distance: 480,
          ),
        ),
      );
      expect(find.text('480 m'), findsOneWidget);
      expect(find.text('Belok kanan'), findsOneWidget);
      expect(find.text('Jalan Ampang'), findsOneWidget);
      expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
      expect(find.text('Kemudian'), findsNothing);
    });

    testWidgets('bulatan: nombor simpang keluar ditunjuk besar', (tester) async {
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(
              1,
              ManeuverKind.roundabout,
              200,
              roundaboutExit: 3,
            ),
            distance: 120,
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      // Gelang + nombor dilukis sendiri; tiada lagi glif Material yang berpintal.
      expect(find.byType(RoundaboutExitIcon), findsOneWidget);
      expect(find.byIcon(Icons.roundabout_right_rounded), findsNothing);
      // Kad: tindakan pendek sahaja (ikon sudah menyebut "bulatan").
      expect(find.text('Ambil simpang keluar ke-3'), findsOneWidget);
    });

    testWidgets('bulatan: label semantik menyebut nombor keluar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(1, ManeuverKind.roundabout, 200, roundaboutExit: 2),
            distance: 120,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Bulatan, ambil simpang keluar ke-2'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('"Bersedia" muncul dalam 150 m sahaja', (tester) async {
      final next = m(1, ManeuverKind.left, 300);
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: next, distance: 260)),
      );
      expect(find.byKey(const ValueKey('nav-get-ready')), findsNothing);
      await pump(
        tester,
        ManeuverBanner(progress: progress(next: next, distance: 120)),
      );
      expect(find.text('Bersedia'), findsOneWidget);
    });

    testWidgets('lalu lintas kiri: pusingan U ke kanan, susur lurus = lurus', (
      tester,
    ) async {
      expect(maneuverIcon(ManeuverKind.uTurn), Icons.u_turn_right_rounded);
      expect(maneuverIcon(ManeuverKind.rampStraight), Icons.straight_rounded);
    });

    testWidgets('"Kemudian" bulatan juga guna gelang + nombor', (tester) async {
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(1, ManeuverKind.left, 300),
            following: m(2, ManeuverKind.roundabout, 500, roundaboutExit: 1),
          ),
        ),
      );
      expect(find.text('Kemudian'), findsOneWidget);
      expect(find.byType(RoundaboutExitIcon), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
      '"Kemudian" hanya jika manuver berikutnya dalam 800 m dan bukan ketibaan',
      (tester) async {
        final next = m(1, ManeuverKind.left, 300);
        await pump(
          tester,
          ManeuverBanner(
            progress: progress(
              next: next,
              following: m(2, ManeuverKind.right, 500),
            ),
          ),
        );
        expect(find.text('Kemudian'), findsOneWidget);

        await pump(
          tester,
          ManeuverBanner(
            progress: progress(
              next: next,
              following: m(2, ManeuverKind.right, 1300),
            ),
          ),
        );
        expect(find.text('Kemudian'), findsNothing);

        await pump(
          tester,
          ManeuverBanner(
            progress: progress(
              next: next,
              following: m(2, ManeuverKind.arrive, 500),
            ),
          ),
        );
        expect(find.text('Kemudian'), findsNothing);
      },
    );

    testWidgets('jarak mengikut kedudukan langsung, bukan fix GPS 1 Hz', (
      tester,
    ) async {
      final live = ValueNotifier<double?>(null);
      addTearDown(live.dispose);
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(1, ManeuverKind.right, 1000),
            distance: 480,
          ),
          liveAlongM: live,
        ),
      );
      // Tiada kedudukan langsung: guna jarak daripada kemajuan.
      expect(find.text('480 m'), findsOneWidget);

      live.value = 800; // 200 m lagi ke manuver pada 1000 m
      await tester.pump();
      expect(find.text('200 m'), findsOneWidget);

      live.value = 1020; // sudah melepasi: tidak negatif
      await tester.pump();
      expect(find.text('10 m'), findsOneWidget);
    });

    testWidgets('liveRegion hanya pada teks tindakan, bukan jarak', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(1, ManeuverKind.right, 300, streets: ['Jalan Ampang']),
            distance: 480,
          ),
        ),
      );
      SemanticsNode node(String text) => tester.getSemantics(find.text(text));
      expect(node('Belok kanan'), isSemantics(isLiveRegion: true));
      expect(node('480 m'), isNot(isSemantics(isLiveRegion: true)));
      handle.dispose();
    });

    testWidgets('English', (tester) async {
      await pump(
        tester,
        ManeuverBanner(
          progress: progress(
            next: m(1, ManeuverKind.uTurn, 300),
            distance: 1500,
          ),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Make a U-turn'), findsOneWidget);
      expect(find.text('1.5 km'), findsOneWidget);
    });

    testWidgets('setiap jenis manuver mempunyai ikon', (tester) async {
      for (final kind in ManeuverKind.values) {
        expect(maneuverIcon(kind), isA<IconData>());
      }
    });
  });

  group('NavStatusChip', () {
    testWidgets('belum ada fix: mencari GPS', (tester) async {
      await pump(
        tester,
        const NavStatusChip(state: NavigationState(phase: NavPhase.active)),
      );
      expect(find.text('Mencari isyarat GPS…'), findsOneWidget);
    });

    testWidgets('mengira semula, GPS lemah, ralat lokasi, dan tiada status', (
      tester,
    ) async {
      final p = progress(next: m(1, ManeuverKind.left, 300));
      await pump(
        tester,
        NavStatusChip(
          state: NavigationState(
            phase: NavPhase.active,
            progress: p,
            rerouting: true,
          ),
        ),
      );
      expect(find.text('Mengira semula laluan…'), findsOneWidget);

      await pump(
        tester,
        NavStatusChip(
          state: NavigationState(
            phase: NavPhase.active,
            progress: progress(gpsWeak: true),
          ),
        ),
      );
      expect(find.text('Isyarat GPS lemah'), findsOneWidget);

      // Isyarat hilang sepenuhnya (terowong): mesej berbeza, kedudukan dianggar.
      await pump(
        tester,
        NavStatusChip(
          state: NavigationState(
            phase: NavPhase.active,
            progress: progress(gpsWeak: true, signalLost: true),
          ),
        ),
      );
      expect(
        find.text('Tiada isyarat GPS. Kedudukan dianggar.'),
        findsOneWidget,
      );

      await pump(
        tester,
        NavStatusChip(
          state: NavigationState(
            phase: NavPhase.active,
            progress: p,
            locationError: true,
          ),
        ),
      );
      expect(find.textContaining('Lokasi tidak dapat diakses'), findsOneWidget);

      await pump(
        tester,
        NavStatusChip(
          state: NavigationState(
            phase: NavPhase.active,
            progress: progress(status: NavStatus.offRoute),
            rerouteFailure: RoutingFailureKind.network,
          ),
        ),
      );
      expect(find.text('Tiada sambungan. Mencuba semula…'), findsOneWidget);

      await pump(
        tester,
        NavStatusChip(
          state: NavigationState(phase: NavPhase.active, progress: p),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  group('SpeedBubble dan panel', () {
    testWidgets('kelajuan dalam km/j dibundar', (tester) async {
      await pump(tester, const SpeedBubble(speedMps: 27.8));
      expect(find.text('100'), findsOneWidget);
      expect(find.text('km/j'), findsOneWidget);
    });

    testWidgets(
      'panel: ETA dikira daripada masa semasa; butang tamat berfungsi',
      (tester) async {
        var ended = 0;
        await pump(
          tester,
          NavBottomPanel(
            progress: progress(next: m(1, ManeuverKind.left, 300)),
            now: DateTime(2026, 1, 1, 9, 0),
            onEnd: () => ended++,
          ),
        );
        expect(find.text('10 min'), findsOneWidget);
        expect(find.textContaining('5.4 km'), findsOneWidget);
        expect(find.textContaining('9:10'), findsOneWidget);
        await tester.tap(find.byTooltip('Tamat'));
        expect(ended, 1);
      },
    );

    testWidgets('butang sisi: butang Laporkan hanya jika dikaitkan', (
      tester,
    ) async {
      var reported = 0;
      await pump(
        tester,
        NavSideButtons(
          voiceEnabled: true,
          cameraMode: NavCameraMode.auto,
          onToggleVoice: () {},
          onCycleCamera: () {},
          onOverview: () {},
          onSettings: () {},
          onReport: () => reported++,
        ),
      );
      await tester.tap(find.byTooltip('Laporkan'));
      expect(reported, 1);

      await pump(
        tester,
        NavSideButtons(
          voiceEnabled: true,
          cameraMode: NavCameraMode.auto,
          onToggleVoice: () {},
          onCycleCamera: () {},
          onOverview: () {},
          onSettings: () {},
        ),
      );
      expect(find.byTooltip('Laporkan'), findsNothing);
    });

    testWidgets('butang sisi: setiap tindakan dipanggil', (tester) async {
      final calls = <String>[];
      await pump(
        tester,
        NavSideButtons(
          voiceEnabled: false,
          cameraMode: NavCameraMode.flat,
          onToggleVoice: () => calls.add('voice'),
          onCycleCamera: () => calls.add('camera'),
          onOverview: () => calls.add('overview'),
          onSettings: () => calls.add('settings'),
        ),
      );
      expect(find.byTooltip('Hidupkan suara'), findsOneWidget);
      expect(find.byTooltip('Kamera 2D'), findsOneWidget);
      for (final t in [
        'Hidupkan suara',
        'Kamera 2D',
        'Lihat keseluruhan laluan',
        'Tetapan navigasi',
      ]) {
        await tester.tap(find.byTooltip(t));
      }
      expect(calls, ['voice', 'camera', 'overview', 'settings']);
    });

    testWidgets('NavStartBar: Mula dan Simulasi', (tester) async {
      var started = 0;
      var simulated = 0;
      await pump(
        tester,
        NavStartBar(onStart: () => started++, onSimulate: () => simulated++),
      );
      await tester.tap(find.text('Mula'));
      await tester.tap(find.text('Simulasi'));
      expect([started, simulated], [1, 1]);
    });

    testWidgets('ArrivalCard: Selesai', (tester) async {
      var done = 0;
      await pump(tester, ArrivalCard(onDone: () => done++));
      expect(find.text('Anda telah sampai'), findsOneWidget);
      await tester.tap(find.text('Selesai'));
      expect(done, 1);
    });
  });
}
