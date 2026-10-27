import 'package:fgmap/core/platform/external_actions.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/safety/presentation/emergency_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeShareService share;
  late FakePhoneDialer dialer;
  GeoPoint? located = const GeoPoint(3.157901, 101.711602);

  setUp(() {
    share = FakeShareService();
    dialer = FakePhoneDialer();
    located = const GeoPoint(3.157901, 101.711602);
  });

  Future<void> pumpSheet(WidgetTester tester, {double textScale = 1}) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      tester,
      Scaffold(body: EmergencySheet(locate: () async => located)),
      overrides: [
        shareServiceProvider.overrideWithValue(share),
        phoneDialerProvider.overrideWithValue(dialer),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '999 dan 112: pengesahan dahulu; hanya selepas disahkan papan nombor dibuka',
    (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.byKey(const ValueKey('emergency-999')));
      await tester.pumpAndSettle();
      expect(find.text('Hubungi 999 sekarang?'), findsOneWidget);
      expect(
        dialer.dialed,
        isEmpty,
        reason: 'tiada panggilan sebelum pengesahan',
      );

      await tester.tap(find.byKey(const ValueKey('emergency-cancel')));
      await tester.pumpAndSettle();
      expect(dialer.dialed, isEmpty);

      await tester.tap(find.byKey(const ValueKey('emergency-112')));
      await tester.pumpAndSettle();
      expect(find.text('Hubungi 112 sekarang?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('emergency-confirm')));
      await tester.pumpAndSettle();
      expect(dialer.dialed, ['112']);
    },
  );

  testWidgets(
    'papan nombor gagal dibuka: mesej dengan nombor untuk didail sendiri',
    (tester) async {
      dialer.succeed = false;
      await pumpSheet(tester);
      await tester.tap(find.byKey(const ValueKey('emergency-999')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emergency-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dail 999 secara manual'), findsOneWidget);
    },
  );

  testWidgets('kongsi lokasi tepat: koordinat 5 perpuluhan dan pautan OSM', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.tap(find.byKey(const ValueKey('emergency-share')));
    await tester.pumpAndSettle();
    expect(share.shared, hasLength(1));
    final text = share.shared.single;
    expect(text, contains('Saya memerlukan bantuan'));
    expect(text, contains('3.15790, 101.71160'));
    expect(
      text,
      contains('https://www.openstreetmap.org/?mlat=3.15790&mlon=101.71160'),
    );
  });

  testWidgets('lokasi tidak diketahui: tiada perkongsian, mesej jelas', (
    tester,
  ) async {
    located = null;
    await pumpSheet(tester);
    await tester.tap(find.byKey(const ValueKey('emergency-share')));
    await tester.pumpAndSettle();
    expect(share.shared, isEmpty);
    expect(find.textContaining('Lokasi anda belum diketahui'), findsOneWidget);
  });

  testWidgets('lembaran kongsi gagal: mesej, tiada ranap', (tester) async {
    share.fail = true;
    await pumpSheet(tester);
    await tester.tap(find.byKey(const ValueKey('emergency-share')));
    await tester.pumpAndSettle();
    expect(find.textContaining('lembaran kongsi'), findsOneWidget);
  });

  testWidgets(
    'penafian: bukan perkhidmatan kecemasan; 2x teks tidak melimpah',
    (tester) async {
      await pumpSheet(tester, textScale: 2);
      expect(find.textContaining('tidak menjamin panggilan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('SystemPhoneDialer menapis nombor', () {
    // Pembersihan sahaja diuji (tanpa melancarkan URL sebenar): nombor kosong ditolak.
    expect(const SystemPhoneDialer().dial('abc'), completion(isFalse));
  });
}
