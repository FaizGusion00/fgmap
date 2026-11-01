import 'package:flutter/widgets.dart';
import '../../../../core/settings/device_tier.dart';

/// Animasi sembang AI (titik menaip, kilauan, kursor, pendedahan teks) TIDAK mengikut
/// `MediaQuery.disableAnimations`.
///
/// Banyak telefon Android (mod jimat bateri HyperOS/MIUI, "skala animasi" dimatikan) melaporkan
/// animasi dimatikan walaupun pengguna tidak meminta Kurangkan Gerakan. Akibatnya penunjuk AI
/// membeku pada satu bingkai dan kelihatan tersekat, jadi pengguna tidak tahu app masih bekerja.
/// Animasi ini kecil dan setempat (tiada skrin bergerak atau zum), jadi ia dikekalkan. Peralihan
/// skrin dan gerakan besar lain masih mengikut tetapan sistem ([Motion]).
abstract final class AiMotion {
  /// Ujian: bekukan animasi sembang AI supaya `pumpAndSettle` boleh selesai.
  @visibleForTesting
  static bool forceStatic = false;

  /// Mod Lite (telefon lemah): animasi AI statik dan teks terus dipaparkan.
  static bool reduce(BuildContext context) => forceStatic || LiteMode.enabled;
}
