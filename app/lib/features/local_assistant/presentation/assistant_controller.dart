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
      await runtime.download(
        id: target,
        onProgress: (p) {
          if (!ref.mounted) return;
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
      if (intent is TopicIntent) {
        reply = await _topic(intent.topic, trimmed, prior, replies, l10n);
      } else if (intent != null) {
        reply = await _handle(
          intent,
          replies,
          l10n,
          askModel: () => _askModel(trimmed, prior, replies, l10n),
        );
      } else if (!state.modelReady) {
        reply = replies.text(l10n.aiNeedModel).copyWith(local: true);
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
    final summary = await _wikiSummary(topic, preferMalay: malay)
        .timeout(_topicWikiBudget, onTimeout: () => null);
    if (summary != null) {
      return replies.topic(summary).copyWith(local: true);
    }
    if (state.modelReady) return _askModel(text, prior, replies, l10n);
    return replies.text(l10n.aiNeedModel).copyWith(local: true);
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
        return replies.places(r, title: l10n.aiNearbyTitle(name));
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
