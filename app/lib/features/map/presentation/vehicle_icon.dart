import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../navigation/presentation/car/car_mesh.dart';
import '../../navigation/presentation/car/car_renderer.dart';

/// Ukuran piksel imej ikon kenderaan. Dilukis dengan MapLibre pada `iconSize` kecil supaya tajam
/// pada skrin berketumpatan tinggi.
const vehicleIconPixels = 192;

/// Sprite kereta dari pandangan atas untuk lapisan peta. Digunakan HANYA apabila kamera tidak mengikut
/// kenderaan (pengguna menggerakkan peta atau pandangan keseluruhan), kerana ketika itu kereta mesti
/// terletak pada koordinat geografi. Semasa mengikut, kereta 3D penuh dilukis oleh `VehicleOverlay`.
///
/// Dilukis dengan enjin kereta yang sama supaya kedua-duanya sama rupa. Tiada bayang atau cahaya
/// sekeliling kerana lapisan peta menambah sendiri.
Future<Uint8List> renderVehicleIcon({
  required Color fill,
  VehicleKind kind = VehicleKind.car,
}) async {
  const s = vehicleIconPixels * 1.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, s, s));
  CarRenderer(kind.mesh).paint(
    canvas,
    anchor: const Offset(s / 2, s / 2),
    lengthPx: s * 0.84 * kind.screenScale,
    yawDeg: 0,
    tiltDeg: 0,
    palette: CarPalette.fromPrimary(fill).withoutHalo(),
    shadow: false,
  );
  final image = await recorder.endRecording().toImage(
    vehicleIconPixels,
    vehicleIconPixels,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
