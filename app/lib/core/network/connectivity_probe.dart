import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Benar jika peranti mempunyai SEKURANG-KURANGNYA satu pautan rangkaian (Wi-Fi, data mudah alih, ethernet, VPN).
/// Salah hanya bila sistem melaporkan tiada pautan langsung (mod pesawat / tiada isyarat). Ia tidak membuktikan
/// internet berfungsi, tetapi cukup untuk membezakan "luar talian" sebenar daripada pelayan yang sibuk atau lambat.
/// Provider supaya ujian boleh menggantikannya. Jika semakan gagal, anggap dalam talian (jangan menyekat pengguna).
final onlineProbeProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } on Object {
      return true;
    }
  };
});
