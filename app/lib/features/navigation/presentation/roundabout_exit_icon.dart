import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/typography.dart';

/// Ikon bulatan yang boleh dibaca sekilas: satu gelang jalan yang tebal, satu tangkai pendek di
/// bawah (jalan masuk) dan nombor simpang keluar yang besar di tengah. Tiada anak panah yang
/// berpintal: pemandu yang lemah membaca peta hanya perlu tahu "bulatan, keluar nombor N".
///
/// [exit] null atau 0 = gelang sahaja (masuk bulatan tanpa nombor).
class RoundaboutExitIcon extends StatelessWidget {
  const RoundaboutExitIcon({
    super.key,
    required this.exit,
    required this.size,
    required this.color,
    this.semanticsLabel,
  });

  final int? exit;
  final double size;
  final Color color;

  /// Label untuk pembaca skrin; ikon itu sendiri dikecualikan daripada semantik.
  final String? semanticsLabel;

  bool get _hasExit => exit != null && exit! > 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Nod sendiri supaya TalkBack menyebut "Bulatan, keluar 2" sebagai satu unit, bukan digabung
      // dengan jarak yang berubah setiap saat.
      container: semanticsLabel != null,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoundaboutPainter(color: color, withStem: true),
              ),
            ),
            if (_hasExit)
              // Nombor sedikit ke atas supaya berada di tengah gelang (bukan tengah kotak yang
              // termasuk tangkai di bawah).
              Align(
                alignment: const Alignment(0, -0.18),
                child: Text(
                  '$exit',
                  // Tanpa penskalaan teks sistem: saiz ikut ikon, bukan tetapan fon.
                  textScaler: TextScaler.noScaling,
                  style: FgTypography.metricLarge.copyWith(
                    color: color,
                    fontSize: size * 0.46,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundaboutPainter extends CustomPainter {
  const _RoundaboutPainter({required this.color, required this.withStem});

  final Color color;
  final bool withStem;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s * 0.13;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height * 0.44);
    final radius = s * 0.30;
    canvas.drawCircle(center, radius, paint);

    if (withStem) {
      // Jalan masuk: dari tepi bawah naik ke gelang.
      final bottom = Offset(size.width / 2, size.height - stroke / 2);
      final top = Offset(size.width / 2, center.dy + radius);
      if (bottom.dy > top.dy) canvas.drawLine(bottom, top, paint);
    }
  }

  @override
  bool shouldRepaint(_RoundaboutPainter old) =>
      old.color != color || old.withStem != withStem;
}
