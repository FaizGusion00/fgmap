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
  static const blue = Color(0xFF2563EB);
}

/// Koordinat dalam ruang ikon 1024 x 1024 (disalin daripada SVG ikon).
abstract final class SplashGeometry {
  /// Laluan utama: dari titik mula ke penanda destinasi.
  static Path route() => Path()
    ..moveTo(250, 790)
    ..relativeLineTo(0, -176)
    ..relativeLineTo(156, 0)
    ..lineTo(406, 462)
    ..relativeLineTo(214, 0)
    ..lineTo(620, 326)
    ..relativeQuadraticBezierTo(0, -54, 54, -54)
    ..relativeLineTo(82, 0);

  /// Penanda destinasi (titisan).
  static Path pin() => Path()
    ..moveTo(756, 132)
    ..relativeCubicTo(-81, 0, -146, 65, -146, 146)
    ..relativeCubicTo(0, 108, 146, 244, 146, 244)
    ..relativeCubicTo(0, 0, 146, -136, 146, -244)
    ..relativeCubicTo(0, -81, -65, -146, -146, -146)
    ..close();

  static const start = Offset(250, 790);
  static const pinCenter = Offset(756, 278);

  /// Jalan latar samar (ruang 1024), dilukis dengan kelegapan rendah.
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
  double get routeDrawn => _stage(t, 0.14, 0.70, Curves.easeInOutCubic);

  /// Penanda jatuh dari atas dan mendarat (0 = di atas, 1 = mendarat).
  double get pinDrop => _stage(t, 0.60, 0.84, Curves.easeOutBack);

  double get pinOpacity => _stage(t, 0.60, 0.70, Curves.easeOut);

  /// Gelombang di destinasi selepas penanda mendarat.
  double get ripple => _stage(t, 0.80, 1.0, Curves.easeOutCubic);

  double get wordmark => _stage(t, 0.68, 0.92, Curves.easeOutCubic);

  double get tagline => _stage(t, 0.80, 1.0, Curves.easeOut);
}

/// Melukis splash: jalan latar, laluan yang dilukis dari titik mula, penanda yang mendarat dan gelombang.
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
          ..color = SplashColors.road.withValues(alpha: 0.14 * bg),
      );
    }
    canvas.restore();

    // Seni utama.
    final scale = artRect.width / 1024;
    canvas.save();
    canvas.translate(artRect.left, artRect.top);
    canvas.scale(scale);

    final route = SplashGeometry.route();
    final metric = route.computeMetrics().first;
    final drawn = timeline.routeDrawn;
    if (drawn > 0) {
      final partial = metric.extractPath(0, metric.length * drawn);
      canvas.drawPath(
        partial,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 76
          ..color = SplashColors.white,
      );
      canvas.drawPath(
        partial,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 34
          ..color = SplashColors.teal,
      );
    }

    // Titik mula.
    final dot = timeline.startDot;
    if (dot > 0) {
      canvas.save();
      canvas.translate(SplashGeometry.start.dx, SplashGeometry.start.dy);
      canvas.scale(dot.clamp(0.0, 1.2));
      canvas.drawCircle(Offset.zero, 43, Paint()..color = SplashColors.white);
      canvas.drawCircle(Offset.zero, 19, Paint()..color = SplashColors.blue);
      canvas.restore();
    }

    // Gelombang di destinasi.
    final ripple = timeline.ripple;
    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(
        SplashGeometry.pinCenter.translate(0, 244),
        40 + 220 * ripple,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = SplashColors.teal.withValues(alpha: 0.5 * (1 - ripple)),
      );
    }

    // Penanda: jatuh dari 220 unit di atas dan mendarat.
    final pinOpacity = timeline.pinOpacity;
    if (pinOpacity > 0) {
      final drop = (1 - timeline.pinDrop) * -220;
      canvas.save();
      canvas.translate(0, drop);
      canvas.drawPath(
        SplashGeometry.pin(),
        Paint()..color = SplashColors.white.withValues(alpha: pinOpacity),
      );
      canvas.drawCircle(
        SplashGeometry.pinCenter,
        48,
        Paint()..color = SplashColors.blue.withValues(alpha: pinOpacity),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashPainter old) =>
      old.timeline.t != timeline.t || old.artRect != artRect;
}
