import 'dart:ui' as ui;

import 'package:fgmap/features/map/presentation/vehicle_icon.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sprite kereta lapisan peta: PNG sah, dipusatkan, dan menghadap atas',
    () async {
      final png = await renderVehicleIcon(fill: const Color(0xFF2563EB));
      expect(png.length, greaterThan(500));
      // Tandatangan PNG.
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, vehicleIconPixels);
      expect(image.height, vehicleIconPixels);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var minX = image.width, maxX = -1, minY = image.height, maxY = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (data.getUint8((y * image.width + x) * 4 + 3) > 40) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      image.dispose();
      // Memanjang menegak (hidung ke atas), dipusatkan, dan muat dalam imej tanpa terpotong.
      expect(maxY - minY, greaterThan((maxX - minX) * 1.9));
      expect(((minX + maxX) / 2 - vehicleIconPixels / 2).abs(), lessThan(3));
      expect(((minY + maxY) / 2 - vehicleIconPixels / 2).abs(), lessThan(4));
      expect(minY, greaterThan(0));
      expect(maxY, lessThan(vehicleIconPixels - 1));
    },
  );
}
