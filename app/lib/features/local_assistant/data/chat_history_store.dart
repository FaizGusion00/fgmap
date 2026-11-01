import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/assistant_message.dart';
import 'muslim_ai_settings.dart';

/// Kunci lama (satu sembang setiap mod). Dipindahkan ke perbualan pertama kali dibaca.
const assistantChatPrefsKey = 'assistant.chat.v1';

/// Awalan semua kunci perbualan; padam data memadam semuanya.
const conversationPrefsPrefix = 'assistant.conv.v1.';

/// Dua AI berasingan, masing-masing dengan senarai perbualan sendiri.
enum AiMode {
  fg,
  muslim;

  String get legacyKey => switch (this) {
    AiMode.fg => assistantChatPrefsKey,
    AiMode.muslim => muslimAiChatPrefsKey,
  };
}

/// Ringkasan satu perbualan untuk senarai (mesej disimpan berasingan supaya senarai pantas).
@immutable
class ConversationMeta {
  const ConversationMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  final String id;

  /// Kosong = belum ada mesej (UI memaparkan "Sembang baharu").
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  ConversationMeta copyWith({
    String? title,
    DateTime? updatedAt,
    int? messageCount,
  }) => ConversationMeta(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messageCount: messageCount ?? this.messageCount,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'count': messageCount,
  };

  static ConversationMeta? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString();
    final created = DateTime.tryParse(raw['createdAt']?.toString() ?? '');
    if (id == null || id.isEmpty || created == null) return null;
    return ConversationMeta(
      id: id,
      title: raw['title']?.toString() ?? '',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(raw['updatedAt']?.toString() ?? '') ?? created,
      messageCount: (raw['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tajuk automatik daripada mesej pertama pengguna (seperti ChatGPT, tanpa model).
String conversationTitleFrom(String firstUserText) {
  final t = firstUserText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length <= 40) return t;
  final cut = t.substring(0, 40);
  final space = cut.lastIndexOf(' ');
  return '${space > 24 ? cut.substring(0, space) : cut}…';
}

/// Perbualan pada peranti (SharedPreferences), satu senarai setiap [AiMode]. Tiada pelayan.
class ConversationStore {
  ConversationStore(this._prefs, this.mode, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final AiMode mode;
  final DateTime Function() _clock;

  static const maxConversations = 50;
  static const maxMessages = 100;

  String get _indexKey => '$conversationPrefsPrefix${mode.name}.index';
  String get _activeKey => '$conversationPrefsPrefix${mode.name}.active';
  String _messagesKey(String id) =>
      '$conversationPrefsPrefix${mode.name}.m.$id';

  /// Senarai perbualan, terbaharu dahulu. Memindahkan sembang lama sekali sahaja.
  List<ConversationMeta> list() {
    _migrateLegacy();
    final raw = _prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = [for (final e in decoded) ?ConversationMeta.fromJson(e)]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    } on Object {
      return const [];
    }
  }

  String? get activeId => _prefs.getString(_activeKey);

  Future<void> setActive(String? id) async {
    if (id == null) {
      await _prefs.remove(_activeKey);
    } else {
      await _prefs.setString(_activeKey, id);
    }
  }

  List<AssistantMessage> messages(String id) {
    final raw = _prefs.getString(_messagesKey(id));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final e in decoded) ?AssistantMessage.fromJson(e)];
    } on Object {
      return const [];
    }
  }

  /// Perbualan kosong baharu (belum disimpan dalam senarai sehingga ada mesej).
  ConversationMeta create() {
    final now = _clock();
    final id =
        '${now.microsecondsSinceEpoch.toRadixString(36)}'
        '${Random().nextInt(1 << 20).toRadixString(36)}';
    return ConversationMeta(id: id, title: '', createdAt: now, updatedAt: now);
  }

  /// Simpan mesej perbualan dan kemas kini senarai. Tajuk diisi automatik bila masih kosong.
  Future<ConversationMeta> save(
    ConversationMeta meta,
    List<AssistantMessage> messages,
  ) async {
    final trimmed = messages.length <= maxMessages
        ? messages
        : messages.sublist(messages.length - maxMessages);
    var title = meta.title;
    if (title.isEmpty) {
      final firstUser = trimmed
          .where((m) => m.role == AssistantRole.user)
          .firstOrNull;
      if (firstUser != null) title = conversationTitleFrom(firstUser.text);
    }
    final updated = meta.copyWith(
      title: title,
      updatedAt: _clock(),
      messageCount: trimmed.length,
    );
    await _prefs.setString(
      _messagesKey(meta.id),
      jsonEncode([for (final m in trimmed) m.toJson()]),
    );
    final others = list().where((c) => c.id != meta.id).toList();
    final all = [updated, ...others];
    for (final dropped in all.skip(maxConversations)) {
      await _prefs.remove(_messagesKey(dropped.id));
    }
    await _writeIndex(all.take(maxConversations).toList());
    return updated;
  }

  Future<ConversationMeta?> rename(String id, String title) async {
    final items = list();
    final i = items.indexWhere((c) => c.id == id);
    final clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (i < 0 || clean.isEmpty) return null;
    final renamed = items[i].copyWith(title: clean);
    items[i] = renamed;
    await _writeIndex(items);
    return renamed;
  }

  /// Padam satu perbualan; pulangkan mesejnya supaya "Buat asal" boleh memulihkan.
  Future<List<AssistantMessage>> delete(String id) async {
    final removed = messages(id);
    await _prefs.remove(_messagesKey(id));
    await _writeIndex(list().where((c) => c.id != id).toList());
    if (activeId == id) await setActive(null);
    return removed;
  }

  Future<void> deleteAll() async {
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('$conversationPrefsPrefix${mode.name}.'),
    )) {
      await _prefs.remove(key);
    }
    await _prefs.remove(mode.legacyKey);
  }

  Future<void> _writeIndex(List<ConversationMeta> items) => _prefs.setString(
    _indexKey,
    jsonEncode([for (final c in items) c.toJson()]),
  );

  bool _migrated = false;

  void _migrateLegacy() {
    if (_migrated) return;
    _migrated = true;
    final raw = _prefs.getString(mode.legacyKey);
    if (raw == null || raw.isEmpty || _prefs.containsKey(_indexKey)) return;
    List<AssistantMessage> legacy;
    try {
      final decoded = jsonDecode(raw);
      legacy = decoded is List
          ? [for (final e in decoded) ?AssistantMessage.fromJson(e)]
          : const [];
    } on Object {
      legacy = const [];
    }
    if (legacy.isEmpty) {
      unawaited(_prefs.remove(mode.legacyKey));
      return;
    }
    final at = legacy.first.at ?? _clock();
    final meta = ConversationMeta(
      id: 'legacy',
      title: conversationTitleFrom(
        legacy.where((m) => m.role == AssistantRole.user).firstOrNull?.text ??
            legacy.first.text,
      ),
      createdAt: at,
      updatedAt: legacy.last.at ?? at,
      messageCount: legacy.length,
    );
    // SharedPreferences menulis ke cache serta-merta; Future hanya untuk cakera.
    unawaited(
      _prefs.setString(
        _messagesKey(meta.id),
        jsonEncode([for (final m in legacy) m.toJson()]),
      ),
    );
    unawaited(_writeIndex([meta]));
    unawaited(_prefs.remove(mode.legacyKey));
  }
}

final conversationStoreProvider = Provider.family<ConversationStore, AiMode>(
  (ref, mode) => ConversationStore(ref.watch(sharedPreferencesProvider), mode),
);

/// Padam semua perbualan kedua-dua AI (dan kunci lama).
Future<void> eraseConversations(SharedPreferences prefs) async {
  for (final key in prefs.getKeys().where(
    (k) => k.startsWith(conversationPrefsPrefix),
  )) {
    await prefs.remove(key);
  }
  await prefs.remove(assistantChatPrefsKey);
  await prefs.remove(muslimAiChatPrefsKey);
}
