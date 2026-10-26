import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Peralihan skrin penuh: pudar masuk sambil naik sedikit (seragam di Android dan iOS), pudar keluar
/// semasa kembali. Reduce Motion: serta-merta.
Route<T> fadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionDuration: Motion.normal,
    reverseTransitionDuration: Motion.fast,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.enter,
        reverseCurve: Motion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
