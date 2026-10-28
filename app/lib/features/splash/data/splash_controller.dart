import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/data/trip_store.dart';

/// Splash animasi sudah selesai pada sesi ini. Sengaja BUKAN disimpan: ia dipaparkan setiap kali app
/// dibuka dari awal (seperti splash app lain), tetapi tidak semasa navigasi dalam app.
class SplashController extends Notifier<bool> {
  @override
  bool build() {
    // Perjalanan yang disimpan dibuka terus pada peta, tanpa splash yang menunda pemulihan.
    // `read` (bukan watch): menamatkan perjalanan tidak boleh memaparkan splash semula.
    return ref.read(tripStoreProvider).read() != null;
  }

  void complete() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashController, bool>(
  SplashController.new,
);
