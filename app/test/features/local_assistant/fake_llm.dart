import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:fgmap/features/local_assistant/domain/local_llm.dart';

/// Model palsu untuk ujian: jawapan tetap, merekod mesej terakhir, boleh mengalirkan teks.
class FakeLlm implements LocalLlmRuntime {
  FakeLlm({this.installed = true, this.reply = ''});

  bool installed;
  String reply;
  String? lastUserText;
  String? lastSessionKey;
  List<AssistantMessage> lastHistory = const [];
  int warmUps = 0;

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<void> download({void Function(double progress)? onProgress}) async {
    onProgress?.call(1);
    installed = true;
  }

  @override
  Future<void> delete() async => installed = false;

  @override
  Future<void> warmUp({required String system}) async => warmUps++;

  @override
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
  }) async {
    lastUserText = userText;
    lastSessionKey = sessionKey;
    lastHistory = history;
    onText?.call(reply);
    return reply;
  }

  @override
  Future<void> release() async {}
}
