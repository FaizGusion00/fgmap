import 'dart:async';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/idle_follow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<LocationFix> stream;
  late int listens;
  late int cancels;
  late List<LocationFix> received;
  late IdleFollow follow;

  LocationFix fix(double lat, {double? accuracy = 8}) =>
      LocationFix(point: GeoPoint(lat, 101.7), accuracyMeters: accuracy);

  setUp(() {
    listens = 0;
    cancels = 0;
    received = [];
    stream = StreamController<LocationFix>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    follow = IdleFollow(fixes: () => stream.stream, onFix: received.add);
    addTearDown(() {
      follow.dispose();
      stream.close();
    });
  });

  test('belum engage: strim tidak dilanggan (tiada GPS dipakai)', () {
    expect(follow.following, isFalse);
    expect(follow.listening, isFalse);
    expect(listens, 0);
  });

  test('engage: melanggan dan meneruskan fix', () async {
    follow.engage();
    stream.add(fix(3.1));
    await Future<void>.delayed(Duration.zero);

    expect(follow.following, isTrue);
    expect(follow.listening, isTrue);
    expect(received.map((f) => f.point.lat), [3.1]);
  });

  test('release: berhenti mengikut dan melepaskan GPS', () async {
    follow.engage();
    follow.release();
    await Future<void>.delayed(Duration.zero);

    expect(follow.following, isFalse);
    expect(follow.listening, isFalse);
    expect(cancels, 1);
    stream.add(fix(3.2));
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
  });

  test(
    'suspend: GPS dilepaskan tetapi niat mengikut diingat; resume menyambung',
    () async {
      follow.engage();
      follow.suspend('background');
      await Future<void>.delayed(Duration.zero);
      expect(follow.following, isTrue, reason: 'pengguna masih mahu mengikut');
      expect(follow.listening, isFalse);

      follow.resume('background');
      expect(follow.listening, isTrue);
      expect(listens, 2);
    },
  );

  test(
    'beberapa sebab gantungan: hanya hidup semula apabila semuanya dibatalkan',
    () {
      follow.engage();
      follow.suspend('navigation');
      follow.suspend('background');

      follow.resume('navigation');
      expect(follow.listening, isFalse);
      follow.resume('background');
      expect(follow.listening, isTrue);
    },
  );

  test(
    'suspend tanpa engage: resume tidak melanggan (pengguna tidak mahu mengikut)',
    () {
      follow.suspend('background');
      follow.resume('background');
      expect(follow.listening, isFalse);
      expect(listens, 0);
    },
  );

  test('release semasa digantung: resume tidak menghidupkan GPS semula', () {
    follow.engage();
    follow.suspend('route');
    follow.release();
    follow.resume('route');
    expect(follow.listening, isFalse);
  });

  test('engage berulang tidak menggandakan langganan', () {
    follow.engage();
    follow.engage();
    follow.engage();
    expect(listens, 1);
  });

  test(
    'fix terlalu kasar diabaikan; fix tanpa maklumat ketepatan diterima',
    () async {
      follow.engage();
      stream.add(fix(3.1, accuracy: 500));
      stream.add(fix(3.2, accuracy: null));
      stream.add(fix(3.3, accuracy: 30));
      await Future<void>.delayed(Duration.zero);

      expect(received.map((f) => f.point.lat), [3.2, 3.3]);
    },
  );

  test(
    'ralat strim (kebenaran ditarik balik): berhenti mengikut tanpa ranap',
    () async {
      follow.engage();
      stream.addError(StateError('permission revoked'));
      await Future<void>.delayed(Duration.zero);

      expect(follow.following, isFalse);
      expect(follow.listening, isFalse);
    },
  );

  test('dispose: melepaskan semuanya', () {
    follow.engage();
    follow.dispose();
    expect(follow.listening, isFalse);
    expect(follow.following, isFalse);
  });
}
