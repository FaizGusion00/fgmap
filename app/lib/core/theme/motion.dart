import 'package:flutter/material.dart';

/// Token gerakan (Bahagian 14.2 pelan): satu set tempoh dan lengkung untuk seluruh app.
abstract final class Motion {
  /// Maklum balas sentuhan, toggle kecil.
  static const fast = Duration(milliseconds: 150);

  /// Peralihan biasa: lembaran, chip, kad.
  static const normal = Duration(milliseconds: 250);

  /// Tukar tema cerah/gelap (Bahagian 14.6).
  static const themeSwitch = Duration(milliseconds: 300);

  /// Momen istimewa sahaja (400-600 ms).
  static const emphasized = Duration(milliseconds: 500);

  /// Lengkung lalai: mula pantas, mendarat lembut.
  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;

  /// Spring untuk lembaran dan elemen yang "ditarik".
  static const spring = SpringDescription(mass: 1, stiffness: 320, damping: 30);

  /// Tempoh yang menghormati tetapan "Reduce Motion" sistem: sifar jika dimatikan.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
