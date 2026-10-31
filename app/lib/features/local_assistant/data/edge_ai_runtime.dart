import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../domain/assistant_message.dart';
import '../domain/assistant_tools.dart';
import '../domain/local_llm.dart';

/// Runtime sebenar melalui flutter_edge_ai + LiteRT-LM.
class EdgeAiLlmRuntime implements LocalLlmRuntime {
  InferenceModel? _model;
  InferenceChat? _chat;

  @override
  Future<bool> isInstalled() =>
      FlutterEdgeAi.isModelInstalled(assistantModelId);

  @override
  Future<void> download({void Function(double progress)? onProgress}) async {
    await FlutterEdgeAi.installModel(
          modelType: ModelType.qwen3,
          fileType: ModelFileType.litertlm,
        )
        .fromNetwork(assistantModelUrl)
        .withProgress((p) => onProgress?.call((p / 100.0).clamp(0.0, 1.0)))
        .install();
  }

  @override
  Future<void> delete() async {
    await release();
    if (await isInstalled()) {
      await FlutterEdgeAi.uninstallModel(assistantModelId);
    }
  }

  Future<InferenceChat> _ensureChat(String system) async {
    final existing = _chat;
    if (existing != null) return existing;
    final model = await FlutterEdgeAi.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.cpu,
    );
    _model = model;
    final chat = await model.createChat(
      temperature: 0.4,
      topK: 40,
      topP: 0.9,
      maxOutputTokens: 512,
      tools: assistantTools(),
      supportsFunctionCalls: true,
      enableThinking: false,
      modelType: ModelType.qwen3,
      toolChoice: ToolChoice.auto,
      systemInstruction: system,
    );
    _chat = chat;
    return chat;
  }

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
  }) async {
    final chat = await _ensureChat(system);
    // Sejarah pendek: hanya beberapa pusingan terakhir (elak konteks penuh).
    final recent = history.length <= 6
        ? history
        : history.sublist(history.length - 6);
    await chat.clearHistory();
    for (final m in recent) {
      if (m.role == AssistantRole.user) {
        await chat.addQueryChunk(Message.text(text: m.text, isUser: true));
      } else if (m.role == AssistantRole.assistant) {
        await chat.addQueryChunk(Message.text(text: m.text, isUser: false));
      }
    }
    await chat.addQueryChunk(Message.text(text: userText, isUser: true));

    final buf = StringBuffer();
    await for (final response in chat.generateChatResponseWithTools(
      maxToolTurns: maxToolTurns,
      onToolCall: (call) async {
        if (!isKnownAssistantTool(call.name)) {
          return {'error': 'unknown_tool'};
        }
        final args = <String, Object?>{
          for (final e in call.args.entries) e.key: e.value,
        };
        final result = await onTool(call.name, args);
        return result;
      },
    )) {
      if (response is TextResponse) {
        buf.write(response.token);
      }
    }
    return buf.toString().trim();
  }

  @override
  Future<void> release() async {
    _chat = null;
    final model = _model;
    _model = null;
    if (model != null && !model.isClosed) {
      await model.close();
    }
  }
}
