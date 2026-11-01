import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/log.dart';
import '../domain/assistant_message.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_tools.dart';
import '../domain/local_llm.dart';
import '../domain/reply_cleaner.dart';

/// Status percubaan GPU, disimpan supaya laluan GPU yang merosakkan app tidak dicuba lagi. Setiap
/// model ada kunci sendiri (GPU yang lulus untuk model kecil mungkin gagal untuk model 4B); model
/// lalai mengekalkan kunci lama supaya keputusan sedia ada tidak hilang.
const assistantGpuPrefsKey = 'assistant.llm.gpu';

String gpuPrefsKeyFor(AiModelOption m) => m.id == defaultAiModel.id
    ? assistantGpuPrefsKey
    : '$assistantGpuPrefsKey.${m.id}';

/// Runtime sebenar melalui flutter_edge_ai + LiteRT-LM.
///
/// Kelajuan pada telefon perlahan:
///  - sesi diteruskan antara mesej (tidak dibina semula dan arahan sistem/alat tidak disuap semula);
///  - model kekal dalam RAM [idleRelease] selepas mesej terakhir, bukan dilepaskan setiap kali tutup;
///  - GPU dicuba sekali; jika gagal (atau app mati semasa mencuba) CPU digunakan selama-lamanya.
class EdgeAiLlmRuntime implements LocalLlmRuntime {
  EdgeAiLlmRuntime(this._prefs);

  final SharedPreferences _prefs;

  InferenceModel? _model;
  InferenceChat? _chat;
  String? _system;
  String? _sessionKey;
  int _estimatedTokens = 0;

  /// Sesi baru dibina dan belum menerima sebarang mesej.
  bool _fresh = true;
  Timer? _idle;
  Future<InferenceChat>? _opening;

  /// Model yang sedang dimuat dalam RAM (mungkin berbeza daripada yang dipilih selepas ditukar).
  AiModelOption? _loaded;

  /// Model aktif untuk bajet konteks / output: yang dalam RAM, atau yang dipilih jika belum dimuat.
  AiModelOption get _activeModel => _loaded ?? _selected;

  /// Bila anggaran konteks melebihi bahagian ini daripada konteks model, sesi dimulakan semula
  /// dengan sejarah ringkas.
  int get _sessionBudget => (_activeModel.contextTokens * 0.68).round();
  static const idleRelease = Duration(minutes: 3);

  AiModelOption get _selected => aiModelById(_prefs.getString(aiModelPrefsKey));

  @override
  String get selectedModelId => _selected.id;

  @override
  Future<void> selectModel(String id) async {
    final next = aiModelById(id);
    if (next.id == _selected.id && _loaded?.id == next.id) return;
    await release();
    await _prefs.setString(aiModelPrefsKey, next.id);
  }

  @override
  Future<Set<String>> installedModelIds() async => {
    for (final m in aiModelOptions)
      if (await FlutterEdgeAi.isModelInstalled(m.id)) m.id,
  };

  @override
  Future<bool> isInstalled() => FlutterEdgeAi.isModelInstalled(_selected.id);

  /// Pasang (atau, jika fail sudah ada, hanya aktifkan: `install()` idempoten) model [m] sebagai
  /// model aktif flutter_edge_ai.
  Future<void> _install(
    AiModelOption m, {
    void Function(double progress)? onProgress,
  }) async {
    await FlutterEdgeAi.installModel(
          modelType: m.modelType,
          fileType: ModelFileType.litertlm,
        )
        .fromNetwork(m.url)
        .withProgress((p) => onProgress?.call((p / 100.0).clamp(0.0, 1.0)))
        .install();
  }

  @override
  Future<void> download({
    String? id,
    void Function(double progress)? onProgress,
  }) async {
    final m = aiModelById(id ?? _selected.id);
    await selectModel(m.id);
    await _install(m, onProgress: onProgress);
  }

  @override
  Future<void> delete({String? id}) async {
    final m = aiModelById(id ?? _selected.id);
    if (_loaded?.id == m.id || m.id == _selected.id) await release();
    if (await FlutterEdgeAi.isModelInstalled(m.id)) {
      await FlutterEdgeAi.uninstallModel(m.id);
    }
  }

  @override
  Future<void> warmUp({required String system}) async {
    _idle?.cancel();
    try {
      await _ensureChat(system);
      _scheduleRelease();
    } on Object catch (e) {
      logDiag('AI: pemanasan model gagal: $e');
    }
  }

  Future<InferenceModel> _loadModel() async {
    final watch = Stopwatch()..start();
    final m = _selected;
    // Pastikan model yang DIPILIH ialah model aktif enjin (tiada muat turun jika fail sudah ada).
    await _install(m);
    _loaded = m;
    final key = gpuPrefsKeyFor(m);
    final gpu = _prefs.getString(key);
    if (gpu == null || gpu == 'ok') {
      if (gpu == null) await _prefs.setString(key, 'trying');
      try {
        final model = await FlutterEdgeAi.getActiveModel(
          maxTokens: m.contextTokens,
          preferredBackend: PreferredBackend.gpu,
        );
        logDiag(
          'AI: ${m.name} GPU dimuat dalam ${watch.elapsedMilliseconds} ms',
        );
        return model;
      } on Object catch (e) {
        logDiag('AI: GPU tidak tersedia untuk ${m.name} ($e); guna CPU');
        await _prefs.setString(key, 'failed');
      }
    } else if (gpu == 'trying') {
      // Percubaan lalu tidak pernah selesai (app mati semasa memuat GPU).
      await _prefs.setString(key, 'failed');
    }
    final model = await FlutterEdgeAi.getActiveModel(
      maxTokens: m.contextTokens,
      preferredBackend: PreferredBackend.cpu,
    );
    logDiag('AI: ${m.name} CPU dimuat dalam ${watch.elapsedMilliseconds} ms');
    return model;
  }

  Future<InferenceChat> _ensureChat(String system) {
    final existing = _chat;
    if (existing != null && _system == system) return Future.value(existing);
    return _opening ??= () async {
      try {
        if (_chat != null) await release();
        final model = _model ??= await _loadModel();
        final m = _activeModel;
        final chat = await model.createChat(
          temperature: 0.3,
          topK: 40,
          topP: 0.9,
          maxOutputTokens: m.maxOutputTokens,
          tools: llmAssistantTools(),
          supportsFunctionCalls: true,
          enableThinking: false,
          modelType: m.modelType,
          toolChoice: ToolChoice.auto,
          systemInstruction: system,
        );
        _chat = chat;
        _system = system;
        _sessionKey = null;
        _fresh = true;
        _estimatedTokens = _approxTokens(system) + m.maxOutputTokens;
        return chat;
      } finally {
        _opening = null;
      }
    }();
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
    String? sessionKey,
    void Function(String text)? onText,
  }) async {
    _idle?.cancel();
    final watch = Stopwatch()..start();
    final chat = await _ensureChat(system);
    final continuing =
        sessionKey != null &&
        sessionKey == _sessionKey &&
        _estimatedTokens + _approxTokens(userText) < _sessionBudget;
    if (!continuing) {
      // Perbualan lain atau konteks hampir penuh: sesi baharu dengan sejarah RINGKAS sahaja. Jawapan
      // lama dipotong supaya model tidak menyalin semula ayatnya.
      final replay = <Message>[];
      for (final m in compactHistory(history)) {
        replay.add(
          Message.text(text: m.text, isUser: m.role == AssistantRole.user),
        );
      }
      if (!_fresh) {
        await chat.clearHistory(replayHistory: replay);
      } else {
        for (final m in replay) {
          await chat.addQueryChunk(m);
        }
      }
      _sessionKey = sessionKey;
      _estimatedTokens =
          _approxTokens(system) +
          _activeModel.maxOutputTokens +
          replay.fold(0, (sum, m) => sum + _approxTokens(m.text));
    }
    await chat.addQueryChunk(Message.text(text: userText, isUser: true));
    _fresh = false;
    _estimatedTokens += _approxTokens(userText);

    final buf = StringBuffer();
    int? firstTokenMs;
    try {
      await for (final response in chat.generateChatResponseWithTools(
        maxToolTurns: maxToolTurns,
        // Model sudah memberi jawapan sebenar, kemudian meminta alat juga: kekalkan jawapan itu dan
        // jangan jalankan alat (jika tidak, jawapan di skrin hilang dan "memuatkan" bermula semula).
        isCancelled: () => hasSubstantiveAnswer(buf.toString()),
        onToolCall: (call) async {
          // Teks sebelum panggilan alat (cth. ".") bukan jawapan: buang.
          buf.clear();
          onText?.call('');
          if (!llmToolNames.contains(call.name)) {
            return {'error': 'unknown_tool'};
          }
          final args = <String, Object?>{
            for (final e in call.args.entries) e.key: e.value,
          };
          final result = await onTool(call.name, args);
          _estimatedTokens += _approxTokens(result.toString());
          return result;
        },
      )) {
        if (response is TextResponse) {
          firstTokenMs ??= watch.elapsedMilliseconds;
          buf.write(response.token);
          onText?.call(cleanReply(buf.toString()));
        }
      }
    } on Object {
      // Sesi mungkin rosak selepas ralat: mulakan semula pada mesej seterusnya.
      _sessionKey = null;
      rethrow;
    } finally {
      _scheduleRelease();
    }
    final reply = cleanReply(buf.toString());
    _estimatedTokens += _approxTokens(reply);
    final gpuKey = gpuPrefsKeyFor(_loaded ?? _selected);
    if (_prefs.getString(gpuKey) == 'trying') {
      await _prefs.setString(gpuKey, 'ok');
    }
    logDiag(
      'AI: token pertama ${firstTokenMs ?? -1} ms, jumlah '
      '${watch.elapsedMilliseconds} ms, ${reply.length} aksara, '
      '${continuing ? 'sesi diteruskan' : 'sesi baharu'}',
    );
    return reply;
  }

  void _scheduleRelease() {
    _idle?.cancel();
    _idle = Timer(idleRelease, () => unawaited(release()));
  }

  @override
  Future<void> release() async {
    _idle?.cancel();
    _chat = null;
    _system = null;
    _sessionKey = null;
    _loaded = null;
    final model = _model;
    _model = null;
    if (model != null && !model.isClosed) {
      await model.close();
    }
  }

  static int _approxTokens(String text) => (text.length / 3.2).ceil() + 4;
}

/// Teks yang sudah menjadi jawapan (bukan sisa sebelum panggilan alat seperti "." atau "Let me
/// check"): sekurang-kurangnya satu ayat penuh.
bool hasSubstantiveAnswer(String raw) {
  final t = cleanReply(raw);
  return t.length >= 40 && RegExp(r'[.!?。]\s*$|[.!?]\s').hasMatch(t);
}

/// Sejarah ringkas untuk sesi baharu: 2 pusingan terakhir; jawapan dipotong ke 200 aksara.
///
/// Jawapan yang dijana app (templat penghala, kad laluan/tempat, Wikipedia) dibuang bersama
/// soalannya: model kecil menyalinnya sebagai jawapan kepada soalan seterusnya (cth. memperkenalkan
/// diri semula bila ditanya tentang Palestin).
List<AssistantMessage> compactHistory(List<AssistantMessage> history) {
  final turns = <AssistantMessage>[];
  for (final m in history) {
    if (m.role == AssistantRole.system || m.text.trim().isEmpty) continue;
    if (m.role == AssistantRole.assistant &&
        (m.local || m.actions.isNotEmpty)) {
      if (turns.isNotEmpty && turns.last.role == AssistantRole.user) {
        turns.removeLast();
      }
      continue;
    }
    turns.add(m);
  }
  final recent = turns.length <= 4 ? turns : turns.sublist(turns.length - 4);
  return [
    for (final m in recent)
      m.role == AssistantRole.assistant && m.text.length > 200
          ? m.copyWith(text: '${m.text.substring(0, 199)}…')
          : m,
  ];
}
