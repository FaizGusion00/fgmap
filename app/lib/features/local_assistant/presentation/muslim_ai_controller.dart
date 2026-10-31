import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_history_store.dart';
import '../data/deen_fatwa_client.dart';
import '../data/islamic_app_client.dart';
import '../data/muslim_ai_settings.dart';
import '../domain/assistant_message.dart';

@immutable
class MuslimAiUiState {
  const MuslimAiUiState({
    this.messages = const [],
    this.busy = false,
    this.error,
    this.lastLibrarySources = const [],
    this.lastFatwaHits = const [],
  });

  final List<AssistantMessage> messages;
  final bool busy;
  final String? error;
  final List<IslamicAppSource> lastLibrarySources;
  final List<DeenFatwaHit> lastFatwaHits;

  /// Alias lama untuk UI yang masih guna `lastHits`.
  List<DeenFatwaHit> get lastHits => lastFatwaHits;

  MuslimAiUiState copyWith({
    List<AssistantMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
    List<IslamicAppSource>? lastLibrarySources,
    List<DeenFatwaHit>? lastFatwaHits,
  }) => MuslimAiUiState(
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    lastLibrarySources: lastLibrarySources ?? this.lastLibrarySources,
    lastFatwaHits: lastFatwaHits ?? this.lastFatwaHits,
  );
}

class MuslimAiController extends Notifier<MuslimAiUiState> {
  CancelToken? _cancel;

  @override
  MuslimAiUiState build() {
    ref.onDispose(() => _cancel?.cancel());
    final history = ref.watch(muslimChatHistoryStoreProvider).load();
    return MuslimAiUiState(messages: history);
  }

  Future<void> clearChat() async {
    await ref.read(muslimChatHistoryStoreProvider).clear();
    if (!ref.mounted) return;
    state = state.copyWith(
      messages: const [],
      lastLibrarySources: const [],
      lastFatwaHits: const [],
      clearError: true,
    );
  }

  /// Utama: islamic.app RAG berpetikan. Sandaran: carian fatwa deen.ai.
  Future<void> send(String text, {required bool malay}) async {
    final settings = ref.read(muslimAiSettingsProvider);
    if (!settings.isActive) {
      state = state.copyWith(error: 'not_enabled');
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    final user = AssistantMessage(
      role: AssistantRole.user,
      text: trimmed,
      at: DateTime.now(),
    );
    final next = [...state.messages, user];
    state = state.copyWith(
      messages: next,
      busy: true,
      clearError: true,
      lastLibrarySources: const [],
      lastFatwaHits: const [],
    );
    await ref.read(muslimChatHistoryStoreProvider).save(next);

    _cancel?.cancel();
    _cancel = CancelToken();

    IslamicAppAnswer? library;
    Object? libraryError;
    try {
      library = await ref
          .read(islamicAppClientProvider)
          .ask(trimmed, cancel: _cancel);
    } on IslamicAppRateLimitException catch (e) {
      libraryError = e;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      libraryError = e;
    } on Object catch (e) {
      libraryError = e;
    }
    if (!ref.mounted) return;

    List<DeenFatwaHit> fatwaHits = const [];
    try {
      fatwaHits = await ref
          .read(deenFatwaClientProvider)
          .search(trimmed, cancel: _cancel);
      fatwaHits = fatwaHits.take(3).toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      // Sandaran gagal — teruskan dengan jawapan library jika ada.
    } on Object {
      // abaikan
    }
    if (!ref.mounted) return;

    final replyText = _composeReply(
      malay: malay,
      library: library,
      libraryError: libraryError,
      fatwaHits: fatwaHits,
    );

    final reply = AssistantMessage(
      role: AssistantRole.assistant,
      text: replyText,
      at: DateTime.now(),
    );
    final all = [...state.messages, reply];
    state = state.copyWith(
      messages: all,
      busy: false,
      lastLibrarySources: library?.sources ?? const [],
      lastFatwaHits: fatwaHits,
      error: library == null && fatwaHits.isEmpty && libraryError != null
          ? libraryError.toString()
          : null,
      clearError: library != null || fatwaHits.isNotEmpty,
    );
    await ref.read(muslimChatHistoryStoreProvider).save(all);
  }

  static String _composeReply({
    required bool malay,
    required IslamicAppAnswer? library,
    required Object? libraryError,
    required List<DeenFatwaHit> fatwaHits,
  }) {
    final buf = StringBuffer();

    if (libraryError is IslamicAppRateLimitException) {
      buf.writeln(
        malay
            ? 'Had permintaan islamic.app dicapai sebentar. Cuba lagi kemudian, '
                  'atau semak pautan fatwa di bawah jika ada. Wallahu a\'lam.'
            : 'islamic.app rate limit reached for now. Try again later, or check '
                  'any fatwa links below. Wallahu a\'lam.',
      );
      buf.writeln();
    } else if (library != null &&
        library.grounded &&
        library.answer.trim().isNotEmpty) {
      buf.writeln(
        malay
            ? 'Ringkasan daripada teks klasik (islamic.app) — bukan fatwa rasmi '
                  'JAKIM / mufti negeri. Semak petikan; rujuk ulama untuk keputusan '
                  'peribadi. Wallahu a\'lam.'
            : 'Summary from classical texts (islamic.app) — not an official JAKIM '
                  '/ state mufti ruling. Verify citations; ask a scholar for personal '
                  'decisions. Wallahu a\'lam.',
      );
      buf.writeln();
      buf.writeln(library.answer.trim());
      if (library.sources.isNotEmpty) {
        buf.writeln();
        buf.writeln(malay ? 'Sumber klasik:' : 'Classical sources:');
        for (final s in library.sources.take(5)) {
          buf.writeln('[${s.n}] ${s.label}');
          buf.writeln('    ${s.url}');
        }
      }
    } else if (library != null && !library.grounded) {
      buf.writeln(
        malay
            ? 'Tiada petikan klasik yang cukup hampir dalam islamic.app untuk soalan '
                  'ini. Sila rujuk ulama. Wallahu a\'lam.'
            : 'No closely matching classical passages were found in islamic.app for '
                  'this question. Please ask a qualified scholar. Wallahu a\'lam.',
      );
    } else if (libraryError != null && fatwaHits.isEmpty) {
      buf.writeln(
        malay
            ? 'Tidak dapat menyambung ke sumber rujukan sekarang. Cuba lagi atau '
                  'rujuk pejabat mufti tempatan. Wallahu a\'lam.'
            : 'Could not reach reference sources right now. Try again or ask your '
                  'local mufti office. Wallahu a\'lam.',
      );
    }

    if (fatwaHits.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln(
        malay
            ? 'Sumber fatwa berkaitan (indeks deen.ai — bukan rasmi Malaysia):'
            : 'Related fatwa sources (deen.ai index — not official in Malaysia):',
      );
      for (var i = 0; i < fatwaHits.length; i++) {
        final h = fatwaHits[i];
        final meta = [
          if (h.madhab != null && h.madhab!.isNotEmpty) h.madhab,
          if (h.source.isNotEmpty) h.source,
        ].join(' · ');
        buf.writeln('${i + 1}. ${h.title}');
        if (meta.isNotEmpty) buf.writeln('   $meta');
        buf.writeln('   ${h.url}');
      }
    }

    final out = buf.toString().trim();
    if (out.isNotEmpty) return out;
    return malay
        ? 'Tiada jawapan yang boleh dipetik. Rujuk ulama. Wallahu a\'lam.'
        : 'No citable answer available. Please ask a scholar. Wallahu a\'lam.';
  }
}

final muslimAiControllerProvider =
    NotifierProvider<MuslimAiController, MuslimAiUiState>(
      MuslimAiController.new,
    );
