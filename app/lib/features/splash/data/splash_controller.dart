import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Splash animasi sudah selesai pada sesi ini. Sengaja BUKAN disimpan: ia dipaparkan setiap kali app
/// dibuka dari awal (seperti splash app lain), tetapi tidak semasa navigasi dalam app.
///
/// Juga bila perjalanan disimpan sedang dipulihkan: dahulu splash dilangkau terus, jadi pemilik yang
/// menguji navigasi tidak pernah melihat animasi logo. Kini versi pantas dimainkan (lihat SplashPage).
class SplashController extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashController, bool>(
  SplashController.new,
);
