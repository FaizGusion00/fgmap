import 'package:flutter/widgets.dart';

/// Mod mudah untuk pemandu yang lemah membaca peta dan warga emas: HUD lebih besar, kontras lebih
/// tinggi, kawalan sekunder disembunyikan. Disebarkan sebagai InheritedWidget supaya widget HUD
/// (yang tiada `ref`) dan ujian yang memasang widget secara berasingan (lalai: mati) tidak berubah.
class EasyModeScope extends InheritedWidget {
  const EasyModeScope({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EasyModeScope>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(EasyModeScope old) => old.enabled != enabled;
}
