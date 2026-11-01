import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_probe.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../route_preview/domain/route_option.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../search/domain/place.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../data/chat_history_store.dart';
import '../data/edge_ai_runtime.dart';
import '../data/tool_executor.dart';
import '../data/trip_info.dart';
import '../domain/assistant_message.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_tools.dart';
import '../domain/intent_router.dart';
import '../domain/local_llm.dart';
import '../domain/reply_cleaner.dart';
import 'ai_chat_controller.dart';
import 'ai_map_bridge.dart';
import 'ai_reply_builder.dart';
import '../data/web_settings.dart';
import '../data/web_knowledge.dart';
import '../../fuel/data/fuel_price_service.dart';
import 'agent_scripts.dart';
import '../../../core/agent/agent_controller.dart';

export 'ai_chat_controller.dart' show AiPhase, AssistantUiState;

final localLlmRuntimeProvider = Provider<LocalLlmRuntime>(
  (ref) => EdgeAiLlmRuntime(ref.watch(sharedPreferencesProvider)),
);

/// FG AI: arahan peta dijalankan terus oleh penghala (pantas, tanpa model); soalan lain dijawab
/// oleh model kecil pada telefon dengan teks dialirkan ke skrin.
class AssistantController extends AiChatController {
  /// Destinasi terakhir yang dirancang dalam sembang ini ("tanpa tol" selepas laluan ditutup).
  String? _lastDestination;

  /// Senarai tempat terakhir (carian/dekat) yang boleh dirujuk dengan "yang pertama", "satu lagi".
  List<Place> _lastPlaces = const [];
  int _pickCursor = -1;

  /// AI baru menawarkan "mula navigasi" (balasan terakhir ada butang mula): hanya ketika itu "ok/ya" bermakna mula.
  bool _offeredStart = false;

  /// AI baru bertanya "nak ke mana?": jawapan pendek seterusnya ialah destinasi.
  bool _pendingDestination = false;

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
  void onConversationChanged() {
    _lastDestination = null;
    _lastPlaces = const [];
    _pickCursor = -1;
    _offeredStart = false;
    _pendingDestination = false;
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

  /// Muat turun model [id] (lalai: yang dipilih) dan gunakannya.
  Future<void> downloadModel({String? id}) async {
    final runtime = ref.read(localLlmRuntimeProvider);
    final target = id ?? runtime.selectedModelId;
    state = state.copyWith(
      modelStatus: AssistantModelStatus.downloading,
      downloadProgress: 0,
      downloadingModelId: target,
      clearError: true,
    );
    try {
      var lastPercent = -1;
      await runtime.download(
        id: target,
        onProgress: (p) {
          if (!ref.mounted) return;
          // Muat turun berbilang GB melaporkan kemajuan sangat kerap; setiap kemas kini membina
          // semula halaman AI dan helaian model. Hanya bila peratus (bulat) berubah: <= 100 kali.
          final percent = (p * 100).floor();
          if (percent == lastPercent) return;
          lastPercent = percent;
          state = state.copyWith(downloadProgress: p);
        },
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: AssistantModelStatus.ready,
        downloadProgress: 1,
        clearDownloading: true,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        modelStatus: AssistantModelStatus.error,
        error: e.toString(),
        clearDownloading: true,
      );
    }
    ref
      ..invalidate(installedAiModelsProvider)
      ..invalidate(selectedAiModelProvider);
  }

  /// Gunakan model [id] yang sudah dimuat turun (satu model sahaja digunakan pada satu masa).
  Future<void> selectModel(String id) async {
    if (state.busy) return;
    final runtime = ref.read(localLlmRuntimeProvider);
    await runtime.selectModel(id);
    if (!ref.mounted) return;
    ref.invalidate(selectedAiModelProvider);
    await _refreshInstalled();
  }

  /// Padam model [id] (lalai: yang dipilih) dari telefon.
  Future<void> deleteModel({String? id}) async {
    try {
      await ref.read(localLlmRuntimeProvider).delete(id: id);
      if (!ref.mounted) return;
      ref.invalidate(installedAiModelsProvider);
      await _refreshInstalled();
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
      final intent = parseIntent(
        trimmed,
        context: ConversationContext(
          hasRoute: hasRoute,
          navActive: ref.read(navigationControllerProvider).isActive,
          offeredStart: _offeredStart,
          resultCount: _lastPlaces.length,
          pendingDestination: _pendingDestination,
        ),
      );
      _pendingDestination = false;
      final webIntent = intent is WebSearchIntent ? intent : null;
      if (webIntent != null &&
          (webIntent.explicit || ref.read(assistantAutoWebProvider))) {
        reply = await _web(webIntent, trimmed, prior, replies, l10n);
      } else if (intent is TopicIntent) {
        reply = await _topic(intent.topic, trimmed, prior, replies, l10n);
      } else if (intent != null && webIntent == null) {
        var usedModel = false;
        reply = await _withDeadline(
          _handle(
            intent,
            replies,
            l10n,
            askModel: () {
              usedModel = true;
              return _askModel(trimmed, prior, replies, l10n);
            },
          ),
          exempt: () => usedModel,
        );
        // Jawapan app (templat, kad laluan/tempat), bukan model: ditanda supaya tidak dimainkan
        // semula kepada model (ia menyalinnya sebagai jawapan soalan seterusnya).
        if (!usedModel) reply = reply.copyWith(local: true);
      } else if (!state.modelReady) {
        reply = replies
            .text(l10n.aiNeedModel, actions: replies.defaultAsks())
            .copyWith(local: true);
      } else {
        reply = await _askModel(trimmed, prior, replies, l10n);
        // Soalan fakta semasa tetapi carian automatik dimatikan: tawarkan carian dengan satu ketikan.
        if (webIntent != null) {
          reply = reply.copyWith(
            actions: [
              ...reply.actions,
              AssistantAction(
                AssistantActionKind.ask,
                label: '${l10n.aiSearchWebAsk}: $trimmed',
              ),
            ],
          );
        }
      }
    } on Object catch (e) {
      logDiag('FG AI gagal: $e');
      final code = networkErrorCode(e, online: await _linkUp());
      reply = replies.text(
        code != null ? replies.failure({'error': code}) : l10n.aiError,
      );
    }
    if (!ref.mounted) return;
    _offeredStart = reply.actions.any(
      (a) => a.kind == AssistantActionKind.startNavigation,
    );
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

  /// Had masa untuk arahan penghala: pelayan yang tergantung tidak boleh membiarkan "Working on it"
  /// selamanya. Bila model sedang menjana ([exempt]), tiada had: model besar pada telefon perlahan
  /// boleh mengambil masa lebih lama dan memotongnya hanya membuang jawapan yang hampir siap.
  Future<T> _withDeadline<T>(
    Future<T> work, {
    required bool Function() exempt,
    Duration limit = const Duration(seconds: 25),
  }) {
    final done = Completer<T>();
    final timer = Timer(limit, () {
      if (done.isCompleted || exempt()) return;
      done.completeError(TimeoutException('FG AI', limit));
    });
    work.then(
      (v) {
        timer.cancel();
        if (!done.isCompleted) done.complete(v);
      },
      onError: (Object e, StackTrace st) {
        timer.cancel();
        if (!done.isCompleted) done.completeError(e, st);
      },
    );
    return done.future;
  }

  /// Carian spekulatif ("bagus", "resepi nasi lemak") hanya dipercayai jika nama hasil mengandungi SEMUA perkataan
  /// pertanyaan; pencari kabur sering memulangkan tempat yang tidak berkaitan untuk sebarang teks.
  Map<String, Object?> _onlyNameMatches(Map<String, Object?> r, String query) {
    if (r['ok'] != true) return r;
    final tokens = query
        .toLowerCase()
        .split(' ')
        .where((w) => w.length >= 2)
        .toList();
    final kept = [
      for (final p in (r['places'] as List).whereType<Map<String, Object?>>())
        if (tokens.every(
          (w) =>
              '${p['name']} ${p['subtitle']}'.toLowerCase().contains(w) ||
              _fold('${p['name']}').contains(_fold(w)) ||
              _initials('${p['name']}').contains(_fold(w)),
        ))
          p,
    ];
    if (kept.isEmpty) {
      return {'ok': false, 'error': 'not_found', 'query': query};
    }
    return {...r, 'places': kept};
  }

  /// "Kuala Lumpur City Centre" -> "klcc" (orang menaip singkatan).
  static String _initials(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0])
      .join();

  static String _fold(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Ingat tempat daripada hasil carian/dekat untuk rujukan "yang pertama".
  void _rememberPlaces(Map<String, Object?> r) {
    if (r['ok'] != true) return;
    final list = (r['places'] as List?)?.whereType<Map<String, Object?>>();
    if (list == null) return;
    final places = <Place>[
      for (final p in list)
        if (p['lat'] is num && p['lng'] is num)
          Place(
            name: p['name']?.toString() ?? '',
            subtitle: p['subtitle']?.toString() ?? '',
            point: GeoPoint(
              (p['lat']! as num).toDouble(),
              (p['lng']! as num).toDouble(),
            ),
          ),
    ];
    if (places.isEmpty) return;
    _lastPlaces = places;
    _pickCursor = -1;
  }

  Future<AssistantMessage> _routeTo(
    Place place,
    AiReplyBuilder replies, {
    bool start = false,
  }) async {
    final r = await _tools.planRouteToPlace(place, start: start);
    if (r['ok'] == true) _lastDestination = r['destination'] as String?;
    return replies.route(r, query: place.name);
  }

  AssistantToolExecutor get _tools => ref.read(assistantToolExecutorProvider);

  /// Had keseluruhan Wikipedia sebelum sandaran model. Tanpa ini, 2 bahasa × 2 permintaan
  /// (receiveTimeout 8s) boleh biarkan UI "sibuk" ~30s+ bila Wikipedia lambat/mati.
  static const _topicWikiBudget = Duration(seconds: 10);

  /// Soalan topik ("tell me about Palestine"): fakta daripada Wikipedia (bahasa soalan, kemudian
  /// Inggeris). Tanpa internet, lambat, atau tiada rencana: model menjawab daripada pengetahuannya.
  Future<AssistantMessage> _topic(
    String topic,
    String text,
    List<AssistantMessage> prior,
    AiReplyBuilder replies,
    AppLocalizations l10n,
  ) async {
    final malay = l10n.localeName.startsWith('ms');
    final summary = await _wikiSummary(
      topic,
      preferMalay: malay,
    ).timeout(_topicWikiBudget, onTimeout: () => null);
    if (summary != null) {
      return replies.topic(summary).copyWith(local: true);
    }
    if (state.modelReady) return _askModel(text, prior, replies, l10n);
    return replies
        .text(l10n.aiNeedModel, actions: replies.defaultAsks())
        .copyWith(local: true);
  }

  Future<String?> _wikiSummary(
    String topic, {
    required bool preferMalay,
  }) async {
    for (final lang in [if (preferMalay) 'ms', 'en']) {
      final r = await _tools.run('wikipedia_summary', {
        'query': topic,
        'lang': lang,
      });
      if (r['ok'] == true && r['summary'] is String) {
        return r['summary']! as String;
      }
    }
    return null;
  }

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
    AppLocalizations l10n, {
    required Future<AssistantMessage> Function() askModel,
  }) async {
    switch (intent) {
      case RouteIntent(
        :final destination,
        :final preference,
        :final autoStart,
        :final soft,
      ):
        final r = await _tools.planRoute(
          destination,
          preference: preference,
          start: autoStart,
        );
        if (soft &&
            (r['error'] == 'not_found' || r['error'] == 'offline_not_found') &&
            state.modelReady) {
          // "how do i go to sleep faster": bukan tempat sebenar, biar model menjawab.
          return askModel();
        }
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
        if (last == null) {
          _pendingDestination = true;
          return replies.text(l10n.aiAskDestination);
        }
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
      case NearbyIntent(:final category, :final navigate, :final autoStart):
        final name = replies.categoryName(category);
        final r = await _tools.nearby(category, fallbackName: name);
        _rememberPlaces(r);
        if (navigate && r['ok'] == true && _lastPlaces.isNotEmpty) {
          // "bawa saya ke stesen minyak terdekat": terus ke yang terdekat (yang lain ada dalam senarai untuk "satu lagi").
          _pickCursor = 0;
          return _routeTo(_lastPlaces.first, replies, start: autoStart);
        }
        return replies.places(
          r,
          title: l10n.aiNearbyTitle(name),
          category: category,
        );
      case SearchIntent(:final query, :final speculative):
        var r = await _tools.searchPlace(query);
        if (speculative) r = _onlyNameMatches(r, query);
        _rememberPlaces(r);
        if (speculative && r['ok'] != true && state.modelReady) {
          // Bukan nama tempat yang dikenali: mungkin soalan pendek, serahkan kepada model.
          return askModel();
        }
        return replies.places(
          r,
          title: speculative
              ? l10n.aiGuessedPlace(query)
              : l10n.aiSearchTitle(query),
          query: query,
        );
      case PickResultIntent(:final index, :final other, :final autoStart):
        if (_lastPlaces.isEmpty) return replies.text(l10n.aiAskDestination);
        final i = other ? _pickCursor + 1 : index;
        if (i < 0 || i >= _lastPlaces.length) {
          return replies.text(l10n.aiNoMoreResults);
        }
        _pickCursor = i;
        return _routeTo(_lastPlaces[i], replies, start: autoStart);
      case GoSavedPlaceIntent(:final slot, :final autoStart):
        final saved = ref.read(savedPlacesControllerProvider.notifier);
        final target = slot == SavedSlot.home ? saved.home : saved.work;
        if (target == null) {
          return replies.text(
            slot == SavedSlot.home ? l10n.aiHomeNotSet : l10n.aiWorkNotSet,
          );
        }
        return _routeTo(target.place, replies, start: autoStart);
      case TripInfoIntent(:final kind):
        return replies.trip(kind, tripInfo(ref, kind));
      case ChangeVehicleIntent(:final vehicle):
        await ref
            .read(routePreviewControllerProvider.notifier)
            .setVehicle(
              vehicle == AssistVehicle.motorcycle
                  ? RouteVehicle.motorcycle
                  : RouteVehicle.car,
            );
        return replies.text(
          vehicle == AssistVehicle.motorcycle
              ? l10n.aiVehicleMotorcycle
              : l10n.aiVehicleCar,
        );
      case VoiceIntent(:final enabled):
        await ref
            .read(navigationSettingsProvider.notifier)
            .setVoiceEnabled(enabled);
        return replies.text(enabled ? l10n.aiVoiceOn : l10n.aiVoiceOff);
      case ThemeIntent(:final theme):
        await ref.read(themeControllerProvider.notifier).setMode(
          switch (theme) {
            AssistTheme.dark => AppThemeMode.dark,
            AssistTheme.light => AppThemeMode.light,
            AssistTheme.system => AppThemeMode.system,
          },
        );
        return replies.text(switch (theme) {
          AssistTheme.dark => l10n.aiThemeDark,
          AssistTheme.light => l10n.aiThemeLight,
          AssistTheme.system => l10n.aiThemeSystem,
        });
      case StopNavigationIntent():
        if (!ref.read(navigationControllerProvider).isActive) {
          return replies.text(l10n.aiAck);
        }
        await ref.read(navigationControllerProvider.notifier).stop();
        return replies.text(l10n.aiNavStopped);
      case AskSlotIntent(:final slot):
        if (slot == AskSlot.destination) _pendingDestination = true;
        return replies.text(switch (slot) {
          AskSlot.destination => l10n.aiAskDestination,
          AskSlot.radioStation => l10n.aiAskRadio,
          AskSlot.musicQuery => l10n.aiAskMusic,
        });
      case CurrentLocationIntent():
        return replies.currentLocation(await _tools.currentLocation());
      case ChatIntent(:final kind):
        return replies.chat(kind);
      case TopicIntent(:final topic):
        // Dikendalikan dalam send() (perlukan model sebagai sandaran); di sini hanya untuk lengkap.
        final summary = await _wikiSummary(
          topic,
          preferMalay: l10n.localeName.startsWith('ms'),
        ).timeout(_topicWikiBudget, onTimeout: () => null);
        return summary != null
            ? replies.topic(summary)
            : replies.text(l10n.aiUnavailable);
      case WebSearchIntent():
        // Dikendalikan dalam send() (_web); di sini hanya untuk lengkap.
        return replies.noAnswer();
      case OpenScreenIntent():
        return _runAgent(intent, replies, l10n);
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
    AppLocalizations l10n, {
    List<WebSnippet> web = const [],
  }) async {
    state = state.copyWith(phase: AiPhase.thinking);
    final context = web.isNotEmpty
        ? webContext(web, _clockNow())
        : _contextLine(text);
    // Sumber yang dirujuk jawapan: hasil carian awal, ditambah hasil alat web_search model.
    final cited = [...web];
    // Model meminta ejen menggunakan app: senarai semak ejen ialah jawapannya.
    AssistantMessage? agentReply;
    final raw = await ref
        .read(localLlmRuntimeProvider)
        .chat(
          system: assistantSystemPrompt,
          history: prior,
          userText: context == null ? text : '$context\nQuestion: $text',
          sessionKey: state.current?.id,
          maxToolTurns: 2,
          onTool: (name, args) async {
            if (!llmToolNames.contains(name)) return {'error': 'unknown_tool'};
            if (ref.mounted) {
              state = state.copyWith(
                phase: name == 'web_search'
                    ? AiPhase.browsing
                    : AiPhase.working,
                clearStreaming: true,
              );
            }
            if (name == 'app_action') {
              final screen = appScreenForAction('${args['action']}');
              if (screen == null) {
                return {'ok': false, 'error': 'unknown_action'};
              }
              final place = args['place']?.toString().trim();
              agentReply = await _runAgent(
                OpenScreenIntent(
                  screen,
                  arg: place == null || place.isEmpty ? null : place,
                ),
                replies,
                l10n,
              );
              if (ref.mounted) state = state.copyWith(phase: AiPhase.thinking);
              return {'ok': true, 'done': true};
            }
            if (name == 'web_search') {
              final found = await ref
                  .read(webKnowledgeProvider)
                  .search(
                    '${args['query'] ?? text}',
                    malay: l10n.localeName.startsWith('ms'),
                  );
              final offset = cited.length;
              cited.addAll(found.snippets);
              if (ref.mounted) state = state.copyWith(phase: AiPhase.thinking);
              return webToolResult(found.snippets, offset: offset);
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
    final agentDone = agentReply;
    if (agentDone != null) return agentDone;
    // Lapisan kedua: runtime sudah cleanReply, tetapi pastikan setiap laluan (ujian palsu,
    // model yang mencetak skema, sisa streaming) tidak membocorkan markup alat.
    final cleaned = cleanReply(raw);
    // Model kecil mengulang ayat pengguna atau memberi salam yang tidak diminta: ganti dengan panduan ringkas.
    if (cleaned.isNotEmpty && isEchoReply(cleaned, text)) {
      return replies.noAnswer();
    }
    final body = cleaned.length > 2000
        ? '${cleaned.substring(0, 1999)}…'
        : cleaned;
    if (body.isEmpty) {
      // Model membuang skema alat sahaja (cth. soalan "what can I ask offline").
      if (looksLikeToolLeak(raw)) {
        return replies.capabilities(offlineFocused: true);
      }
      return replies.noAnswer();
    }
    if (cited.isEmpty) return replies.text(body);
    return replies
        .text(body)
        .copyWith(
          sources: [
            for (var i = 0; i < cited.length; i++)
              replies.webSource(cited[i], i + 1),
          ],
        );
  }

  DateTime _clockNow() => DateTime.now();

  /// Ejen menggunakan app di skrin (jari hantu + senarai semak, ADR 0019), kemudian jawapan dalam
  /// sembang meringkaskan setiap langkah. Langkah gagal tidak diteruskan.
  Future<AssistantMessage> _runAgent(
    OpenScreenIntent intent,
    AiReplyBuilder replies,
    AppLocalizations l10n,
  ) async {
    final steps = agentStepsFor(intent, l10n);
    final outcome = await ref
        .read(agentControllerProvider.notifier)
        .run(agentTitleFor(intent, l10n), steps);
    final lines = [
      for (final s in outcome.steps)
        '${switch (s.status) {
          AgentStepStatus.done => '✓',
          AgentStepStatus.failed => '✗',
          _ => '○',
        }} ${s.label}',
    ];
    final head = outcome.completed
        ? l10n.agentDone
        : outcome.stopped
        ? l10n.agentStopped
        : l10n.agentFailed;
    return replies.text('**$head**\n${lines.join('\n')}');
  }

  /// Maklumat terkini dari internet (ADR 0018). Kadar tukaran dan harga minyak terus dari sumber
  /// rasmi; pautan dibaca; soalan umum/berita dicari serentak (berita, DuckDuckGo, Wikipedia) lalu
  /// diringkaskan oleh model (jika ada) dengan petikan [n], atau dipaparkan sebagai senarai bersumber.
  Future<AssistantMessage> _web(
    WebSearchIntent intent,
    String text,
    List<AssistantMessage> prior,
    AiReplyBuilder replies,
    AppLocalizations l10n,
  ) async {
    state = state.copyWith(phase: AiPhase.browsing);
    final web = ref.read(webKnowledgeProvider);
    final malay = l10n.localeName.startsWith('ms');
    const budget = Duration(seconds: 12);
    AssistantMessage offline() => replies
        .text(replies.failure({'error': 'offline'}))
        .copyWith(local: true);
    switch (intent.kind) {
      case WebKind.exchangeRate:
        try {
          final rate = await web
              .exchangeRate(intent.currency ?? 'USD')
              .timeout(budget);
          if (rate != null) return replies.webFact(rate).copyWith(local: true);
        } on Object catch (e) {
          if (!await _linkUp()) return offline();
          logDiag('Kadar BNM gagal: $e');
        }
        break;
      case WebKind.fuelPrice:
        try {
          final prices = await ref
              .read(fuelPricesProvider.future)
              .timeout(budget);
          if (prices != null) {
            return replies.fuelPrices(prices).copyWith(local: true);
          }
        } on Object catch (e) {
          logDiag('Harga minyak gagal: $e');
        }
        if (!await _linkUp()) return offline();
        break;
      case WebKind.url:
        WebSnippet? page;
        try {
          page = await web.readUrl(intent.query).timeout(budget);
        } on Object catch (e) {
          logDiag('Baca pautan gagal: $e');
          if (!await _linkUp()) return offline();
        }
        if (page == null) {
          return replies.text(l10n.aiWebUnreadable).copyWith(local: true);
        }
        if (state.modelReady) {
          return _askModel(text, prior, replies, l10n, web: [page]);
        }
        return replies
            .webResults([page], title: page.title)
            .copyWith(local: true);
      case WebKind.general:
      case WebKind.news:
        break;
    }
    final query =
        intent.kind == WebKind.exchangeRate || intent.kind == WebKind.fuelPrice
        ? text
        : intent.query;
    final found = intent.kind == WebKind.news
        ? WebSearchResult(
            await web
                .news(query, malay: malay)
                .timeout(budget)
                .catchError((Object _) => const <WebSnippet>[]),
          )
        : await web.search(query, malay: malay);
    final snippets = found.snippets.take(5).toList();
    if (snippets.isEmpty) {
      if (found.failed || !await _linkUp()) return offline();
      return replies.text(l10n.aiWebNothing(query)).copyWith(local: true);
    }
    if (state.modelReady && intent.kind != WebKind.news) {
      return _askModel(text, prior, replies, l10n, web: snippets);
    }
    return replies
        .webResults(
          snippets,
          title: intent.kind == WebKind.news
              ? l10n.aiWebNewsTitle(query)
              : l10n.aiWebResultsTitle(query),
        )
        .copyWith(local: true);
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

/// Model yang dipilih untuk FG AI (lihat `aiModelOptions`).
final selectedAiModelProvider = Provider<AiModelOption>(
  (ref) => aiModelById(ref.read(localLlmRuntimeProvider).selectedModelId),
);

/// Model yang sudah dimuat turun pada telefon.
final installedAiModelsProvider = FutureProvider<Set<String>>(
  (ref) => ref.read(localLlmRuntimeProvider).installedModelIds(),
);

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantUiState>(
      AssistantController.new,
    );

/// Konteks hasil internet untuk model (Inggeris; tidak dipaparkan): bernombor supaya jawapan boleh
/// memetik [n], dihadkan ~1,200 aksara (setiap token diproses pada telefon).
String webContext(List<WebSnippet> web, DateTime now) {
  final b = StringBuffer(
    '[Web results fetched ${now.toIso8601String().substring(0, 10)}. Answer the question using ONLY '
    'these results, cite them like [1], and say plainly if they do not answer it.]',
  );
  var budget = 1200;
  for (var i = 0; i < web.length && budget > 0; i++) {
    final s = web[i];
    final date = s.date == null
        ? ''
        : ', ${s.date!.toIso8601String().substring(0, 10)}';
    final body = s.text.isEmpty ? '' : ': ${s.text}';
    var line = '[${i + 1}] ${s.title} (${s.source}$date)$body';
    if (line.length > 320) line = '${line.substring(0, 319)}…';
    b.write('\n$line');
    budget -= line.length;
  }
  return b.toString();
}

/// Hasil alat `web_search` untuk model, bernombor bermula selepas [offset] sumber sedia ada.
Map<String, Object?> webToolResult(List<WebSnippet> web, {int offset = 0}) {
  if (web.isEmpty) return {'ok': false, 'error': 'not_found'};
  return {
    'ok': true,
    'results': [
      for (var i = 0; i < web.length && i < 5; i++)
        {
          'n': offset + i + 1,
          'title': web[i].title,
          'source': web[i].source,
          if (web[i].date != null)
            'date': web[i].date!.toIso8601String().substring(0, 10),
          if (web[i].text.isNotEmpty)
            'text': web[i].text.length > 240
                ? '${web[i].text.substring(0, 239)}…'
                : web[i].text,
        },
    ],
    'note': 'Cite results as [n].',
  };
}
