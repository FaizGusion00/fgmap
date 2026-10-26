import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Klien Dio tunggal. Sengaja tiada LogInterceptor: badan permintaan laluan mengandungi koordinat
/// lokasi pengguna dan tidak boleh sampai ke log peranti.
///
/// User-Agent mengenal pasti app: dasar penggunaan wajar OSM/FOSSGIS memerlukan pelanggan yang
/// boleh dikenali dan dihubungi, dan pelanggan tanpa UA lazimnya disekat dahulu.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'User-Agent': AppConfig.userAgent,
      },
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
