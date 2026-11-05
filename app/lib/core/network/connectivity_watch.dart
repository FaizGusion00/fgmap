import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status pautan rangkaian semasa (benar = ada sekurang-kurangnya satu pautan). Berubah apabila sistem
/// melaporkan perubahan (mod pesawat, keluar/masuk liputan). Ralat plugin -> dianggap dalam talian
/// (jangan menyekat pengguna). Lihat [onlineProbeProvider] untuk semakan sekali.
final onlineStatusProvider = StreamProvider<bool>((ref) async* {
  bool online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  final c = Connectivity();
  try {
    yield online(await c.checkConnectivity());
  } on Object {
    yield true;
    return;
  }
  try {
    await for (final r in c.onConnectivityChanged) {
      yield online(r);
    }
  } on Object {
    // Plugin tiada (ujian/desktop): kekal pada nilai terakhir.
  }
});
