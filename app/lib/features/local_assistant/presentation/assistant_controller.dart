import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_probe.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/log.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../data/chat_history_store.dart';
import '../data/edge_ai_runtime.dart';
import '../data/tool_executor.dart';
import '../domain/assistant_message.dart';
import '../domain/assistant_tools.dart';
import '../domain/intent_router.dart';
import '../domain/local_llm.dart';
import '../domain/reply_cleaner.dart';
import 'ai_chat_controller.dart';
import 'ai_map_bridge.dart';
import 'ai_reply_builder.dart';

export 'ai_chat_controller.dart' show AiPhase, AssistantUiState;

final localLlmRuntimeProvider = Provider<LocalLlmRuntime>(
  (ref) => EdgeAiLlmRuntime(ref.watch(sharedPreferencesProvider)),
);

/// FG AI: arahan peta dijalankan terus oleh penghala (pantas, tanpa model); soalan lain dijawab
/// oleh model kecil pada telefon dengan teks dialirkan ke skrin.
class AssistantController extends AiChatController {
  /// Destinasi terakhir yang dirancang dalam sembang ini ("tanpa tol" selepas laluan ditutup).
  String? _lastDestination;

  /// Halaman AI dibuka sebelum status model diketahui: panaskan sebaik sahaja ia sedia.
  bool _wantWarm = false;
  DateTime _lastStreamPush = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  AiMode get mode => AiMode.fg;

  @override
  AssistantUiState build() {
    final runtime = ref.read(localLlmRuntimeProvider);
    ref.onDispose(() => unawaited(runtime.release()));
    Future.microtask(_refreshInstalled);
    return initialState();
  }

  @override
  void onConversationChanged() => _lastDestination = null;

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
      if (ok && _wantWarm) unawaited(warmUp());
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: AssistantModelStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Muatkan model semasa halaman dibuka supaya jawapan pertama tidak menunggu pemuatan.
  Future<void> warmUp() async {
    _wantWarm = true;
    if (!state.modelReady || state.busy) return;
    _wantWarm = false;
    state = state.copyWith(phase: AiPhase.preparing);
    await ref
        .read(localLlmRuntimeProvider)
        .warmUp(system: assistantSystemPrompt);
    if (!ref.mounted) return;
    if (state.phase == AiPhase.preparing) {
      state = state.copyWith(phase: AiPhase.idle);
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

  Future<void> send(String text, {bool uiMalay = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;
    final l10n = replyL10n(trimmed, uiMalay: uiMalay);
    final replies = AiReplyBuilder(l10n);
    final prior = state.messages;
    final next = [...prior, userMessage(trimmed)];
    state = state.copyWith(
      messages: next,
      busy: true,
      phase: AiPhase.working,
      clearStreaming: true,
      clearError: true,
    );
    await persist(next);

    AssistantMessage reply;
    try {
      final hasRoute = ref.read(routePreviewControllerProvider) is RouteReady;
      final intent = parseIntent(trimmed, hasRoute: hasRoute);
      if (intent != null) {
        reply = await _handle(intent, replies, l10n);
      } else if (!state.modelReady) {
        reply = replies.text(l10n.aiNeedModel);
      } else {
        reply = await _askModel(trimmed, prior, replies, l10n);
      }
    } on Object catch (e) {
      logDiag('FG AI gagal: $e');
      final code = networkErrorCode(e, online: await _linkUp());
      reply = replies.text(
        code != null ? replies.failure({'error': code}) : l10n.aiError,
      );
    }
    if (!ref.mounted) return;
    final all = [...state.messages, reply];
    state = state.copyWith(
      messages: all,
      busy: false,
      phase: AiPhase.idle,
      clearStreaming: true,
      freshAt: reply.at,
    );
    await persist(all);
  }

  AssistantToolExecutor get _tools => ref.read(assistantToolExecutorProvider);

  Future<bool> _linkUp() async {
    try {
      return await ref.read(onlineProbeProvider)();
    } on Object {
      return true;
    }
  }

  Future<AssistantMessage> _handle(
    AssistantIntent intent,
    AiReplyBuilder replies,
    AppLocalizations l10n,
  ) async {
    switch (intent) {
      case RouteIntent(:final destination, :final preference, :final autoStart):
        final r = await _tools.planRoute(
          destination,
          preference: preference,
          start: autoStart,
        );
        if (r['ok'] == true) _lastDestination = r['destination'] as String?;
        return replies.route(r, query: destination);
      case RouteFollowUpIntent(:final autoStart):
        // "how do i get there / do that / tell me how": guna laluan yang sudah ada, atau destinasi terakhir.
        final preview = ref.read(routePreviewControllerProvider);
        if (preview is RouteReady) {
          if (autoStart) {
            ref.read(aiMapRequestProvider.notifier).startNavigation();
            return replies.text(l10n.aiNavStarting);
          }
          return replies.text(l10n.aiRouteReadyHint);
        }
        if (ref.read(navigationControllerProvider).isActive) {
          return replies.text(l10n.aiNavStarting);
        }
        final last = _lastDestination;
        if (last == null) return replies.text(l10n.aiAskDestination);
        final r = await _tools.planRoute(last, start: autoStart);
        if (r['ok'] == true) _lastDestination = r['destination'] as String?;
        return replies.route(r, query: last);
      case StartNavigationIntent():
        if (ref.read(routePreviewControllerProvider) is! RouteReady) {
          return replies.text(
            ref.read(navigationControllerProvider).isActive
                ? l10n.aiNavStarting
                : l10n.aiNoRouteToStart,
          );
        }
        ref.read(aiMapRequestProvider.notifier).startNavigation();
        return replies.text(l10n.aiNavStarting);
      case RoutePreferenceIntent(:final preference, :final autoStart):
        if (ref.read(routePreviewControllerProvider) is RouteReady) {
          return replies.route(
            await _tools.chooseCurrentRoute(preference, start: autoStart),
          );
        }
        final last = _lastDestination;
        if (last == null) return replies.text(l10n.aiNoRouteToStart);
        return replies.route(
          await _tools.planRoute(
            last,
            preference: preference,
            start: autoStart,
          ),
          query: last,
        );
      case CancelRouteIntent():
        ref.read(routePreviewControllerProvider.notifier).clear();
        return replies.text(l10n.aiRouteCleared);
      case NearbyIntent(:final category):
        final name = replies.categoryName(category);
        return replies.places(
          await _tools.nearby(category, fallbackName: name),
          title: l10n.aiNearbyTitle(name),
        );
      case SearchIntent(:final query):
        return replies.places(
          await _tools.searchPlace(query),
          title: l10n.aiSearchTitle(query),
          query: query,
        );
      case CurrentLocationIntent():
        return replies.currentLocation(await _tools.currentLocation());
      case ChatIntent(:final kind):
        return replies.chat(kind);
      case CapabilitiesIntent(:final offlineFocused):
        return replies.capabilities(offlineFocused: offlineFocused);
      case WeatherIntent(:final place):
        return replies.weather(
          await _tools.run('get_weather', {'query': ?place}),
          query: place,
        );
      case AirQualityIntent(:final place):
        return replies.air(
          await _tools.run('get_air_quality', {'query': ?place}),
          query: place,
        );
      case QiblaIntent():
        return replies.qibla(await _tools.run('get_qibla', const {}));
      case PrayerTimesIntent():
        return replies.prayer(await _tools.run('get_prayer_times', const {}));
      case AlongRouteIntent(:final category):
        return replies.along(
          await _tools.run('list_along_route', {'category': category}),
          category,
        );
      case PlayMusicIntent(:final query):
        return replies.playing(
          await _tools.run('play_music', {'query': query}),
          query: query,
        );
      case PlayRadioIntent(:final query):
        return replies.playing(
          await _tools.run('play_radio', {'query': query}),
          query: query,
        );
    }
  }

  Future<AssistantMessage> _askModel(
    String text,
    List<AssistantMessage> prior,
    AiReplyBuilder replies,
    AppLocalizations l10n,
  ) async {
    state = state.copyWith(phase: AiPhase.thinking);
    final context = _contextLine(text);
    final raw = await ref
        .read(localLlmRuntimeProvider)
        .chat(
          system: assistantSystemPrompt,
          history: prior,
          userText: context == null ? text : '$context\n$text',
          sessionKey: state.current?.id,
          maxToolTurns: 2,
          onTool: (name, args) async {
            if (!llmToolNames.contains(name)) return {'error': 'unknown_tool'};
            if (ref.mounted) {
              state = state.copyWith(
                phase: AiPhase.working,
                clearStreaming: true,
              );
            }
            final result = await _tools.run(name, args);
            if (ref.mounted) state = state.copyWith(phase: AiPhase.thinking);
            return clipToolMap(result);
          },
          onText: (partial) {
            if (!ref.mounted) return;
            final now = DateTime.now();
            if (partial.isNotEmpty &&
                now.difference(_lastStreamPush) <
                    const Duration(milliseconds: 60)) {
              return;
            }
            _lastStreamPush = now;
            final shown = partial.isEmpty ? '' : cleanReply(partial);
            state = shown.isEmpty
                ? state.copyWith(clearStreaming: true)
                : state.copyWith(streamingText: shown);
          },
        );
    // Lapisan kedua: runtime sudah cleanReply, tetapi pastikan setiap laluan (ujian palsu,
    // model yang mencetak skema, sisa streaming) tidak membocorkan markup alat.
    final cleaned = cleanReply(raw);
    // Model kecil mengulang ayat pengguna atau memberi salam yang tidak diminta: ganti dengan panduan ringkas.
    if (cleaned.isNotEmpty && isEchoReply(cleaned, text)) {
      return replies.text(l10n.aiNotUnderstood);
    }
    final body = cleaned.length > 2000
        ? '${cleaned.substring(0, 1999)}…'
        : cleaned;
    if (body.isEmpty) {
      // Model membuang skema alat sahaja (cth. soalan "what can I ask offline").
      if (looksLikeToolLeak(raw)) {
        return replies.capabilities(offlineFocused: true);
      }
      return replies.text(l10n.aiUnavailable);
    }
    return replies.text(body);
  }

  /// Konteks ringkas untuk model (Inggeris; bukan dipaparkan): laluan semasa, HANYA bila soalan
  /// menyebut perjalanan. Jika dihantar untuk setiap soalan, model kecil mengulang laluan itu
  /// sebagai jawapan kepada "hai" atau "siapa awak".
  String? _contextLine(String text) {
    if (!_tripQuestion.hasMatch(normalizeCommand(text))) return null;
    final nav = ref.read(navigationControllerProvider);
    if (nav.isActive) {
      return '[Context: the user is navigating now.]';
    }
    final preview = ref.read(routePreviewControllerProvider);
    if (preview is RouteReady) {
      final o = preview.selected;
      final label = preview.query.destinationLabel ?? 'the destination';
      return '[Context: route preview to $label is open, '
          '${(o.distanceM / 1000).toStringAsFixed(0)} km, '
          '${(o.durationS / 60).round()} min.]';
    }
    return null;
  }
}

final _tripQuestion = RegExp(
  r'\b(?:route|routes|trip|journey|drive|driving|toll|tolls|eta|arrive|arrival|distance|destination|navigat\w*|how\s+long|how\s+far|laluan|perjalanan|tol|jarak|destinasi|sampai|tiba|berapa\s+lama|berapa\s+jauh|memandu|navigasi)\b',
);

/// Potong nilai teks panjang dalam hasil alat supaya konteks telefon tidak membengkak.
Map<String, Object?> clipToolMap(Map<String, Object?> result, {int max = 900}) {
  final encoded = jsonEncode(result);
  if (encoded.length <= max) return result;
  return {
    for (final e in result.entries)
      e.key: e.value is String
          ? clipToolResult(e.value! as String, max: 500)
          : e.value,
  };
}

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantUiState>(
      AssistantController.new,
    );
