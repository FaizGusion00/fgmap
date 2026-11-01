import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Penunjuk "sedang menaip": tiga titik beralun dan label status bersinar (shimmer).
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.color, this.label});

  final Color color;

  /// Cth. "Sedang berfikir…", "Mencari dalam teks klasik…".
  final String? label;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
    final label = widget.label;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = reduce ? 0.0 : _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              _dot(t, i),
            ],
            if (label != null) ...[
              const SizedBox(width: 12),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(-1.6 + t * 3.2 - 0.6, 0),
                  end: Alignment(-1.6 + t * 3.2 + 0.6, 0),
                  colors: [
                    theme.colorScheme.onSurfaceVariant,
                    widget.color,
                    theme.colorScheme.onSurfaceVariant,
                  ],
                ).createShader(rect),
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(double t, int i) {
    // Gelombang: setiap titik naik dan menjadi terang mengikut fasa masing-masing.
    final phase = (t - i * 0.16) * 2 * math.pi;
    final wave = (math.sin(phase) + 1) / 2;
    return Transform.translate(
      offset: Offset(0, -4 * wave),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.35 + 0.65 * wave),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
