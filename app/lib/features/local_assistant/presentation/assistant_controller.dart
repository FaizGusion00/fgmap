import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_history_store.dart';
import '../data/edge_ai_runtime.dart';
import '../data/tool_executor.dart';
import '../domain/assistant_message.dart';
import '../domain/assistant_tools.dart';
import '../domain/local_llm.dart';

@immutable
class AssistantUiState {
  const AssistantUiState({
    this.modelStatus = AssistantModelStatus.missing,
    this.downloadProgress = 0,
    this.messages = const [],
    this.busy = false,
    this.error,
  });

  final AssistantModelStatus modelStatus;
  final double downloadProgress;
  final List<AssistantMessage> messages;
  final bool busy;
  final String? error;

  bool get modelReady => modelStatus == AssistantModelStatus.ready;

  AssistantUiState copyWith({
    AssistantModelStatus? modelStatus,
    double? downloadProgress,
    List<AssistantMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => AssistantUiState(
    modelStatus: modelStatus ?? this.modelStatus,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

final localLlmRuntimeProvider = Provider<LocalLlmRuntime>(
  (ref) => EdgeAiLlmRuntime(),
);

class AssistantController extends Notifier<AssistantUiState> {
  @override
  AssistantUiState build() {
    final history = ref.watch(chatHistoryStoreProvider).load();
    final runtime = ref.read(localLlmRuntimeProvider);
    ref.onDispose(() {
      unawaited(runtime.release());
    });
    Future.microtask(_refreshInstalled);
    return AssistantUiState(messages: history);
  }

  Future<void> _refreshInstalled() async {
    try {
      final ok = await ref.read(localLlmRuntimeProvider).isInstalled();
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: ok
            ? AssistantModelStatus.ready
            : AssistantModelStatus.missing,
        clearError: true,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: AssistantModelStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> downloadModel() async {
    state = state.copyWith(
      modelStatus: AssistantModelStatus.downloading,
      downloadProgress: 0,
      clearError: true,
    );
    try {
      await ref
          .read(localLlmRuntimeProvider)
          .download(
            onProgress: (p) {
              if (!ref.mounted) return;
              state = state.copyWith(downloadProgress: p);
            },
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: AssistantModelStatus.ready,
        downloadProgress: 1,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: AssistantModelStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteModel() async {
    try {
      await ref.read(localLlmRuntimeProvider).delete();
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: AssistantModelStatus.missing,
        downloadProgress: 0,
        clearError: true,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> clearChat() async {
    await ref.read(chatHistoryStoreProvider).clear();
    if (!ref.mounted) return;
    state = state.copyWith(messages: const [], clearError: true);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy || !state.modelReady) return;
    final user = AssistantMessage(
      role: AssistantRole.user,
      text: trimmed,
      at: DateTime.now(),
    );
    final prior = [
      for (final m in state.messages)
        if (m.role != AssistantRole.system) m,
    ];
    final next = [...prior, user];
    state = state.copyWith(messages: next, busy: true, clearError: true);
    await ref.read(chatHistoryStoreProvider).save(next);

    try {
      final reply = await ref
          .read(localLlmRuntimeProvider)
          .chat(
            system: assistantSystemPrompt,
            history: prior,
            userText: trimmed,
            maxToolTurns: 2,
            onTool: (name, args) =>
                ref.read(assistantToolExecutorProvider).run(name, args),
          );
      if (!ref.mounted) return;
      final body = reply.trim().isEmpty ? '…' : reply.trim();
      final assistant = AssistantMessage(
        role: AssistantRole.assistant,
        text: body.length > 2000 ? '${body.substring(0, 1999)}…' : body,
        at: DateTime.now(),
      );
      final all = [...state.messages, assistant];
      state = state.copyWith(messages: all, busy: false);
      await ref.read(chatHistoryStoreProvider).save(all);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  Future<void> releaseModel() => ref.read(localLlmRuntimeProvider).release();
}

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantUiState>(
      AssistantController.new,
    );
