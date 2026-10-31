import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/assistant_message.dart';
import 'muslim_ai_settings.dart';

const assistantChatPrefsKey = 'assistant.chat.v1';

/// Sejarah sembang pada peranti (dipadam oleh padam data).
class ChatHistoryStore {
  ChatHistoryStore(this._prefs, {this.prefsKey = assistantChatPrefsKey});

  final SharedPreferences _prefs;
  final String prefsKey;
  static const maxMessages = 40;

  List<AssistantMessage> load() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded) ?AssistantMessage.fromJson(e),
      ];
    } on Object {
      return const [];
    }
  }

  Future<void> save(List<AssistantMessage> messages) async {
    final trimmed = messages.length <= maxMessages
        ? messages
        : messages.sublist(messages.length - maxMessages);
    await _prefs.setString(
      prefsKey,
      jsonEncode([for (final m in trimmed) m.toJson()]),
    );
  }

  Future<void> clear() => _prefs.remove(prefsKey);
}

final chatHistoryStoreProvider = Provider(
  (ref) => ChatHistoryStore(ref.watch(sharedPreferencesProvider)),
);

final muslimChatHistoryStoreProvider = Provider(
  (ref) => ChatHistoryStore(
    ref.watch(sharedPreferencesProvider),
    prefsKey: muslimAiChatPrefsKey,
  ),
);
