import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/nav_route.dart';

/// Gambar rajah manuver: jalan yang sedang dilalui, jalan lain yang TIDAK diambil (pudar), dan anak
/// panah tebal sepanjang laluan yang mesti diambil. Pemandu melihat bentuk simpang, bukan hanya
/// simbol: "kekal kanan" ialah jalan bercabang dengan cabang kanan ditonjolkan; "susur keluar" ialah
/// jalan lurus dengan cabang keluar ke tepi. Semua dilukis untuk lalu lintas sebelah KIRI (Malaysia)
/// dalam ruang 100x100 sebagai versi kanan; versi kiri ialah cerminannya.
///
/// Kind yang tidak mempunyai gambar rajah (mula, tiba, feri, bulatan) tidak dilukis di sini: lihat
/// [ManeuverGlyph].
class ManeuverDiagram extends StatelessWidget {
  const ManeuverDiagram({
    super.key,
    required this.kind,
    required this.size,
    required this.color,
  });

  final ManeuverKind kind;
  final double size;
  final Color color;

  /// Adakah [kind] dilukis oleh gambar rajah ini.
  static bool draws(ManeuverKind kind) => switch (kind) {
    ManeuverKind.depart ||
    ManeuverKind.arrive ||
    ManeuverKind.arriveLeft ||
    ManeuverKind.arriveRight ||
    ManeuverKind.ferry ||
    ManeuverKind.roundabout => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: ManeuverDiagramPainter(kind: kind, color: color),
    ),
  );
}

class ManeuverDiagramPainter extends CustomPainter {
  const ManeuverDiagramPainter({required this.kind, required this.color});

  final ManeuverKind kind;
  final Color color;

  /// Lebar garis jalan (daripada 100) bagi laluan yang diambil dan jalan lain.
  static const _boldWidth = 15.0;
  static const _fadedWidth = 12.0;
  static const _fadedAlpha = 0.36;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale);
    if (_mirrored(kind)) {
      canvas.translate(100, 0);
      canvas.scale(-1, 1);
    }

    final bold = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _boldWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final faded = Paint()
      ..color = color.withValues(alpha: _fadedAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _fadedWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final head = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case ManeuverKind.right || ManeuverKind.left:
        canvas.drawPath(_line([(50, 54), (50, 8)]), faded);
        final p = Path()
          ..moveTo(50, 100)
          ..lineTo(50, 60)
          ..quadraticBezierTo(50, 44, 66, 44)
          ..lineTo(70, 44);
        canvas.drawPath(p, bold);
        _arrowHead(canvas, head, const Offset(70, 44), const Offset(1, 0));
      case ManeuverKind.slightRight || ManeuverKind.slightLeft:
        canvas.drawPath(_line([(40, 68), (40, 8)]), faded);
        final p = Path()
          ..moveTo(40, 100)
          ..lineTo(40, 74)
          ..quadraticBezierTo(40, 66, 47, 59)
          ..lineTo(66, 40);
        canvas.drawPath(p, bold);
        _arrowHead(canvas, head, const Offset(66, 40), _unit(1, -1));
      case ManeuverKind.sharpRight || ManeuverKind.sharpLeft:
        final p = Path()
          ..moveTo(32, 100)
          ..lineTo(32, 34)
          ..quadraticBezierTo(32, 24, 41, 29)
          ..lineTo(56, 40);
        canvas.drawPath(p, bold);
        _arrowHead(canvas, head, const Offset(56, 40), _unit(1, 0.95));
      case ManeuverKind.uTurn:
        final p = Path()
          ..moveTo(30, 100)
          ..lineTo(30, 40)
          ..cubicTo(30, 10, 82, 10, 82, 40)
          ..lineTo(82, 62);
        canvas.drawPath(p, bold);
        _arrowHead(canvas, head, const Offset(82, 62), const Offset(0, 1));
      case ManeuverKind.rampRight ||
          ManeuverKind.rampLeft ||
          ManeuverKind.exitRight ||
          ManeuverKind.exitLeft:
        // Jalan utama terus ke atas (pudar); susur keluar bercabang ke tepi (tebal).
        canvas.drawPath(_line([(38, 70), (38, 6)]), faded);
        final p = Path()
          ..moveTo(38, 100)
          ..lineTo(38, 74)
          ..cubicTo(38, 56, 52, 52, 62, 38)
          ..lineTo(70, 26);
        canvas.drawPath(p, bold);
        _arrowHead(canvas, head, const Offset(70, 26), _unit(0.52, -0.85));
      case ManeuverKind.keepRight || ManeuverKind.keepLeft:
        // Jalan bercabang dua: cabang yang tidak diambil pudar, yang diambil tebal + anak panah.
        canvas.drawPath(
          Path()
            ..moveTo(50, 66)
            ..cubicTo(50, 48, 32, 40, 28, 10),
          faded,
        );
        final p = Path()
          ..moveTo(50, 100)
          ..lineTo(50, 66)
          ..cubicTo(50, 50, 62, 44, 68, 32)
          ..lineTo(70, 28);
        canvas.drawPath(p, bold);
        _arrowHead(canvas, head, const Offset(70, 28), _unit(0.3, -0.95));
      case ManeuverKind.merge ||
          ManeuverKind.mergeRight ||
          ManeuverKind.mergeLeft:
        // Jalan yang disertai (pudar) lurus; laluan kita masuk dari bawah ke dalamnya.
        canvas.drawPath(_line([(66, 100), (66, 8)]), faded);
        final p = Path()
          ..moveTo(30, 100)
          ..lineTo(30, 82)
          ..lineTo(66, 52)
          ..lineTo(66, 30);
        canvas.drawPath(p, bold);
        _arrowHead(canvas, head, const Offset(66, 30), const Offset(0, -1));
      case ManeuverKind.straight ||
          ManeuverKind.keepStraight ||
          ManeuverKind.rampStraight ||
          ManeuverKind.none:
        canvas.drawPath(_line([(50, 100), (50, 30)]), bold);
        _arrowHead(canvas, head, const Offset(50, 30), const Offset(0, -1));
      case ManeuverKind.depart ||
          ManeuverKind.arrive ||
          ManeuverKind.arriveLeft ||
          ManeuverKind.arriveRight ||
          ManeuverKind.ferry ||
          ManeuverKind.roundabout:
        break; // Tidak dilukis di sini.
    }
    canvas.restore();
  }

  static Path _line(List<(double, double)> pts) {
    final p = Path()..moveTo(pts.first.$1, pts.first.$2);
    for (final pt in pts.skip(1)) {
      p.lineTo(pt.$1, pt.$2);
    }
    return p;
  }

  static Offset _unit(double dx, double dy) {
    final len = math.sqrt(dx * dx + dy * dy);
    return Offset(dx / len, dy / len);
  }

  /// Kepala anak panah bermula di [base] (hujung garisan tebal) menghala [dir].
  static void _arrowHead(Canvas canvas, Paint paint, Offset base, Offset dir) {
    const length = 26.0;
    const halfWidth = 19.0;
    final normal = Offset(-dir.dy, dir.dx);
    final tip = base + dir * length;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + normal.dx * halfWidth, base.dy + normal.dy * halfWidth)
      ..lineTo(base.dx - normal.dx * halfWidth, base.dy - normal.dy * halfWidth)
      ..close();
    canvas.drawPath(path, paint);
    // Sudut dibulatkan sedikit supaya sepadan dengan garisan tebal.
    canvas.drawPath(
      path,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Versi kiri ialah cerminan versi kanan.
  static bool _mirrored(ManeuverKind kind) => switch (kind) {
    ManeuverKind.left ||
    ManeuverKind.slightLeft ||
    ManeuverKind.sharpLeft ||
    ManeuverKind.rampLeft ||
    ManeuverKind.exitLeft ||
    ManeuverKind.keepLeft ||
    ManeuverKind.mergeLeft => true,
    _ => false,
  };

  @override
  bool shouldRepaint(ManeuverDiagramPainter old) =>
      old.kind != kind || old.color != color;
}
