import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Splash animasi sudah selesai pada sesi ini. Sengaja BUKAN disimpan: ia dipaparkan setiap kali app
/// dibuka dari awal (seperti splash app lain), tetapi tidak semasa navigasi dalam app.
class SplashController extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashController, bool>(
  SplashController.new,
);
