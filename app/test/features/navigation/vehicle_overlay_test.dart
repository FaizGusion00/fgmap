import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fgmap/features/navigation/presentation/car/car_renderer.dart';
import 'package:fgmap/features/navigation/presentation/car/vehicle_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  final palette = CarPalette.fromPrimary(const Color(0xFF2563EB));

  group('CarPlacement', () {
    const base = CarPlacement(yawDeg: 3, tiltDeg: 56, anchorY: 0.69);

    test('beza tidak kelihatan dianggap sama (tiada lukisan semula)', () {
      expect(
        const CarPlacement(
          yawDeg: 3.01,
          tiltDeg: 56.02,
          anchorY: 0.6901,
        ).isVisiblySameAs(base),
        isTrue,
      );
      expect(base.isVisiblySameAs(null), isFalse);
    });

    test('perubahan yang kelihatan dikesan', () {
      expect(
        const CarPlacement(
          yawDeg: 4,
          tiltDeg: 56,
          anchorY: 0.69,
        ).isVisiblySameAs(base),
        isFalse,
      );
      expect(
        const CarPlacement(
          yawDeg: 3,
          tiltDeg: 50,
          anchorY: 0.69,
        ).isVisiblySameAs(base),
        isFalse,
      );
      expect(
        const CarPlacement(
          yawDeg: 3,
          tiltDeg: 56,
          anchorY: 0.62,
        ).isVisiblySameAs(base),
        isFalse,
      );
      expect(
        const CarPlacement(
          yawDeg: 3,
          tiltDeg: 56,
          anchorY: 0.69,
          opacity: 0.5,
        ).isVisiblySameAs(base),
        isFalse,
      );
      expect(
        const CarPlacement(
          yawDeg: 3,
          tiltDeg: 56,
          anchorY: 0.69,
          brake: 1,
        ).isVisiblySameAs(base),
        isFalse,
      );
    });
  });

  test('panjang kereta mengikut tinggi paparan dan dihad', () {
    expect(VehicleOverlay.lengthFor(844), inInclusiveRange(66, 80));
    expect(VehicleOverlay.lengthFor(390), 44, reason: 'mendatar: dihad bawah');
    expect(VehicleOverlay.lengthFor(3000), 80, reason: 'tablet: dihad atas');
  });

  Widget host(ValueListenable<CarPlacement?> placement, Size size, {Key? key}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VehicleOverlay(placement: placement, palette: palette),
          ),
        ),
      ),
    );
  }

  RenderObject paintObject(WidgetTester tester) =>
      tester.renderObject(find.byKey(const ValueKey('vehicle-overlay')));

  testWidgets('tiada penempatan: tiada apa dilukis', (tester) async {
    final placement = ValueNotifier<CarPlacement?>(null);
    addTearDown(placement.dispose);
    await tester.pumpWidget(host(placement, const Size(390, 844)));

    expect(paintObject(tester), isNot(paints..path()));
  });

  testWidgets(
    'penempatan ditetapkan: kereta dilukis tanpa membina semula widget',
    (tester) async {
      final placement = ValueNotifier<CarPlacement?>(null);
      addTearDown(placement.dispose);
      await tester.pumpWidget(host(placement, const Size(390, 844)));

      placement.value = const CarPlacement(
        yawDeg: 0,
        tiltDeg: 56,
        anchorY: 0.69,
      );
      await tester.pump();
      expect(paintObject(tester), paints..path());

      placement.value = null;
      await tester.pump();
      expect(paintObject(tester), isNot(paints..path()));
    },
  );

  testWidgets('lutsinar sebahagian masih dilukis; sifar tidak', (tester) async {
    final placement = ValueNotifier<CarPlacement?>(
      const CarPlacement(yawDeg: 0, tiltDeg: 56, anchorY: 0.69, opacity: 0.4),
    );
    addTearDown(placement.dispose);
    await tester.pumpWidget(host(placement, const Size(390, 844)));
    expect(paintObject(tester), paints..path());

    placement.value = const CarPlacement(
      yawDeg: 0,
      tiltDeg: 56,
      anchorY: 0.69,
      opacity: 0,
    );
    await tester.pump();
    expect(paintObject(tester), isNot(paints..path()));
  });

  testWidgets(
    'kereta dilukis tepat di tapak yang diminta (tengah, anchorY tinggi skrin)',
    (tester) async {
      const size = Size(390, 844);
      usePhoneSurface(tester);
      for (final anchorY in [0.69, 0.62]) {
        final key = GlobalKey();
        final placement = ValueNotifier<CarPlacement?>(
          CarPlacement(yawDeg: 0, tiltDeg: 56, anchorY: anchorY),
        );
        addTearDown(placement.dispose);
        await tester.pumpWidget(host(placement, size, key: key));

        final bounds = await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final w = image.width, h = image.height;
          image.dispose();
          var minX = w, maxX = -1, minY = h, maxY = -1;
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              if (data.getUint8((y * w + x) * 4 + 3) > 90) {
                minX = math.min(minX, x);
                maxX = math.max(maxX, x);
                minY = math.min(minY, y);
                maxY = math.max(maxY, y);
              }
            }
          }
          return (minX, maxX, minY, maxY, w, h);
        });
        final (minX, maxX, minY, maxY, w, h) = bounds!;
        expect(maxX, greaterThan(0), reason: 'sesuatu dilukis');
        final scale = w / size.width;
        // Tengah mendatar; menegak: badan menjulang ke atas dari tapak jadi pusat piksel sedikit di atas.
        expect(((minX + maxX) / 2) / scale, closeTo(size.width / 2, 4));
        final baseY = size.height * anchorY;
        expect(
          maxY / scale,
          closeTo(baseY + 8, 14),
          reason: 'tapak di anchorY $anchorY',
        );
        expect(minY / scale, lessThan(baseY - 20));
        expect(h, greaterThan(0));
      }
    },
  );
}
