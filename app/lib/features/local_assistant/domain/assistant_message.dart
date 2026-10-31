import 'package:flutter/foundation.dart';

/// Satu mesej dalam sejarah sembang pembantu.
@immutable
class AssistantMessage {
  const AssistantMessage({required this.role, required this.text, this.at});

  final AssistantRole role;
  final String text;
  final DateTime? at;

  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    if (at != null) 'at': at!.toIso8601String(),
  };

  static AssistantMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final roleName = raw['role']?.toString();
    final text = raw['text']?.toString();
    if (roleName == null || text == null || text.trim().isEmpty) return null;
    final role = AssistantRole.values
        .where((r) => r.name == roleName)
        .firstOrNull;
    if (role == null) return null;
    return AssistantMessage(
      role: role,
      text: text,
      at: DateTime.tryParse(raw['at']?.toString() ?? ''),
    );
  }
}

enum AssistantRole { user, assistant, system }
