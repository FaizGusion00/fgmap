import 'package:flutter/foundation.dart' show ValueListenable, immutable;
import 'package:flutter/material.dart';

import 'car_renderer.dart';

/// Di mana dan bagaimana kereta dilukis pada skrin semasa kamera mengikut kenderaan.
@immutable
class CarPlacement {
  const CarPlacement({
    required this.yawDeg,
    required this.tiltDeg,
    required this.anchorY,
    this.anchorX = 0.5,
    this.opacity = 1,
    this.brake = 0,
  });

  /// Arah kereta relatif kepada atas skrin, ikut jam positif. Hampir 0 di jalan lurus; berayun di
  /// selekoh kerana arah kamera melicin di belakang arah kereta.
  final double yawDeg;

  /// Condongan kamera dari menegak (0 = pandangan atas).
  final double tiltDeg;

  /// Kedudukan tapak kereta dari atas skrin, sebagai pecahan tinggi (0.5 = tengah).
  final double anchorY;

  /// Kedudukan mendatar tapak kereta sebagai pecahan lebar (0.5 = tengah).
  final double anchorX;

  /// 0..1; kereta ini muncul perlahan apabila peralihan masuk kamera hampir selesai, supaya tidak
  /// terpacak di skrin ketika peta masih meluncur ke kenderaan.
  final double opacity;

  /// 0..1 kekuatan lampu brek.
  final double brake;

  /// Beza yang tidak kelihatan oleh mata diabaikan supaya kereta tidak dilukis semula tanpa sebab
  /// ketika kenderaan stabil di jalan lurus.
  bool isVisiblySameAs(CarPlacement? other) =>
      other != null &&
      (yawDeg - other.yawDeg).abs() < 0.05 &&
      (tiltDeg - other.tiltDeg).abs() < 0.05 &&
      (anchorY - other.anchorY).abs() < 0.0005 &&
      (anchorX - other.anchorX).abs() < 0.0005 &&
      (opacity - other.opacity).abs() < 0.01 &&
      (brake - other.brake).abs() < 0.02;
}

/// Kereta 3D di atas peta semasa navigasi. Dilukis sepenuhnya oleh Flutter (tiada panggilan ke
/// platform peta setiap bingkai), jadi sentiasa serentak dengan kamera dan tidak berkelip.
class VehicleOverlay extends StatefulWidget {
  const VehicleOverlay({
    super.key,
    required this.placement,
    required this.palette,
  });

  final ValueListenable<CarPlacement?> placement;
  final CarPalette palette;

  /// Panjang kereta pada skrin untuk tinggi paparan [height]: cukup besar untuk dibaca sebagai kereta,
  /// cukup kecil untuk tidak menutup jalan di hadapan, termasuk pada telefon mendatar.
  static double lengthFor(double height) => (height * 0.088).clamp(44.0, 80.0);

  @override
  State<VehicleOverlay> createState() => _VehicleOverlayState();
}

class _VehicleOverlayState extends State<VehicleOverlay> {
  final CarRenderer _renderer = CarRenderer();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('vehicle-overlay'),
            size: Size.infinite,
            painter: _OverlayPainter(
              placement: widget.placement,
              palette: widget.palette,
              renderer: _renderer,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.placement,
    required this.palette,
    required this.renderer,
  }) : super(repaint: placement);

  final ValueListenable<CarPlacement?> placement;
  final CarPalette palette;
  final CarRenderer renderer;

  @override
  void paint(Canvas canvas, Size size) {
    final p = placement.value;
    if (p == null || p.opacity <= 0.01) return;
    final anchor = Offset(size.width * p.anchorX, size.height * p.anchorY);
    final length = VehicleOverlay.lengthFor(size.height);
    final faded = p.opacity < 0.99;
    if (faded) {
      canvas.saveLayer(
        Rect.fromCenter(center: anchor, width: length * 3, height: length * 3),
        Paint()..color = Color.fromRGBO(0, 0, 0, p.opacity),
      );
    }
    renderer.paint(
      canvas,
      anchor: anchor,
      lengthPx: length,
      yawDeg: p.yawDeg,
      tiltDeg: p.tiltDeg,
      palette: palette,
      brake: p.brake,
    );
    if (faded) canvas.restore();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.palette != palette || old.placement != placement;
}
