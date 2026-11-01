import 'assistant_message.dart';

/// Status muat turun / kehadiran model pada peranti.
enum AssistantModelStatus { missing, downloading, ready, error }

/// Enjin sembang tempatan (LiteRT atau palsu untuk ujian).
abstract class LocalLlmRuntime {
  /// Model yang dipilih untuk digunakan (nama fail, lihat `aiModelOptions`). Satu sahaja pada satu masa.
  String get selectedModelId;

  /// Tukar model yang digunakan. Model semasa dilepaskan dari RAM; fail kekal pada storan.
  Future<void> selectModel(String id);

  /// Model yang sudah dimuat turun pada peranti.
  Future<Set<String>> installedModelIds();

  /// Model yang DIPILIH sudah dipasang pada peranti.
  Future<bool> isInstalled();

  /// Muat turun model [id] (lalai: yang dipilih) dan jadikannya model yang digunakan (kemajuan 0–1).
  Future<void> download({
    String? id,
    void Function(double progress)? onProgress,
  });

  /// Padam model [id] (lalai: yang dipilih) dari storan app.
  Future<void> delete({String? id});

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
