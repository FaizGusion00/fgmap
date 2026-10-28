import 'package:flutter/foundation.dart';

/// Data gelembung kelajuan (telefon dan skrin kereta): km/j, dan papan had hanya jika had diketahui.
@immutable
class SpeedBubbleData {
  const SpeedBubbleData({
    required this.speedMps,
    this.limitKmh,
    this.overspeed = false,
  });

  final double speedMps;
  final int? limitKmh;
  final bool overspeed;

  int get kmh => (speedMps * 3.6).round();

  /// Papan had dilukis hanya apabila carian memulangkan had.
  bool get showLimit => limitKmh != null && limitKmh! > 0;
}
