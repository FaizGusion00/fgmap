import 'dart:convert';
import 'dart:io';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/junction.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/speed_limits/data/speed_limit_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nav_test_support.dart';

/// Respons `trace_attributes` Valhalla (bentuk sama seperti yang diprob pada 2026-11-02 di Shah Alam).
void main() {
  const a = GeoPoint(3.0, 101.0);
  final node = destinationPoint(a, 0, 80);
  final shape = [a, node, destinationPoint(node, 90, 60)];

  Map<String, Object?> arm(
    num heading, {
    String use = 'road',
    String? drive = 'both',
  }) => {'begin_heading': heading, 'use': use, 'driveability': ?drive};

  String body(List<Map<String, Object?>> edges, {List<GeoPoint>? points}) =>
      jsonEncode({'shape': encodePolyline6(points ?? shape), 'edges': edges});

  test('simpang 3: belok kanan, satu jalan lain di kiri', () {
    final j = parseJunction(
      body([
        {
          'begin_shape_index': 0,
          'end_shape_index': 1,
          'begin_heading': 0,
          'end_heading': 0,
          'end_node': {
            'intersecting_edges': [
              arm(271),
              // Lintasan pejalan kaki dan lorong servis bukan "jalan" dalam gambar.
              arm(30, use: 'pedestrian_crossing', drive: null),
            ],
          },
        },
        {'begin_shape_index': 1, 'end_shape_index': 2, 'begin_heading': 90},
      ]),
      at: node,
      roundabout: false,
    )!;
    expect(j.kind, JunctionKind.tee);
    expect(j.exitDeg, closeTo(90, 0.01));
    expect(j.otherArmsDeg.single, closeTo(-89, 0.01));
  });

  test('simpang 4: kiri dan lurus juga ada jalan', () {
    final j = parseJunction(
      body([
        {
          'end_shape_index': 1,
          'begin_shape_index': 0,
          'end_heading': 0,
          'end_node': {
            'intersecting_edges': [arm(270), arm(2, drive: 'forward')],
          },
        },
        {'begin_shape_index': 1, 'end_shape_index': 2, 'begin_heading': 90},
      ]),
      at: node,
      roundabout: false,
    )!;
    expect(j.kind, JunctionKind.cross);
    expect(j.armCount, 4);
  });

  test('bulatan: jalan keluar sebenar dan jalan yang dilalui di lingkaran', () {
    final ring1 = destinationPoint(node, 300, 20);
    final ring2 = destinationPoint(ring1, 30, 20);
    final out = destinationPoint(ring2, 0, 60);
    final j = parseJunction(
      body(
        [
          {'begin_shape_index': 0, 'end_shape_index': 1, 'end_heading': 0},
          {
            'begin_shape_index': 1,
            'end_shape_index': 2,
            'roundabout': true,
            'end_node': {
              'intersecting_edges': [arm(268, drive: 'forward')],
            },
          },
          {'begin_shape_index': 2, 'end_shape_index': 3, 'roundabout': true},
          {'begin_shape_index': 3, 'end_shape_index': 4, 'begin_heading': 3},
        ],
        points: [a, node, ring1, ring2, out],
      ),
      at: node,
      roundabout: true,
      roundaboutExit: 2,
    )!;
    expect(j.kind, JunctionKind.roundabout);
    expect(j.exitDeg, closeTo(3, 0.01));
    expect(j.otherArmsDeg.single, closeTo(-92, 0.01));
    expect(j.roundaboutExit, 2);
  });

  test(
    'padanan jauh dari titik manuver atau respons rosak: null (gambar anggaran)',
    () {
      final far = destinationPoint(node, 90, 200);
      expect(
        parseJunction(
          body([
            {'begin_shape_index': 0, 'end_shape_index': 1, 'end_heading': 0},
            {'begin_shape_index': 1, 'end_shape_index': 2, 'begin_heading': 90},
          ]),
          at: far,
          roundabout: false,
        ),
        isNull,
      );
      expect(parseJunction('{}', at: node, roundabout: false), isNull);
      expect(parseJunction('not json', at: node, roundabout: false), isNull);
    },
  );

  test('bahagian laluan: sekitar manuver sahaja; hanya belokan sebenar', () {
    final route = NavRoute(lShapedRoute(legM: 1500));
    final turn = route.maneuvers.firstWhere(
      (m) => m.kind == ManeuverKind.right,
    );
    final slice = junctionSlice(route, turn);
    expect(slice.length, greaterThan(2));
    var length = 0.0;
    for (var i = 1; i < slice.length; i++) {
      length += distanceMeters(slice[i - 1], slice[i]);
    }
    expect(length, closeTo(140, 2));
    expect(wantsJunction(turn), isTrue);
    expect(wantsJunction(route.maneuvers.first), isFalse);
  });

  group('respons Valhalla sebenar (dirakam 2026-11-02, Shah Alam)', () {
    Junction? fixture(String name, {required bool roundabout}) {
      final f =
          jsonDecode(
                File('test/fixtures/junction/$name.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final at = f['at'] as Map<String, dynamic>;
      return parseJunction(
        f['response'],
        at: GeoPoint(
          (at['lat'] as num).toDouble(),
          (at['lon'] as num).toDouble(),
        ),
        roundabout: roundabout,
        roundaboutExit: f['exit'] as int?,
      );
    }

    test(
      'Bulatan Bestari, keluar ke-2: keluar pertama di kiri depan dilalui',
      () {
        final j = fixture('shah_alam_roundabout', roundabout: true)!;
        expect(j.kind, JunctionKind.roundabout);
        expect(j.roundaboutExit, 2);
        expect(j.exitDeg, closeTo(53, 3));
        // Lalu lintas kiri: lingkaran ikut jam, jadi keluar pertama (kiri depan) dilalui dahulu.
        expect(j.otherArmsDeg.single, closeTo(-37, 3));
      },
    );

    test('belok kiri ke Jalan Plumbum 7/100', () {
      final j = fixture('shah_alam_left', roundabout: false)!;
      expect(j.exitDeg, lessThan(-45));
      expect(j.kind, JunctionKind.tee);
    });
  });
}
