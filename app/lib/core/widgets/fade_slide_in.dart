import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Masuk berperingkat (Bahagian 14.3): kandungan memudar masuk sambil naik sedikit, dengan
/// kelewatan mengikut [index] supaya senarai "mekar" dari atas ke bawah. Hanya dimainkan apabila
/// widget mula-mula dipasang (kekunci stabil pada item senarai); Reduce Motion: terus kelihatan.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 35),
    this.maxIndex = 8,
    this.offset = 14,
  });

  final Widget child;

  /// Kedudukan dalam senarai; kelewatan = index x [step], dihad pada [maxIndex] supaya item jauh di
  /// bawah tidak menunggu lama.
  final int index;
  final Duration step;
  final int maxIndex;

  /// Jarak naik (px) semasa masuk.
  final double offset;

  @override
  Widget build(BuildContext context) {
    final base = Motion.of(context, Motion.normal);
    if (base == Duration.zero) return child;
    final delay = step * index.clamp(0, maxIndex);
    final total = base + delay;
    final begin = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(begin, 1, curve: Motion.enter),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
