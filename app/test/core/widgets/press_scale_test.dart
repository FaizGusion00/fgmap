import 'package:fgmap/core/theme/motion.dart';
import 'package:fgmap/core/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('PressScale', () {
    Future<void> pump(WidgetTester tester, VoidCallback onTap) => pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: PressScale(
            child: ElevatedButton(onPressed: onTap, child: const Text('tekan')),
          ),
        ),
      ),
    );

    double scaleNow(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets(
      'mengecil semasa disentuh, kembali selepas dilepas; ketukan tetap berfungsi',
      (tester) async {
        var taps = 0;
        await pump(tester, () => taps++);
        expect(scaleNow(tester), 1);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('tekan')),
        );
        await tester.pump();
        expect(scaleNow(tester), 0.97);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(scaleNow(tester), 1);
        expect(taps, 1);
      },
    );

    testWidgets('dibatalkan (seret keluar): kembali ke saiz asal', (
      tester,
    ) async {
      await pump(tester, () {});
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('tekan')),
      );
      await tester.pump();
      expect(scaleNow(tester), 0.97);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(scaleNow(tester), 1);
    });

    testWidgets('Reduce Motion: tiada pengecilan', (tester) async {
      reduceMotion(tester);
      await pump(tester, () {});
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('tekan')),
      );
      await tester.pump();
      expect(scaleNow(tester), 1);
      await gesture.up();
    });
  });

  group('SpringCurve (Motion.sheet)', () {
    test('bermula 0, berakhir tepat 1', () {
      expect(Motion.sheet.transform(0), 0);
      expect(Motion.sheet.transform(1), closeTo(1, 1e-9));
    });

    test(
      'menaik tanpa lajak (lembaran tidak terangkat melepasi kedudukan akhir)',
      () {
        var prev = 0.0;
        for (var i = 1; i <= 200; i++) {
          final v = Motion.sheet.transform(i / 200);
          expect(v, greaterThanOrEqualTo(prev - 1e-12));
          expect(v, lessThanOrEqualTo(1 + 1e-9));
          prev = v;
        }
      },
    );

    test('lebih pantas pada awal daripada linear (rasa pegas)', () {
      expect(Motion.sheet.transform(0.25), greaterThan(0.25));
      expect(Motion.sheet.transform(0.5), greaterThan(0.7));
    });
  });
}
