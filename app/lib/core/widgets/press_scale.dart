import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Tindak balas tekan (Bahagian 14.3): kandungan mengecil sedikit (0.97) semasa disentuh.
///
/// Menggunakan [Listener] sahaja, jadi ketukan, tekan lama dan semantik anak tidak terjejas. Dengan
/// Reduce Motion, tiada animasi.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.fast);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && duration != Duration.zero ? widget.scale : 1,
        duration: duration,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}
