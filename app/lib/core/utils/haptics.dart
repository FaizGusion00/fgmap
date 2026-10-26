import 'package:flutter/services.dart';

/// Getaran sentuhan yang menghormati tetapan pengguna ("Getaran"). Satu pintu masuk supaya mematikan
/// getaran dalam Tetapan berkuat kuasa di seluruh app tanpa membawa `ref` ke setiap pemanggil.
///
/// [enabled] ditetapkan oleh `AppPreferencesController` apabila tetapan dimuat atau berubah.
abstract final class Haptics {
  static bool enabled = true;

  static Future<void> selection() =>
      enabled ? HapticFeedback.selectionClick() : Future.value();
  static Future<void> light() =>
      enabled ? HapticFeedback.lightImpact() : Future.value();
  static Future<void> medium() =>
      enabled ? HapticFeedback.mediumImpact() : Future.value();
  static Future<void> heavy() =>
      enabled ? HapticFeedback.heavyImpact() : Future.value();
}
