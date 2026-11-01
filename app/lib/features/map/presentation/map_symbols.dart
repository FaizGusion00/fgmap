import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/poi_category.dart';

/// Lebar imej pin POI dan anak panah arah (piksel).
const poiPinWidth = 96;
const poiPinHeight = 124;
const chevronPixels = 64;

Color poiColor(PoiCategory c) => switch (c) {
  PoiCategory.fuel => const Color(0xFFD84315),
  PoiCategory.food => const Color(0xFFEF6C00),
  PoiCategory.shop => const Color(0xFF8E24AA),
  PoiCategory.school => const Color(0xFF1E64C8),
  PoiCategory.health => const Color(0xFFC62828),
  PoiCategory.bank => const Color(0xFF2E7D32),
  PoiCategory.worship => const Color(0xFF00796B),
  PoiCategory.lodging => const Color(0xFF6D4C41),
  PoiCategory.parking => const Color(0xFF455A64),
};

IconData poiIcon(PoiCategory c) => switch (c) {
  PoiCategory.fuel => Icons.local_gas_station_rounded,
  PoiCategory.food => Icons.restaurant_rounded,
  PoiCategory.shop => Icons.shopping_bag_rounded,
  PoiCategory.school => Icons.school_rounded,
  PoiCategory.health => Icons.local_hospital_rounded,
  PoiCategory.bank => Icons.account_balance_rounded,
  PoiCategory.worship => Icons.mosque_rounded,
  PoiCategory.lodging => Icons.hotel_rounded,
  PoiCategory.parking => Icons.local_parking_rounded,
};

Future<Uint8List> _encode(ui.PictureRecorder recorder, int w, int h) async {
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Pin tempat: kepala bulat berwarna dengan cincin putih, ekor ke titik sebenar, dan ikon jenis.
/// Titik sauh ialah hujung ekor (tengah-bawah imej).
Future<Uint8List> renderPoiPin(PoiCategory category) async {
  const w = poiPinWidth * 1.0;
  const h = poiPinHeight * 1.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
  const r = w * 0.4;
  const head = Offset(w / 2, r + 4);
  const tip = Offset(w / 2, h - 4);

  Path pin(double grow) {
    final rr = r + grow;
    // Kepala bulat dan ekor segi tiga yang bertemu dengan licin pada bahu.
    final a = head + Offset(-rr * 0.78, rr * 0.62);
    final b = head + Offset(rr * 0.78, rr * 0.62);
    return Path()
      ..addOval(Rect.fromCircle(center: head, radius: rr))
      ..moveTo(a.dx, a.dy)
      ..lineTo(tip.dx, tip.dy + grow)
      ..lineTo(b.dx, b.dy)
      ..close();
  }

  canvas.drawPath(
    pin(2).shift(const Offset(0, 3)),
    Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.drawPath(pin(0), Paint()..color = Colors.white);
  final inner = pin(-5);
  canvas.drawPath(inner, Paint()..color = poiColor(category));

  final icon = poiIcon(category);
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: r * 1.15,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, head - Offset(painter.width / 2, painter.height / 2));
  return _encode(recorder, poiPinWidth, poiPinHeight);
}

/// Anak panah arah pada laluan: chevron putih tebal dengan garis tepi gelap nipis supaya jelas di
/// atas laluan hijau/biru dan di bawah silau. Menuding ke atas (utara) sebelum diputar peta.
Future<Uint8List> renderChevron() async {
  const s = chevronPixels * 1.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, s, s));
  final path = Path()
    ..moveTo(s * 0.5, s * 0.16)
    ..lineTo(s * 0.86, s * 0.56)
    ..lineTo(s * 0.72, s * 0.7)
    ..lineTo(s * 0.5, s * 0.46)
    ..lineTo(s * 0.28, s * 0.7)
    ..lineTo(s * 0.14, s * 0.56)
    ..close();
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(path, Paint()..color = Colors.white);
  return _encode(recorder, chevronPixels, chevronPixels);
}
