import 'assistant_message.dart';

/// Status muat turun / kehadiran model pada peranti.
enum AssistantModelStatus { missing, downloading, ready, error }

/// Enjin sembang tempatan (LiteRT atau palsu untuk ujian).
abstract class LocalLlmRuntime {
  /// Model sudah dipasang pada peranti.
  Future<bool> isInstalled();

  /// Muat turun model (kemajuan 0–1).
  Future<void> download({void Function(double progress)? onProgress});

  /// Padam model dari storan app.
  Future<void> delete();

  /// Muatkan model dan sesi lebih awal (semasa halaman AI dibuka) supaya mesej pertama pantas.
  Future<void> warmUp({required String system});

  /// Satu pusingan sembang dengan paling banyak [maxToolTurns] panggilan alat.
  ///
  /// [sessionKey] mengenal pasti perbualan: selagi sama, sesi model diteruskan dan [history] tidak
  /// dimasukkan semula. [onText] menerima teks jawapan terkumpul semasa ia dijana (untuk animasi
  /// menaip); teks giliran sebelum panggilan alat dibuang.
  Future<String> chat({
    required String system,
    required List<AssistantMessage> history,
    required String userText,
    required Future<Map<String, Object?>> Function(
      String name,
      Map<String, Object?> args,
    )
    onTool,
    int maxToolTurns = 2,
    String? sessionKey,
    void Function(String text)? onText,
  });

  /// Lepaskan sesi model dari RAM (fail kekal di storan).
  Future<void> release();
}
