import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Ukuran piksel imej ikon kenderaan. Dilukis dengan MapLibre pada `iconSize` kecil supaya tajam
/// pada skrin berketumpatan tinggi.
const vehicleIconPixels = 192;

/// Melukis anak panah navigasi (ala Waze/Google): badan biru, tepi putih, bayang lembut. Dilukis
/// dalam kod supaya tiada aset binari dan warna mengikut tema.
Future<Uint8List> renderVehicleIcon({
  required Color fill,
  Color outline = const Color(0xFFFFFFFF),
}) async {
  const s = vehicleIconPixels * 1.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, s, s));

  // Anak panah menghala ke atas (utara = hadapan kenderaan).
  final path = Path()
    ..moveTo(s * 0.5, s * 0.10)
    ..lineTo(s * 0.80, s * 0.84)
    ..lineTo(s * 0.5, s * 0.66)
    ..lineTo(s * 0.20, s * 0.84)
    ..close();

  canvas.drawPath(
    path.shift(const Offset(0, 5)),
    Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(path, Paint()..color = fill);
  // Serlah lembut pada separuh kiri untuk kesan dimensi.
  canvas.drawPath(
    Path()
      ..moveTo(s * 0.5, s * 0.10)
      ..lineTo(s * 0.5, s * 0.66)
      ..lineTo(s * 0.20, s * 0.84)
      ..close(),
    Paint()..color = const Color(0x26FFFFFF),
  );

  final image = await recorder.endRecording().toImage(
    vehicleIconPixels,
    vehicleIconPixels,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
