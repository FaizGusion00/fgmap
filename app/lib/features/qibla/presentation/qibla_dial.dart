import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Warna dail. Dipisahkan daripada [ThemeData] supaya mudah diuji dan konsisten pada tema cerah/gelap.
@immutable
class QiblaDialColors {
  const QiblaDialColors({
    required this.disc,
    required this.discEdge,
    required this.tick,
    required this.label,
    required this.north,
    required this.gold,
    required this.ok,
    required this.phoneMark,
  });

  final Color disc;
  final Color discEdge;
  final Color tick;
  final Color label;
  final Color north;
  final Color gold;
  final Color ok;
  final Color phoneMark;

  factory QiblaDialColors.of(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    return QiblaDialColors(
      disc: dark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
      discEdge: cs.outlineVariant,
      tick: cs.onSurface.withValues(alpha: 0.55),
      label: cs.onSurface,
      north: const Color(0xFFE5484D),
      gold: const Color(0xFFE0A526),
      ok: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
      phoneMark: cs.primary,
    );
  }
}

/// Dail kompas kiblat. Cakera berputar supaya utara sentiasa menghala ke utara sebenar; penanda
/// bahagian atas telefon kekal di atas. Apabila ikon Kaabah (pada bearing kiblat) berada di bawah
/// penanda itu, telefon menghadap kiblat.
///
/// [heading] ialah [ValueListenable] supaya hanya lukisan ini yang dilukis semula pada setiap bingkai
/// (bukan seluruh halaman). Tanpa [hasHeading] (tiada sensor), cakera tidak berputar: utara di atas.
class QiblaDialPainter extends CustomPainter {
  QiblaDialPainter({
    required this.heading,
    required this.qibla,
    required this.aligned,
    required this.hasHeading,
    required this.colors,
    required this.cardinals,
  }) : super(repaint: heading);

  final ValueListenable<double> heading;

  /// Arah kiblat dari utara benar (0–360).
  final double qibla;
  final bool aligned;
  final bool hasHeading;
  final QiblaDialColors colors;

  /// Huruf mata angin U, T, S, B (atau N, E, S, W) mengikut bahasa.
  final List<String> cardinals;

  final _cache = <String, TextPainter>{};

  TextPainter _text(String s, double size, Color color, FontWeight w) {
    final key = '$s|$size|${color.toARGB32()}|${w.value}';
    return _cache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: color, fontWeight: w),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  /// Lukis [s] berpusat di [at] dan tegak walaupun kanvas sedang diputar sebanyak [canvasRotation].
  void _upright(
    Canvas canvas,
    String s,
    Offset at,
    double size,
    Color color,
    FontWeight w,
    double canvasRotation,
  ) {
    final tp = _text(s, size, color, w);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-canvasRotation);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s / 2 - s * 0.045;
    final h = hasHeading ? heading.value : 0.0;
    final rot = -h * math.pi / 180;

    // Cakera + cahaya apabila tepat.
    if (aligned) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = colors.ok.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colors.disc,
            Color.lerp(colors.disc, colors.discEdge, 0.35)!,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? s * 0.012 : s * 0.006
        ..color = aligned ? colors.ok : colors.discEdge,
    );

    // --- Bahagian berputar ---
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);

    // Tanda darjah setiap 5°; lebih panjang pada 30°, terpanjang pada mata angin.
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * math.pi / 180;
      final cardinal = i % 18 == 0;
      final major = i % 6 == 0;
      final len = cardinal ? s * 0.055 : (major ? s * 0.04 : s * 0.022);
      final p = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cardinal ? s * 0.011 : (major ? s * 0.007 : s * 0.004)
        ..color = i == 0 ? colors.north : colors.tick;
      final outer = Offset(
        math.sin(a) * (r - s * 0.018),
        -math.cos(a) * (r - s * 0.018),
      );
      final inner = Offset(
        math.sin(a) * (r - s * 0.018 - len),
        -math.cos(a) * (r - s * 0.018 - len),
      );
      canvas.drawLine(inner, outer, p);
    }

    // Huruf mata angin dan angka 30°, kekal tegak.
    final labelR = r - s * 0.115;
    for (var i = 0; i < 12; i++) {
      final deg = i * 30;
      final a = deg * math.pi / 180;
      final at = Offset(math.sin(a) * labelR, -math.cos(a) * labelR);
      if (deg % 90 == 0) {
        final idx = deg ~/ 90;
        _upright(
          canvas,
          cardinals[idx.clamp(0, cardinals.length - 1)],
          at,
          s * 0.075,
          deg == 0 ? colors.north : colors.label,
          FontWeight.w800,
          rot,
        );
      } else {
        _upright(
          canvas,
          '$deg',
          Offset(
            math.sin(a) * (labelR + s * 0.004),
            -math.cos(a) * (labelR + s * 0.004),
          ),
          s * 0.036,
          colors.tick,
          FontWeight.w600,
          rot,
        );
      }
    }

    // Garis dan ikon Kaabah pada bearing kiblat.
    final qa = qibla * math.pi / 180;
    final dir = Offset(math.sin(qa), -math.cos(qa));
    final kaabaC = dir * (r * 0.60);
    final lineColor = aligned ? colors.ok : colors.gold;
    canvas.drawLine(
      dir * (r * 0.22),
      dir * (r * 0.60 - s * 0.075),
      Paint()
        ..color = lineColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.012,
    );
    canvas.save();
    canvas.translate(kaabaC.dx, kaabaC.dy);
    canvas.rotate(-rot); // ikon sentiasa tegak
    _paintKaaba(canvas, s * (aligned ? 0.19 : 0.16), aligned);
    canvas.restore();

    canvas.restore();

    // --- Bahagian tetap: penanda bahagian atas telefon ---
    if (hasHeading) {
      final markColor = aligned ? colors.ok : colors.phoneMark;
      canvas.drawLine(
        Offset(c.dx, c.dy - r * 0.2),
        Offset(c.dx, c.dy - r + s * 0.075),
        Paint()
          ..color = markColor.withValues(alpha: 0.35)
          ..strokeWidth = s * 0.006
          ..strokeCap = StrokeCap.round,
      );
      final tri = Path()
        ..moveTo(c.dx, c.dy - r + s * 0.052)
        ..lineTo(c.dx - s * 0.035, c.dy - r - s * 0.012)
        ..lineTo(c.dx + s * 0.035, c.dy - r - s * 0.012)
        ..close();
      canvas.drawPath(tri, Paint()..color = markColor);
    }

    // Cakera pusat (angka arah dilapis oleh widget).
    canvas.drawCircle(c, r * 0.2, Paint()..color = colors.disc);
    canvas.drawCircle(
      c,
      r * 0.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.005
        ..color = colors.discEdge,
    );
  }

  /// Kaabah ringkas: kubus hitam, jalur emas dan pintu.
  void _paintKaaba(Canvas canvas, double size, bool glow) {
    final w = size * 0.82;
    final h = size * 0.82;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, size * 0.06), width: w, height: h),
      Radius.circular(size * 0.07),
    );
    if (glow) {
      canvas.drawRRect(
        body.inflate(size * 0.05),
        Paint()
          ..color = colors.ok.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.12),
      );
    }
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 3, true);
    canvas.drawRRect(body, Paint()..color = const Color(0xFF15151A));
    // Muka atas (isyarat 3D ringan).
    final top = Path()
      ..moveTo(body.left + size * 0.04, body.top + size * 0.02)
      ..lineTo(body.right - size * 0.04, body.top + size * 0.02)
      ..lineTo(body.right - size * 0.10, body.top - size * 0.1)
      ..lineTo(body.left + size * 0.10, body.top - size * 0.1)
      ..close();
    canvas.drawPath(top, Paint()..color = const Color(0xFF2A2A33));
    // Jalur emas (kiswah) dan pintu.
    canvas.drawRect(
      Rect.fromLTWH(body.left, body.top + h * 0.2, w, h * 0.16),
      Paint()..color = colors.gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + w * 0.58,
          body.top + h * 0.5,
          w * 0.2,
          h * 0.38,
        ),
        Radius.circular(size * 0.03),
      ),
      Paint()..color = colors.gold,
    );
  }

  @override
  bool shouldRepaint(covariant QiblaDialPainter old) =>
      old.qibla != qibla ||
      old.aligned != aligned ||
      old.hasHeading != hasHeading ||
      old.colors != colors ||
      !listEquals(old.cardinals, cardinals);
}
