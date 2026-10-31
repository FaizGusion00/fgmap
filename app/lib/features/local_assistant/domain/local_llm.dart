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

  /// Satu pusingan sembang dengan paling banyak [maxToolTurns] panggilan alat.
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
  });

  /// Lepaskan sesi model dari RAM (fail kekal di storan).
  Future<void> release();
}
