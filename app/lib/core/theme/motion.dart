import 'dart:math' as math;

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

  /// Lengkung "spring" tanpa lajak (redaman kritikal) untuk lembaran bawah: bermula pantas dan
  /// mendarat lembut seperti pegas, tetapi tidak melepasi kedudukan akhir (lembaran terlekat di tepi
  /// bawah tidak boleh terangkat dan mendedahkan jurang).
  static const Curve sheet = SpringCurve();

  /// Tempoh yang menghormati tetapan "Reduce Motion" sistem: sifar jika dimatikan.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

/// Lengkung daripada simulasi pegas redaman kritikal, dinormalisasi supaya t=0 -> 0 dan t=1 -> 1.
///
/// Penyelesaian tertutup: x(t) = 1 - (1 + w t)(e^{-w t}) dengan w ialah frekuensi semula jadi. Pada t=1
/// nilainya hampir tetapi bukan tepat 1, jadi dibahagi dengan x(1).
class SpringCurve extends Curve {
  const SpringCurve({this.omega = 9});

  /// Frekuensi sudut (lebih besar = lebih pantas mendarat dalam tempoh yang sama).
  final double omega;

  double _x(double t) => 1 - (1 + omega * t) * math.exp(-omega * t);

  @override
  double transformInternal(double t) => _x(t) / _x(1);
}
