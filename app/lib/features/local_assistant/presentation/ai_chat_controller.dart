import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/chat_history_store.dart';
import '../domain/assistant_message.dart';
import '../domain/intent_router.dart';
import '../domain/local_llm.dart';

/// Apa yang sedang dibuat AI (untuk penunjuk menaip).
enum AiPhase {
  idle,

  /// Model sedang dimuat ke RAM.
  preparing,

  /// Model menjana jawapan.
  thinking,

  /// Alat sedang berjalan (laluan, carian, cuaca...).
  working,

  /// FGMuslim: mencari dalam teks klasik.
  searching,
}

/// Keadaan satu halaman AI (FG AI atau FGMuslim): senarai perbualan + perbualan semasa.
@immutable
class AssistantUiState {
  const AssistantUiState({
    this.modelStatus = AssistantModelStatus.missing,
    this.downloadProgress = 0,
    this.conversations = const [],
    this.current,
    this.messages = const [],
    this.busy = false,
    this.phase = AiPhase.idle,
    this.streamingText,
    this.freshAt,
    this.error,
  });

  final AssistantModelStatus modelStatus;
  final double downloadProgress;
  final List<ConversationMeta> conversations;

  /// Null = sembang baharu yang belum ada mesej.
  final ConversationMeta? current;
  final List<AssistantMessage> messages;
  final bool busy;
  final AiPhase phase;

  /// Teks jawapan yang sedang dijana (dipaparkan secara langsung dengan kursor).
  final String? streamingText;

  /// Cap masa jawapan terbaharu yang perlu dianimasi (taip) sekali.
  final DateTime? freshAt;
  final String? error;

  bool get modelReady => modelStatus == AssistantModelStatus.ready;

  AssistantUiState copyWith({
    AssistantModelStatus? modelStatus,
    double? downloadProgress,
    List<ConversationMeta>? conversations,
    ConversationMeta? current,
    bool clearCurrent = false,
    List<AssistantMessage>? messages,
    bool? busy,
    AiPhase? phase,
    String? streamingText,
    bool clearStreaming = false,
    DateTime? freshAt,
    String? error,
    bool clearError = false,
  }) => AssistantUiState(
    modelStatus: modelStatus ?? this.modelStatus,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    conversations: conversations ?? this.conversations,
    current: clearCurrent ? null : (current ?? this.current),
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    phase: phase ?? this.phase,
    streamingText: clearStreaming
        ? null
        : (streamingText ?? this.streamingText),
    freshAt: freshAt ?? this.freshAt,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Asas bersama dua AI: CRUD perbualan (seperti ChatGPT) yang disimpan pada peranti.
abstract class AiChatController extends Notifier<AssistantUiState> {
  AiMode get mode;

  ConversationStore get store => ref.read(conversationStoreProvider(mode));

  /// Keadaan awal: perbualan aktif terakhir dibuka semula.
  AssistantUiState initialState() {
    final s = ref.read(conversationStoreProvider(mode));
    final list = s.list();
    final active = list.where((c) => c.id == s.activeId).firstOrNull;
    return AssistantUiState(
      conversations: list,
      current: active,
      messages: active == null ? const [] : s.messages(active.id),
    );
  }

  /// Dipanggil bila perbualan bertukar (cth. supaya sesi model dimulakan semula).
  @protected
  void onConversationChanged() {}

  void newConversation() {
    if (state.busy) return;
    state = state.copyWith(
      clearCurrent: true,
      messages: const [],
      clearStreaming: true,
      clearError: true,
    );
    unawaited(store.setActive(null));
    onConversationChanged();
  }

  void openConversation(String id) {
    if (state.busy || state.current?.id == id) return;
    final meta = state.conversations.where((c) => c.id == id).firstOrNull;
    if (meta == null) return;
    state = state.copyWith(
      current: meta,
      messages: store.messages(id),
      clearStreaming: true,
      clearError: true,
    );
    unawaited(store.setActive(id));
    onConversationChanged();
  }

  Future<void> renameConversation(String id, String title) async {
    final renamed = await store.rename(id, title);
    if (!ref.mounted || renamed == null) return;
    state = state.copyWith(
      conversations: store.list(),
      current: state.current?.id == id ? renamed : null,
    );
  }

  /// Padam; pulangkan data untuk "Buat asal".
  Future<({ConversationMeta meta, List<AssistantMessage> messages})?>
  deleteConversation(String id) async {
    if (state.busy && state.current?.id == id) return null;
    final meta = state.conversations.where((c) => c.id == id).firstOrNull;
    if (meta == null) return null;
    final removed = await store.delete(id);
    if (!ref.mounted) return null;
    final wasCurrent = state.current?.id == id;
    state = state.copyWith(
      conversations: store.list(),
      clearCurrent: wasCurrent,
      messages: wasCurrent ? const [] : null,
    );
    if (wasCurrent) onConversationChanged();
    return (meta: meta, messages: removed);
  }

  Future<void> restoreConversation(
    ConversationMeta meta,
    List<AssistantMessage> messages,
  ) async {
    await store.save(meta, messages);
    if (!ref.mounted) return;
    state = state.copyWith(conversations: store.list());
  }

  Future<void> deleteAllConversations() async {
    if (state.busy) return;
    await store.deleteAll();
    if (!ref.mounted) return;
    state = state.copyWith(
      conversations: const [],
      clearCurrent: true,
      messages: const [],
      clearStreaming: true,
      clearError: true,
    );
    onConversationChanged();
  }

  /// Simpan mesej ke perbualan semasa (dicipta pada mesej pertama).
  @protected
  Future<void> persist(List<AssistantMessage> messages) async {
    final meta = state.current ?? store.create();
    final saved = await store.save(meta, messages);
    await store.setActive(saved.id);
    if (!ref.mounted) return;
    state = state.copyWith(current: saved, conversations: store.list());
  }

  @protected
  AssistantMessage userMessage(String text) => AssistantMessage(
    role: AssistantRole.user,
    text: text,
    at: DateTime.now(),
  );

  /// Bahasa jawapan: bahasa mesej jika jelas, jika tidak bahasa UI.
  @protected
  AppLocalizations replyL10n(String text, {required bool uiMalay}) {
    final malay = replyIsMalay(text, uiMalay: uiMalay);
    return lookupAppLocalizations(Locale(malay ? 'ms' : 'en'));
  }
}
