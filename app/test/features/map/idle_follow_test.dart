import 'dart:async';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/idle_follow.dart';
import 'package:fgmap/features/map/presentation/user_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<UserLocation> stream;
  late int listens;
  late int cancels;
  late List<UserLocation> received;
  late IdleFollow follow;

  UserLocation at(double lat, {bool stale = false}) => UserLocation(
    point: GeoPoint(lat, 101.7),
    accuracyM: 8,
    time: DateTime(2026, 10, 26, 10),
    stale: stale,
  );

  setUp(() {
    listens = 0;
    cancels = 0;
    received = [];
    stream = StreamController<UserLocation>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    follow = IdleFollow(updates: stream.stream, onLocation: received.add);
    addTearDown(() {
      follow.dispose();
      stream.close();
    });
  });

  test('belum engage: kamera tidak mengikut', () async {
    expect(follow.following, isFalse);
    expect(follow.active, isFalse);
    stream.add(at(3.1));
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    expect(listens, 0);
  });

  test('engage: meneruskan kedudukan ke kamera', () async {
    follow.engage();
    stream.add(at(3.1));
    await Future<void>.delayed(Duration.zero);

    expect(follow.following, isTrue);
    expect(follow.active, isTrue);
    expect(received.map((l) => l.point.lat), [3.1]);
  });

  test('release: berhenti mengikut', () async {
    follow.engage();
    follow.release();
    await Future<void>.delayed(Duration.zero);

    expect(follow.following, isFalse);
    expect(follow.active, isFalse);
    expect(cancels, 1);
    stream.add(at(3.2));
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
  });

  test('suspend: niat mengikut diingat; resume menyambung', () async {
    follow.engage();
    follow.suspend('route');
    await Future<void>.delayed(Duration.zero);
    expect(follow.following, isTrue, reason: 'pengguna masih mahu mengikut');
    expect(follow.active, isFalse);
    stream.add(at(3.1));
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);

    follow.resume('route');
    expect(follow.active, isTrue);
    stream.add(at(3.2));
    await Future<void>.delayed(Duration.zero);
    expect(received.map((l) => l.point.lat), [3.2]);
  });

  test(
    'beberapa sebab gantungan: hanya aktif semula apabila semuanya dibatalkan',
    () {
      follow.engage();
      follow.suspend('navigation');
      follow.suspend('route');

      follow.resume('navigation');
      expect(follow.active, isFalse);
      follow.resume('route');
      expect(follow.active, isTrue);
    },
  );

  test('suspend tanpa engage: resume tidak mula mengikut', () {
    follow.suspend('route');
    follow.resume('route');
    expect(follow.active, isFalse);
    expect(listens, 0);
  });

  test('release semasa digantung: resume tidak mengikut semula', () {
    follow.engage();
    follow.suspend('route');
    follow.release();
    follow.resume('route');
    expect(follow.active, isFalse);
  });

  test('engage berulang tidak menggandakan langganan', () {
    follow.engage();
    follow.engage();
    follow.engage();
    expect(listens, 1);
  });

  test(
    'kedudukan lapuk (ditinggalkan semasa latar belakang) tidak menyentak kamera',
    () async {
      follow.engage();
      stream.add(at(3.1, stale: true));
      stream.add(at(3.2));
      await Future<void>.delayed(Duration.zero);

      expect(received.map((l) => l.point.lat), [3.2]);
    },
  );

  test('dispose: melepaskan semuanya', () {
    follow.engage();
    follow.dispose();
    expect(follow.active, isFalse);
    expect(follow.following, isFalse);
  });
}
