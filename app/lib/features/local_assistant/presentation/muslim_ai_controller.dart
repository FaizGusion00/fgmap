import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_history_store.dart';
import '../data/deen_fatwa_client.dart';
import '../data/islamic_app_client.dart';
import '../data/muslim_ai_settings.dart';
import '../domain/assistant_message.dart';
import '../domain/local_llm.dart';
import 'ai_chat_controller.dart';

export 'ai_chat_controller.dart' show AiPhase, AssistantUiState;

/// FGMuslim AI: jawapan berpetikan islamic.app (utama) + pautan fatwa deen.ai, dipaparkan sebagai
/// jawapan bersih dengan kad sumber, bukan longgokan URL.
class MuslimAiController extends AiChatController {
  CancelToken? _cancel;

  @override
  AiMode get mode => AiMode.muslim;

  @override
  AssistantUiState build() {
    ref.onDispose(() => _cancel?.cancel());
    return initialState().copyWith(modelStatus: AssistantModelStatus.ready);
  }

  @override
  void onConversationChanged() => _cancel?.cancel();

  Future<void> send(String text, {bool uiMalay = false}) async {
    if (!ref.read(muslimAiSettingsProvider).isActive) {
      state = state.copyWith(error: 'not_enabled');
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    final next = [...state.messages, userMessage(trimmed)];
    state = state.copyWith(
      messages: next,
      busy: true,
      phase: AiPhase.searching,
      clearError: true,
    );
    await persist(next);

    _cancel?.cancel();
    final cancel = _cancel = CancelToken();

    // Kedua-dua sumber serentak: jumlah masa = yang paling lambat, bukan dicampur.
    final libraryFuture = _ask(trimmed, cancel);
    final fatwaFuture = _fatwa(trimmed, cancel);
    final library = await libraryFuture;
    final fatwa = await fatwaFuture;
    if (!ref.mounted || cancel.isCancelled) return;

    final reply = composeMuslimReply(
      library: library.answer,
      libraryError: library.error,
      fatwaHits: fatwa,
    );
    final all = [...state.messages, reply];
    state = state.copyWith(
      messages: all,
      busy: false,
      phase: AiPhase.idle,
      freshAt: reply.at,
    );
    await persist(all);
  }

  Future<({IslamicAppAnswer? answer, Object? error})> _ask(
    String q,
    CancelToken cancel,
  ) async {
    try {
      final a = await ref.read(islamicAppClientProvider).ask(q, cancel: cancel);
      return (answer: a, error: null);
    } on Object catch (e) {
      return (answer: null, error: e);
    }
  }

  Future<List<DeenFatwaHit>> _fatwa(String q, CancelToken cancel) async {
    try {
      final hits = await ref
          .read(deenFatwaClientProvider)
          .search(q, cancel: cancel);
      return hits.take(3).toList();
    } on Object {
      return const [];
    }
  }
}

/// Bina jawapan berstruktur: teks jawapan sahaja (tanpa senarai rujukan yang model sertakan),
/// sumber sebagai data, dan nota piawai yang diterjemah semasa dipaparkan.
AssistantMessage composeMuslimReply({
  required IslamicAppAnswer? library,
  required Object? libraryError,
  required List<DeenFatwaHit> fatwaHits,
  DateTime? at,
}) {
  final grounded =
      library != null && library.grounded && library.answer.trim().isNotEmpty;
  final AnswerNotice? notice;
  if (libraryError is IslamicAppRateLimitException) {
    notice = AnswerNotice.rateLimited;
  } else if (grounded) {
    notice = AnswerNotice.classicalSummary;
  } else if (library != null) {
    notice = AnswerNotice.notGrounded;
  } else {
    notice = fatwaHits.isEmpty ? AnswerNotice.unreachable : null;
  }
  return AssistantMessage(
    role: AssistantRole.assistant,
    text: grounded ? stripReferenceList(library.answer) : '',
    at: at ?? DateTime.now(),
    notice: notice,
    sources: [
      if (grounded)
        for (final s in library.sources.take(6))
          AnswerSource(
            kind: AnswerSourceKind.classical,
            n: s.n > 0 ? s.n : null,
            title: (s.translit?.trim().isNotEmpty ?? false)
                ? s.translit!.trim()
                : s.bookTitle,
            original:
                (s.translit?.trim().isNotEmpty ?? false) &&
                    s.bookTitle != s.translit
                ? s.bookTitle
                : null,
            subtitle: [
              if (s.chapterTitle?.trim().isNotEmpty ?? false)
                s.chapterTitle!.trim(),
              if (s.page != null) 'p.${s.page}',
            ].join(' · '),
            url: s.url,
          ),
      for (final h in fatwaHits)
        AnswerSource(
          kind: AnswerSourceKind.fatwa,
          title: h.title,
          subtitle: [
            if (h.madhab?.isNotEmpty ?? false) h.madhab!,
            if (h.source.isNotEmpty) h.source,
          ].join(' · '),
          url: h.url,
        ),
    ],
  );
}

final _referenceHeading = RegExp(
  r'^\s*(?:#+\s*)?(?:\*\*)?(?:sources|references|citations|rujukan|sumber(?:\s+rujukan)?)(?:\*\*)?\s*:?\s*(?:\*\*)?\s*$',
  caseSensitive: false,
);
final _referenceLine = RegExp(r'^\s*(?:[-*•]\s*)?\[\d+\]\s+\S');

/// Buang senarai rujukan di hujung jawapan model (sumber dipaparkan sebagai kad berasingan).
/// Penanda petikan dalam ayat ("... [2]") dikekalkan.
String stripReferenceList(String answer) {
  final lines = answer.trim().split('\n');
  final heading = lines.indexWhere(_referenceHeading.hasMatch);
  var end = heading >= 0 ? heading : lines.length;
  while (end > 0 &&
      (lines[end - 1].trim().isEmpty ||
          _referenceLine.hasMatch(lines[end - 1]))) {
    end--;
  }
  final kept = lines.sublist(0, end).join('\n').trim();
  return kept.isEmpty ? answer.trim() : kept;
}

final muslimAiControllerProvider =
    NotifierProvider<MuslimAiController, AssistantUiState>(
      MuslimAiController.new,
    );
