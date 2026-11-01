import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Penunjuk "sedang berfikir": label bersinar (shimmer) dengan tiga titik beralun, dan di bawahnya
/// garis rangka jawapan yang berkilau, jadi ruang jawapan terasa "hidup" dan sedang terbentuk,
/// bukan sekadar tiga titik. Dengan Reduce Motion, semuanya statik.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.color, this.label});

  final Color color;

  /// Cth. "Sedang berfikir…", "Mencari dalam teks klasik…". Elipsis di hujung diganti titik beralun.
  final String? label;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: statik (dan pumpAndSettle dalam ujian boleh selesai).
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final raw = widget.label?.replaceFirst(RegExp(r'[….]+$'), '');
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = reduce ? 0.0 : _c.value;
          // Sapuan bersinar dari kiri ke kanan (-1 hingga +1 kali lebar).
          final slide = -1 + 2 * t;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (raw != null)
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (rect) => _sweep(
                        base: muted,
                        glow: widget.color,
                        slide: reduce ? 0 : slide,
                        width: 0.45,
                      ).createShader(rect),
                      child: Text(
                        raw,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  SizedBox(width: raw == null ? 0 : 3),
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _dot(t, i),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => _sweep(
                  base: widget.color.withValues(alpha: 0.10),
                  glow: widget.color.withValues(alpha: 0.32),
                  slide: reduce ? 0 : slide,
                  width: 0.3,
                ).createShader(rect),
                child: const _GhostLines(),
              ),
            ],
          );
        },
      ),
    );
  }

  static LinearGradient _sweep({
    required Color base,
    required Color glow,
    required double slide,
    required double width,
  }) {
    final half = width / 2;
    return LinearGradient(
      colors: [base, glow, base],
      stops: [0.5 - half, 0.5, 0.5 + half],
      transform: _Slide(slide),
    );
  }

  Widget _dot(double t, int i) {
    // Gelombang sinus: setiap titik membesar dan terang mengikut fasa masing-masing (2 kitaran
    // setiap gelung supaya sambungan gelung tidak kelihatan).
    final phase = (t * 2 - i * 0.16) * 2 * math.pi;
    final wave = (math.sin(phase) + 1) / 2;
    return Transform.scale(
      scale: 0.62 + 0.38 * wave,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.35 + 0.65 * wave),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Anjakan kecerunan secara mendatar: [percent] -1..1 daripada lebar kawasan lukis.
class _Slide extends GradientTransform {
  const _Slide(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

/// Tiga garis jawapan hantu (putih penuh; warna sebenar datang daripada ShaderMask).
class _GhostLines extends StatelessWidget {
  const _GhostLines();

  @override
  Widget build(BuildContext context) {
    Widget bar(double factor) => FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bar(1),
        const SizedBox(height: 8),
        bar(0.82),
        const SizedBox(height: 8),
        bar(0.48),
      ],
    );
  }
}
