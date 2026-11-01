import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Warna jenama (sama dengan ikon app `assets/branding/fgmap-app-icon.svg`).
abstract final class SplashColors {
  static const navTop = Color(0xFF173B78);
  static const navBottom = Color(0xFF10244A);
  static const road = Color(0xFF8EB5F4);
  static const white = Color(0xFFF7F9FC);
  static const teal = Color(0xFF19D3B8);
  static const tealLight = Color(0xFF3FF0D2);
  static const tealDark = Color(0xFF12B9A0);
  static const blue = Color(0xFF2563EB);
}

/// Tanda "F-laluan" dalam ruang tanda (disalin daripada `assets/branding/fgmap-mark.svg`):
/// titik mula, laluan yang naik dan membelok ke kanan, lengan tengah F (simpang) dan anak panah arah.
/// Tanda dipetakan ke ruang ikon 1024 dengan [markScale] berpusat pada [markCenter], sama seperti SVG.
abstract final class SplashGeometry {
  /// Lebar garisan laluan dan lengan.
  static const stroke = 136.0;

  /// Skala tanda dalam ruang ikon 1024 (`scale(.84)` dalam SVG).
  static const markScale = 0.84;

  /// Pusat kotak sempadan tanda dalam ruang tanda.
  static const markCenter = Offset(563, 497);

  /// Laluan utama: dari titik mula, naik, membelok ke kanan, hingga ke pangkal anak panah.
  static Path route() => Path()
    ..moveTo(372, 800)
    ..lineTo(372, 418)
    ..arcToPoint(const Offset(522, 268), radius: const Radius.circular(150))
    ..lineTo(592, 268);

  /// Lengan tengah F: simpang dari batang ke kanan.
  static const armStart = Offset(372, 540);
  static const armEnd = Offset(530, 540);

  /// Anak panah arah (bertakuk), diisi dan disurih dengan sambungan bulat.
  static Path arrow() => Path()
    ..moveTo(560, 108)
    ..lineTo(840, 268)
    ..lineTo(560, 428)
    ..lineTo(616, 268)
    ..close();

  static const arrowStroke = 36.0;

  static const start = Offset(372, 800);
  static const arrowCenter = Offset(690, 268);

  /// Peta ruang tanda ke ruang ikon 1024.
  static Offset toIcon(Offset p) =>
      (p - markCenter) * markScale + const Offset(512, 512);

  /// Jalan latar samar (ruang 1024), dilukis dengan kelegapan rendah sebagai suasana splash sahaja
  /// (bukan sebahagian daripada logo).
  static List<(Path, double)> backgroundRoads() => [
    (
      Path()
        ..moveTo(88, 230)
        ..relativeLineTo(210, 0)
        ..relativeLineTo(74, 74)
        ..relativeLineTo(170, 0)
        ..relativeLineTo(80, -80)
        ..relativeLineTo(310, 0),
      24,
    ),
    (
      Path()
        ..moveTo(132, 868)
        ..relativeLineTo(170, 0)
        ..relativeLineTo(82, -82)
        ..relativeLineTo(0, -136)
        ..relativeLineTo(84, -84)
        ..relativeLineTo(120, 0)
        ..relativeLineTo(70, -70)
        ..relativeLineTo(290, 0),
      22,
    ),
    (
      Path()
        ..moveTo(150, 106)
        ..relativeLineTo(0, 132)
        ..relativeLineTo(-64, 64)
        ..relativeLineTo(0, 190)
        ..relativeLineTo(75, 75)
        ..relativeLineTo(0, 118)
        ..relativeLineTo(-58, 58)
        ..relativeLineTo(0, 126),
      20,
    ),
    (
      Path()
        ..moveTo(873, 98)
        ..relativeLineTo(0, 154)
        ..relativeLineTo(-72, 72)
        ..relativeLineTo(0, 116)
        ..relativeLineTo(91, 91)
        ..relativeLineTo(0, 156)
        ..relativeLineTo(-70, 70)
        ..relativeLineTo(0, 168),
      22,
    ),
    (
      Path()
        ..moveTo(424, 104)
        ..relativeLineTo(0, 126)
        ..relativeLineTo(-60, 60)
        ..relativeLineTo(0, 120)
        ..relativeLineTo(78, 78),
      18,
    ),
  ];
}

/// Peringkat animasi splash sebagai fungsi nilai pengawal 0..1. Dipisahkan daripada pelukis supaya
/// boleh diuji tanpa merender.
class SplashTimeline {
  const SplashTimeline(this.t);

  final double t;

  static double _stage(
    double t,
    double begin,
    double end, [
    Curve curve = Curves.linear,
  ]) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return curve.transform((t - begin) / (end - begin));
  }

  /// Jalan latar samar muncul.
  double get background => _stage(t, 0.0, 0.30, Curves.easeOut);

  /// Titik mula membesar (sedikit melantun).
  double get startDot => _stage(t, 0.05, 0.22, Curves.easeOutBack);

  /// Pecahan laluan yang telah dilukis.
  double get routeDrawn => _stage(t, 0.14, 0.62, Curves.easeInOutCubic);

  /// Lengan tengah F memanjang dari batang selepas laluan melepasi simpang.
  double get arm => _stage(t, 0.36, 0.58, Curves.easeOutCubic);

  /// Anak panah meluncur ke hadapan dan membesar ke tempatnya (0 = belum, 1 = di tempat).
  double get arrowIn => _stage(t, 0.56, 0.80, Curves.easeOutBack);

  double get arrowOpacity => _stage(t, 0.56, 0.64, Curves.easeOut);

  /// Gelombang dari anak panah selepas ia tiba.
  double get ripple => _stage(t, 0.76, 1.0, Curves.easeOutCubic);

  double get wordmark => _stage(t, 0.68, 0.92, Curves.easeOutCubic);

  double get tagline => _stage(t, 0.80, 1.0, Curves.easeOut);
}

/// Melukis splash: jalan latar samar, kemudian tanda F-laluan dibina — titik mula, laluan dilukis naik
/// dan membelok, lengan simpang, anak panah meluncur masuk dan gelombang.
class SplashPainter extends CustomPainter {
  SplashPainter({required this.timeline, required this.artRect});

  final SplashTimeline timeline;

  /// Segi empat tempat ruang ikon 1024 dipetakan pada skrin.
  final Rect artRect;

  @override
  void paint(Canvas canvas, Size size) {
    // Latar: gradien jenama.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          const [SplashColors.navTop, SplashColors.navBottom],
        ),
    );

    // Jalan latar menutupi seluruh skrin (skala "cover" ruang 1024).
    final cover = math.max(size.width, size.height) / 1024;
    canvas.save();
    canvas.translate(
      (size.width - 1024 * cover) / 2,
      (size.height - 1024 * cover) / 2,
    );
    canvas.scale(cover);
    final bg = timeline.background;
    for (final (path, width) in SplashGeometry.backgroundRoads()) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = width
          ..color = SplashColors.road.withValues(alpha: 0.10 * bg),
      );
    }
    canvas.restore();

    // Seni utama: ruang ikon 1024 dipetakan ke artRect, kemudian ruang tanda seperti dalam SVG.
    final scale = artRect.width / 1024;
    canvas.save();
    canvas.translate(artRect.left, artRect.top);
    canvas.scale(scale);
    canvas.translate(512, 512);
    canvas.scale(SplashGeometry.markScale);
    canvas.translate(
      -SplashGeometry.markCenter.dx,
      -SplashGeometry.markCenter.dy,
    );

    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = SplashGeometry.stroke
      ..color = SplashColors.white;

    // Lengan tengah F memanjang dari batang.
    final arm = timeline.arm;
    if (arm > 0) {
      canvas.drawLine(
        SplashGeometry.armStart,
        Offset.lerp(SplashGeometry.armStart, SplashGeometry.armEnd, arm)!,
        white,
      );
    }

    // Laluan dilukis dari titik mula.
    final drawn = timeline.routeDrawn;
    if (drawn > 0) {
      final metric = SplashGeometry.route().computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * drawn), white);
    }

    // Gelombang dari anak panah.
    final ripple = timeline.ripple;
    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(
        SplashGeometry.arrowCenter,
        120 + 260 * ripple,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = SplashColors.teal.withValues(alpha: 0.5 * (1 - ripple)),
      );
    }

    // Anak panah: meluncur 140 unit ke hadapan dan membesar dari 60% ke tempatnya.
    final arrowOpacity = timeline.arrowOpacity;
    if (arrowOpacity > 0) {
      final p = timeline.arrowIn;
      const c = SplashGeometry.arrowCenter;
      canvas.save();
      canvas.translate(c.dx - 140 * (1 - p), c.dy);
      canvas.scale(0.6 + 0.4 * p);
      canvas.translate(-c.dx, -c.dy);
      final shader =
          ui.Gradient.linear(const Offset(560, 108), const Offset(840, 428), [
            SplashColors.tealLight.withValues(alpha: arrowOpacity),
            SplashColors.tealDark.withValues(alpha: arrowOpacity),
          ]);
      canvas.drawPath(
        SplashGeometry.arrow(),
        Paint()
          ..shader = shader
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        SplashGeometry.arrow(),
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = SplashGeometry.arrowStroke,
      );
      canvas.restore();
    }

    // Titik mula (di atas pangkal laluan).
    final dot = timeline.startDot;
    if (dot > 0) {
      canvas.save();
      canvas.translate(SplashGeometry.start.dx, SplashGeometry.start.dy);
      canvas.scale(dot.clamp(0.0, 1.2));
      canvas.drawCircle(Offset.zero, 104, Paint()..color = SplashColors.white);
      canvas.drawCircle(Offset.zero, 46, Paint()..color = SplashColors.blue);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashPainter old) =>
      old.timeline.t != timeline.t || old.artRect != artRect;
}
