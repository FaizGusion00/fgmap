import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Ukuran piksel imej ikon kenderaan. Dilukis dengan MapLibre pada `iconSize` kecil supaya tajam
/// pada skrin berketumpatan tinggi.
const vehicleIconPixels = 192;

/// Melukis ikon kereta dari pandangan atas. Ia kekal tajam pada skrin berketumpatan tinggi dan
/// menggunakan warna utama tema tanpa aset binari.
Future<Uint8List> renderVehicleIcon({
  required Color fill,
  Color outline = const Color(0xFFFFFFFF),
}) async {
  const s = vehicleIconPixels * 1.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, s, s));

  final body = Path()
    ..moveTo(s * 0.5, s * 0.08)
    ..cubicTo(s * 0.62, s * 0.08, s * 0.68, s * 0.15, s * 0.71, s * 0.27)
    ..lineTo(s * 0.77, s * 0.67)
    ..cubicTo(s * 0.79, s * 0.81, s * 0.73, s * 0.89, s * 0.63, s * 0.89)
    ..lineTo(s * 0.37, s * 0.89)
    ..cubicTo(s * 0.27, s * 0.89, s * 0.21, s * 0.81, s * 0.23, s * 0.67)
    ..lineTo(s * 0.29, s * 0.27)
    ..cubicTo(s * 0.32, s * 0.15, s * 0.38, s * 0.08, s * 0.5, s * 0.08)
    ..close();

  canvas.drawPath(
    body.shift(const Offset(0, 5)),
    Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );
  final wheelPaint = Paint()..color = const Color(0xFF172033);
  for (final rect in const [
    Rect.fromLTRB(s * 0.19, s * 0.29, s * 0.31, s * 0.45),
    Rect.fromLTRB(s * 0.69, s * 0.29, s * 0.81, s * 0.45),
    Rect.fromLTRB(s * 0.19, s * 0.63, s * 0.31, s * 0.79),
    Rect.fromLTRB(s * 0.69, s * 0.63, s * 0.81, s * 0.79),
  ]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(s * 0.035)),
      wheelPaint,
    );
  }

  canvas.drawPath(
    body,
    Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(body, Paint()..color = fill);

  final glassPaint = Paint()..color = const Color(0xFF172B45);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTRB(s * 0.36, s * 0.23, s * 0.64, s * 0.43),
      const Radius.circular(s * 0.045),
    ),
    glassPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTRB(s * 0.37, s * 0.56, s * 0.63, s * 0.70),
      const Radius.circular(s * 0.04),
    ),
    glassPaint,
  );
  final detailPaint = Paint()..color = const Color(0xBFFFFFFF);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTRB(s * 0.40, s * 0.46, s * 0.60, s * 0.50),
      const Radius.circular(s * 0.02),
    ),
    detailPaint,
  );
  final lightPaint = Paint()..color = const Color(0xFFFFF3C4);
  canvas.drawCircle(const Offset(s * 0.36, s * 0.17), s * 0.025, lightPaint);
  canvas.drawCircle(const Offset(s * 0.64, s * 0.17), s * 0.025, lightPaint);

  final image = await recorder.endRecording().toImage(
    vehicleIconPixels,
    vehicleIconPixels,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
