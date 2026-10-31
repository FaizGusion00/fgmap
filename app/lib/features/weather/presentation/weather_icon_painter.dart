import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keluarga ikon cuaca. Kod WMO (Open-Meteo) dipetakan kepada keluarga, bukan satu glif setiap kod.
enum WeatherGlyph {
  clear,
  mostlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  heavyRain,
  thunder,
  snow,
}

WeatherGlyph weatherGlyphFor(int code) {
  if (code == 0) return WeatherGlyph.clear;
  if (code == 1) return WeatherGlyph.mostlyClear;
  if (code == 2) return WeatherGlyph.partlyCloudy;
  if (code == 3) return WeatherGlyph.overcast;
  if (code <= 48) return WeatherGlyph.fog;
  if (code <= 57) return WeatherGlyph.drizzle;
  if (code == 65 || code == 66 || code == 67) return WeatherGlyph.heavyRain;
  if (code <= 67) return WeatherGlyph.rain;
  if (code <= 77) return WeatherGlyph.snow;
  if (code == 82) return WeatherGlyph.heavyRain;
  if (code <= 82) return WeatherGlyph.rain;
  if (code <= 86) return WeatherGlyph.snow;
  return WeatherGlyph.thunder;
}

/// Siang? Waktu setempat 07:00–19:00 (Malaysia: matahari terbit ~07:00 dan terbenam ~19:15 sepanjang
/// tahun). Data Open-Meteo yang digunakan tidak membawa penanda siang/malam.
bool isDaytime(DateTime local) => local.hour >= 7 && local.hour < 19;

/// Palet ikon. Berwarna dan jelas pada gradien suasana cerah dan gelap.
abstract final class WeatherPalette {
  static const sunCore = Color(0xFFFFE066);
  static const sunEdge = Color(0xFFFF9F1C);
  static const ray = Color(0xFFFFC53D);
  static const moon = Color(0xFFFFE699);
  static const moonEdge = Color(0xFFF5B82E);
  static const star = Color(0xFFFFC83D);
  static const cloudTop = Color(0xFFFFFFFF);
  static const cloudBottom = Color(0xFFB4C6DE);
  static const stormTop = Color(0xFF9AA9C0);
  static const stormBottom = Color(0xFF5D6B85);
  static const rain = Color(0xFF3DA5FF);
  static const heavyRain = Color(0xFF1E88E5);
  static const bolt = Color(0xFFFFD23F);
  static const boltEdge = Color(0xFFFF9800);
  static const snow = Color(0xFFD8EEFF);
  static const fog = Color(0xFF9FB0C8);
}

/// Melukis ikon cuaca berwarna dengan gerakan. [progress] ialah 0–1 yang berulang (lihat
/// `WeatherAnimatedIcon`); semua tempoh ialah gandaan integer 1/8 saat supaya gelung tidak
/// tersentak. Ikon statik (Reduce Motion) melukis pada [progress] tetap.
class WeatherIconPainter extends CustomPainter {
  WeatherIconPainter({
    required this.glyph,
    required this.isDay,
    required Animation<double> progress,
  }) : _progress = progress,
       super(repaint: progress);

  final WeatherGlyph glyph;
  final bool isDay;
  final Animation<double> _progress;

  static final Path _cloud = _buildCloud();

  /// Awan berlebar 1, berpusat pada (0, 0).
  static Path _buildCloud() {
    final base = Path()
      ..addRRect(
        RRect.fromLTRBR(-0.5, -0.02, 0.5, 0.24, const Radius.circular(0.13)),
      );
    Path circle(double x, double y, double r) =>
        Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    var p = base;
    for (final c in [
      circle(-0.24, -0.04, 0.19),
      circle(0.06, -0.15, 0.25),
      circle(0.3, -0.02, 0.17),
    ]) {
      p = Path.combine(PathOperation.union, p, c);
    }
    return p;
  }

  void _drawCloud(
    Canvas canvas,
    Offset center,
    double width, {
    Color top = WeatherPalette.cloudTop,
    Color bottom = WeatherPalette.cloudBottom,
    double alpha = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(width);
    final bounds = _cloud.getBounds();
    // Bayang lembut di bawah awan memberi kedalaman.
    canvas.drawPath(
      _cloud.shift(const Offset(0, 0.035)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03),
    );
    canvas.drawPath(
      _cloud,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            top.withValues(alpha: alpha),
            bottom.withValues(alpha: alpha),
          ],
        ).createShader(bounds),
    );
    // Garis tepi lembut supaya awan putih kekal jelas pada latar cerah.
    canvas.drawPath(
      _cloud,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.014
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF7F97B8).withValues(alpha: 0.5 * alpha),
    );
    canvas.restore();
  }

  void _drawSun(Canvas canvas, Offset c, double r, double t) {
    final pulse = 1 + 0.05 * math.sin(t * math.pi * 2 * 4);
    // Cahaya.
    canvas.drawCircle(
      c,
      r * 1.9 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            WeatherPalette.sunCore.withValues(alpha: 0.45),
            WeatherPalette.sunCore.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.9 * pulse)),
    );
    // Sinar berputar perlahan.
    final spin = t * math.pi * 2;
    final ray = Paint()
      ..color = WeatherPalette.ray
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.26;
    for (var i = 0; i < 8; i++) {
      final a = spin + i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r * 1.3), c + dir * (r * 1.62 * pulse), ray);
    }
    canvas.drawCircle(
      c,
      r * pulse,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [WeatherPalette.sunCore, WeatherPalette.sunEdge],
        ).createShader(Rect.fromCircle(center: c, radius: r * pulse)),
    );
  }

  void _drawMoon(Canvas canvas, Offset c, double r, double t, double s) {
    final bob = math.sin(t * math.pi * 2 * 2) * r * 0.06;
    final center = c + Offset(0, bob);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
      Path()..addOval(
        Rect.fromCircle(
          center: center + Offset(r * 0.5, -r * 0.3),
          radius: r * 0.86,
        ),
      ),
    );
    canvas.drawPath(
      crescent.shift(Offset.zero),
      Paint()
        ..color = WeatherPalette.moonEdge.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
    );
    canvas.drawPath(
      crescent,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD99A12).withValues(alpha: 0.6),
    );
    canvas.drawPath(
      crescent,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WeatherPalette.moon, WeatherPalette.moonEdge],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    // Bintang berkelip.
    void star(Offset p, double size, double phase) {
      final a =
          0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * 3 + phase));
      final paint = Paint()
        ..color = WeatherPalette.star.withValues(alpha: a)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.03;
      canvas.drawLine(p - Offset(size, 0), p + Offset(size, 0), paint);
      canvas.drawLine(p - Offset(0, size), p + Offset(0, size), paint);
    }

    star(Offset(s * 0.78, s * 0.26), s * 0.06, 0);
    star(Offset(s * 0.68, s * 0.6), s * 0.045, 2);
    star(Offset(s * 0.24, s * 0.72), s * 0.04, 4);
  }

  void _drawRain(
    Canvas canvas,
    double s,
    double t, {
    required int drops,
    required Color color,
    required double length,
    required double width,
    double speed = 4,
    double yStart = 0.62,
    double yEnd = 0.98,
  }) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * width;
    for (var i = 0; i < drops; i++) {
      final lane = (i + 0.5) / drops;
      final x = s * (0.24 + 0.52 * lane);
      final phase = (i * 0.37) % 1;
      final f = (t * speed + phase) % 1;
      final y = s * (yStart + (yEnd - yStart) * f);
      // Pudar masuk di bawah awan dan pudar keluar di hujung.
      final alpha = math.sin(f * math.pi).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: 0.35 + 0.65 * alpha);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - s * 0.035, y + s * length),
        paint,
      );
    }
  }

  void _drawBolt(Canvas canvas, double s, double t) {
    // Dua kilatan pantas dalam setiap kitaran 2 saat.
    final f = (t * 4) % 1;
    final flash = (f < 0.08)
        ? 1.0
        : (f > 0.16 && f < 0.24)
        ? 0.8
        : 0.0;
    final path = Path()
      ..moveTo(s * 0.56, s * 0.5)
      ..lineTo(s * 0.4, s * 0.76)
      ..lineTo(s * 0.51, s * 0.76)
      ..lineTo(s * 0.44, s * 0.98)
      ..lineTo(s * 0.68, s * 0.66)
      ..lineTo(s * 0.56, s * 0.66)
      ..lineTo(s * 0.64, s * 0.5)
      ..close();
    if (flash > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = WeatherPalette.bolt.withValues(alpha: 0.7 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = WeatherPalette.bolt.withValues(alpha: 0.78 + 0.22 * flash),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s * 0.018
        ..color = WeatherPalette.boltEdge,
    );
  }

  void _drawSnow(Canvas canvas, double s, double t) {
    final paint = Paint()..color = WeatherPalette.snow;
    for (var i = 0; i < 5; i++) {
      final lane = (i + 0.5) / 5;
      final f = (t * 2 + i * 0.23) % 1;
      final x =
          s * (0.24 + 0.52 * lane) +
          math.sin((t * 2 + i) * math.pi * 2) * s * 0.025;
      final y = s * (0.62 + 0.36 * f);
      final alpha = math.sin(f * math.pi).clamp(0.0, 1.0);
      paint.color = WeatherPalette.snow.withValues(alpha: 0.4 + 0.6 * alpha);
      canvas.drawCircle(Offset(x, y), s * (0.032 + 0.008 * (i % 2)), paint);
    }
  }

  void _drawFog(Canvas canvas, double s, double t) {
    for (var i = 0; i < 4; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final dx = math.sin(t * math.pi * 2 * 2 + i) * s * 0.05 * dir;
      final y = s * (0.3 + i * 0.16);
      final w = s * (i == 1 || i == 2 ? 0.7 : 0.54);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(s * 0.5 + dx, y),
          width: w,
          height: s * 0.075,
        ),
        Radius.circular(s * 0.04),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = WeatherPalette.fog.withValues(alpha: i == 0 ? 0.6 : 0.9),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final t = _progress.value;
    final drift = math.sin(t * math.pi * 2 * 2) * s * 0.035;

    switch (glyph) {
      case WeatherGlyph.clear:
        isDay
            ? _drawSun(canvas, Offset(s * 0.5, s * 0.5), s * 0.2, t)
            : _drawMoon(canvas, Offset(s * 0.48, s * 0.5), s * 0.26, t, s);
      case WeatherGlyph.mostlyClear:
      case WeatherGlyph.partlyCloudy:
        if (isDay) {
          _drawSun(canvas, Offset(s * 0.36, s * 0.38), s * 0.16, t);
        } else {
          _drawMoon(canvas, Offset(s * 0.38, s * 0.38), s * 0.2, t, s);
        }
        _drawCloud(
          canvas,
          Offset(s * 0.56 + drift, s * 0.6),
          s * (glyph == WeatherGlyph.mostlyClear ? 0.52 : 0.7),
        );
      case WeatherGlyph.overcast:
        _drawCloud(
          canvas,
          Offset(s * 0.38 - drift, s * 0.4),
          s * 0.5,
          top: WeatherPalette.stormTop,
          bottom: WeatherPalette.stormBottom,
          alpha: 0.95,
        );
        _drawCloud(canvas, Offset(s * 0.56 + drift, s * 0.6), s * 0.74);
      case WeatherGlyph.fog:
        _drawFog(canvas, s, t);
      case WeatherGlyph.drizzle:
        _drawCloud(canvas, Offset(s * 0.5 + drift * 0.5, s * 0.4), s * 0.74);
        _drawRain(
          canvas,
          s,
          t,
          drops: 3,
          color: WeatherPalette.rain,
          length: 0.07,
          width: 0.028,
          speed: 2,
        );
      case WeatherGlyph.rain:
        _drawCloud(
          canvas,
          Offset(s * 0.5 + drift * 0.5, s * 0.4),
          s * 0.78,
          top: const Color(0xFFD6E0EE),
          bottom: const Color(0xFF8798B2),
        );
        _drawRain(
          canvas,
          s,
          t,
          drops: 4,
          color: WeatherPalette.rain,
          length: 0.1,
          width: 0.035,
        );
      case WeatherGlyph.heavyRain:
        _drawCloud(
          canvas,
          Offset(s * 0.5 + drift * 0.5, s * 0.38),
          s * 0.8,
          top: WeatherPalette.stormTop,
          bottom: WeatherPalette.stormBottom,
        );
        _drawRain(
          canvas,
          s,
          t,
          drops: 6,
          color: WeatherPalette.heavyRain,
          length: 0.13,
          width: 0.04,
          speed: 8,
        );
      case WeatherGlyph.thunder:
        _drawCloud(
          canvas,
          Offset(s * 0.5, s * 0.36),
          s * 0.82,
          top: WeatherPalette.stormTop,
          bottom: WeatherPalette.stormBottom,
        );
        _drawBolt(canvas, s, t);
      case WeatherGlyph.snow:
        _drawCloud(canvas, Offset(s * 0.5 + drift * 0.5, s * 0.4), s * 0.74);
        _drawSnow(canvas, s, t);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WeatherIconPainter old) =>
      old.glyph != glyph || old.isDay != isDay;
}
