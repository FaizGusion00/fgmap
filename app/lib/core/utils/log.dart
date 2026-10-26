import 'package:flutter/foundation.dart';

final _url = RegExp(r'https?://\S+');
final _longDecimal = RegExp(r'-?\d{1,3}\.\d{3,}');

/// Membuang URL (boleh membawa koordinat dalam laluan/pertanyaan) dan nombor perpuluhan panjang
/// (koordinat) daripada teks log.
String redactForLog(String message) =>
    message.replaceAll(_url, '<url>').replaceAll(_longDecimal, '<n>');

/// Log diagnostik. `debugPrint` mencetak ke logcat/konsol walaupun dalam build release, jadi semua log
/// aplikasi melalui fungsi ini: senyap dalam release, dan dalam debug URL serta koordinat dibuang
/// supaya lokasi pengguna tidak bocor melalui ralat rangkaian (cth. `DioException` membawa URL penuh).
void logDiag(String message) {
  if (!kDebugMode) return;
  debugPrint(redactForLog(message));
}
