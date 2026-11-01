import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/navigation/domain/car_session.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/lane_plan.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart'
    show Lane;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pose = CameraPose(
    center: GeoPoint(3.1, 101.7),
    zoom: 17,
    tilt: 56,
    bearing: 90,
  );
  const route = [GeoPoint(3.1, 101.7), GeoPoint(3.2, 101.8)];

  test('browse tiada laluan', () {
    final snap = mapCarSession(navigating: false, cruising: false);
    expect(snap.mode, CarDriveMode.browse);
    expect(snap.route, isEmpty);
    expect(snap.hasRoute, isFalse);
    expect(snap.toMap()['route'], isEmpty);
    expect(snap.toMap()['maneuver'], isNull);
  });

  test('browse menghantar AQI; tiada isyarat pemanduan', () {
    final snap = mapCarSession(
      navigating: false,
      cruising: false,
      airAqi: 'AQI 42 · Baik',
      cameraAlert: 'should-ignore',
      alongCue: 'should-ignore',
    );
    expect(snap.mode, CarDriveMode.browse);
    expect(snap.airAqi, 'AQI 42 · Baik');
    expect(snap.cameraAlert, isNull);
    expect(snap.alongCue, isNull);
    expect(snap.driveAlert, isNull);
    expect(snap.toMap()['airAqi'], 'AQI 42 · Baik');
  });

  test('cruise ada pose dan kelajuan, tiada laluan', () {
    final snap = mapCarSession(
      navigating: false,
      cruising: true,
      pose: pose,
      speedMps: 12,
      limitKmh: 80,
      overspeed: false,
      navigationRoute: route,
    );
    expect(snap.mode, CarDriveMode.cruise);
    expect(snap.route, isEmpty);
    expect(snap.pose!.bearing, 90);
    expect(snap.pose!.tilt, inInclusiveRange(52, 60));
    expect(snap.speed.kmh, 43);
    expect(snap.speed.showLimit, isTrue);
    final map = snap.toMap();
    expect(map['route'], isEmpty);
    expect(map['speedKmh'], 43);
    expect(map['limitKmh'], 80);
    expect(map['maneuver'], isNull);
  });

  test('navigasi ada laluan dan manuver; cruise mati', () {
    final snap = mapCarSession(
      navigating: true,
      cruising: true,
      pose: pose,
      speedMps: 10,
      navigationRoute: route,
      routeVersion: 3,
      maneuver: 'Belok kanan',
      maneuverKind: 'roundabout',
      roundaboutExit: 2,
      distanceToManeuverM: 120,
      remainingM: 4000,
      remainingS: 300,
    );
    expect(snap.mode, CarDriveMode.navigating);
    // Jenis manuver dan nombor keluar dihantar supaya hos kereta boleh melukis ikon piawai.
    expect(snap.toMap()['maneuverKind'], 'roundabout');
    expect(snap.toMap()['roundaboutExit'], 2);
    expect(snap.route, route);
    expect(snap.maneuver, 'Belok kanan');
    expect(snap.hasRoute, isTrue);
    final map = snap.toMap();
    expect(map['mode'], 'navigating');
    expect((map['route'] as List), hasLength(2));
    expect(map['maneuver'], 'Belok kanan');
  });

  test('had tidak diketahui: papan tidak dihantar', () {
    final snap = mapCarSession(
      navigating: false,
      cruising: true,
      speedMps: 8,
      limitKmh: null,
    );
    expect(snap.speed.showLimit, isFalse);
    expect(snap.toMap()['limitKmh'], isNull);
  });

  test('keutamaan isyarat: kamera menyembunyikan R&R', () {
    final withCam = mapCarSession(
      navigating: true,
      cruising: false,
      navigationRoute: route,
      cameraAlert: 'Kamera AwAS · 600 m',
      weatherAlert: 'Cuaca buruk',
      alongCue: 'R&R · 2.0 km',
    );
    expect(withCam.cameraAlert, 'Kamera AwAS · 600 m');
    expect(withCam.weatherAlert, 'Cuaca buruk');
    expect(withCam.alongCue, isNull);
    expect(withCam.driveAlert, 'Kamera AwAS · 600 m');
    expect(withCam.toMap()['driveAlert'], 'Kamera AwAS · 600 m');
    expect(withCam.toMap()['alongCue'], isNull);

    final weatherOnly = mapCarSession(
      navigating: true,
      cruising: false,
      navigationRoute: route,
      weatherAlert: 'Cuaca buruk',
      alongCue: 'R&R · 2.0 km',
    );
    expect(weatherOnly.driveAlert, 'Cuaca buruk');
    expect(weatherOnly.alongCue, 'R&R · 2.0 km');

    final alongOnly = mapCarSession(
      navigating: true,
      cruising: false,
      navigationRoute: route,
      alongCue: 'Minyak · 1.2 km',
    );
    expect(alongOnly.driveAlert, 'Minyak · 1.2 km');
  });

  test('carFormatDistance bundar meter dan km', () {
    expect(carFormatDistance(42), '40 m');
    expect(carFormatDistance(600), '600 m');
    expect(carFormatDistance(1500), '1.5 km');
    expect(carFormatDistance(12000), '12 km');
  });

  group('waktu solat di skrin kereta', () {
    test('browse dan cruise membawa waktu solat seterusnya', () {
      final browse = mapCarSession(
        navigating: false,
        cruising: false,
        prayerLine: 'Asar 16:28',
      );
      expect(browse.toMap()['prayerLine'], 'Asar 16:28');
      final cruise = mapCarSession(
        navigating: false,
        cruising: true,
        pose: pose,
        prayerLine: 'Asar 16:28',
      );
      expect(cruise.toMap()['prayerLine'], 'Asar 16:28');
    });

    test('navigasi tidak membawanya: tidak bersaing dengan manuver', () {
      final nav = mapCarSession(
        navigating: true,
        cruising: false,
        pose: pose,
        navigationRoute: route,
        prayerLine: 'Asar 16:28',
      );
      expect(nav.toMap()['prayerLine'], isNull);
    });

    test('tanpa Waktu Azan: tiada baris', () {
      final snap = mapCarSession(navigating: false, cruising: false);
      expect(snap.toMap()['prayerLine'], isNull);
    });
  });

  group('lorong di skrin kereta', () {
    final realPlan = lanePlanFor(
      const NavManeuver(
        index: 1,
        kind: ManeuverKind.right,
        startM: 0,
        lengthM: 100,
        timeS: 10,
        streetNames: [],
        lanes: [
          Lane(directions: Lane.through),
          Lane(directions: Lane.through | Lane.right, valid: Lane.right),
        ],
      ),
    );

    test(
      'data sebenar dihantar: anak panah kiri ke kanan dan lorong disyorkan',
      () {
        final lanes = carLanesFor(realPlan);
        expect(lanes, hasLength(2));
        expect(lanes[0].arrows, ['through']);
        expect(lanes[0].recommended, isFalse);
        expect(lanes[1].arrows, ['through', 'right']);
        expect(lanes[1].recommended, isTrue);
      },
    );

    test(
      'anggaran tidak pernah dihantar: UI lorong kereta tiada label anggaran',
      () {
        final estimated = lanePlanFor(
          const NavManeuver(
            index: 1,
            kind: ManeuverKind.right,
            startM: 0,
            lengthM: 100,
            timeS: 10,
            streetNames: [],
          ),
        );
        expect(estimated!.estimated, isTrue);
        expect(carLanesFor(estimated), isEmpty);
        expect(carLanesFor(null), isEmpty);
      },
    );

    test('navigasi membawa lorong dan ayat; browse/cruise tidak', () {
      final nav = mapCarSession(
        navigating: true,
        cruising: false,
        pose: pose,
        navigationRoute: route,
        lanes: carLanesFor(realPlan),
        laneHint: 'Guna lorong paling kanan',
      );
      final map = nav.toMap();
      expect(map['laneHint'], 'Guna lorong paling kanan');
      expect((map['lanes'] as List).first, {
        'arrows': ['through'],
        'recommended': false,
        'highlighted': <String>[],
      });
      for (final cruising in [false, true]) {
        final other = mapCarSession(
          navigating: false,
          cruising: cruising,
          pose: pose,
          lanes: carLanesFor(realPlan),
          laneHint: 'Guna lorong paling kanan',
        );
        expect(other.toMap()['lanes'], isEmpty);
        expect(other.toMap()['laneHint'], isNull);
      }
    });

    test('ayat sisi BM dan EN daripada InstructionText', () {
      const ms = InstructionText(VoiceLanguage.ms);
      const en = InstructionText(VoiceLanguage.en);
      NavManeuver of(ManeuverKind k, {List<Lane> lanes = const []}) =>
          NavManeuver(
            index: 1,
            kind: k,
            startM: 0,
            lengthM: 1,
            timeS: 1,
            streetNames: const [],
            lanes: lanes,
          );
      expect(ms.laneHint(of(ManeuverKind.right)), 'Guna lorong paling kanan');
      expect(en.laneHint(of(ManeuverKind.left)), 'Use the leftmost lane');
      expect(ms.laneHint(of(ManeuverKind.straight)), isNull);
      final two = of(
        ManeuverKind.right,
        lanes: const [
          Lane(directions: Lane.through),
          Lane(directions: Lane.right, valid: Lane.right, active: Lane.right),
          Lane(directions: Lane.right, valid: Lane.right),
        ],
      );
      expect(ms.laneHint(two), 'Guna 2 lorong paling kanan');
      expect(en.laneHint(two), 'Use the 2 rightmost lanes');
      final middle = of(
        ManeuverKind.slightRight,
        lanes: [
          for (var i = 0; i < 5; i++)
            Lane(directions: Lane.through, valid: i == 1 ? Lane.through : 0),
        ],
      );
      expect(ms.laneHint(middle), 'Guna lorong ke-2 dari kiri');
      expect(en.laneHint(middle), 'Use lane 2 from the left');
      // Data lorong ada tetapi tiada sorotan: tiada ayat palsu daripada sisi manuver.
      final unknown = of(
        ManeuverKind.right,
        lanes: const [
          Lane(directions: Lane.through),
          Lane(directions: Lane.right),
        ],
      );
      expect(ms.laneHint(unknown), isNull);
      // Bulatan keluar 1: tiada pelan, jatuh kepada sisi bulatan.
      expect(
        ms.laneHint(
          NavManeuver(
            index: 1,
            kind: ManeuverKind.roundabout,
            startM: 0,
            lengthM: 1,
            timeS: 1,
            streetNames: const [],
            roundaboutExit: 1,
          ),
        ),
        'Guna lorong paling kiri',
      );
    });
  });
}
