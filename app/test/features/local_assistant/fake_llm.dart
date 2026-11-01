import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_models.dart';
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

  /// Model yang dimuat turun (nama fail). [installed] = model lalai ada.
  late final Set<String> models = {if (installed) defaultAiModel.id};
  String selected = defaultAiModel.id;
  final List<String> downloads = [];

  @override
  String get selectedModelId => selected;

  @override
  Future<void> selectModel(String id) async => selected = id;

  @override
  Future<Set<String>> installedModelIds() async => {...models};

  @override
  Future<bool> isInstalled() async => models.contains(selected);

  @override
  Future<void> download({
    String? id,
    void Function(double progress)? onProgress,
  }) async {
    final target = id ?? selected;
    downloads.add(target);
    onProgress?.call(1);
    models.add(target);
    selected = target;
  }

  @override
  Future<void> delete({String? id}) async => models.remove(id ?? selected);

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
