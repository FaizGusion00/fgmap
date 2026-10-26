import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/log.dart';

/// Satu catatan ralat yang telah dibersihkan (tiada URL atau koordinat).
@immutable
class ErrorLogEntry {
  const ErrorLogEntry({
    required this.time,
    required this.source,
    required this.message,
    required this.stack,
  });

  final DateTime time;

  /// `flutter` (ralat rangka kerja/pelukisan) atau `async` (ralat tidak ditangkap).
  final String source;
  final String message;
  final String stack;

  Map<String, Object?> toJson() => {
    't': time.toIso8601String(),
    's': source,
    'm': message,
    'k': stack,
  };

  static ErrorLogEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final time = DateTime.tryParse(json['t'] as String? ?? '');
    final source = json['s'];
    final message = json['m'];
    final stack = json['k'];
    if (time == null ||
        source is! String ||
        message is! String ||
        stack is! String) {
      return null;
    }
    return ErrorLogEntry(
      time: time,
      source: source,
      message: message,
      stack: stack,
    );
  }
}

const _prefsKey = 'diag.errors.v1';

/// Log ralat TEMPATAN (cincin [capacity] entri). Tidak dihantar ke mana-mana: pengguna boleh menyalinnya
/// dari Tetapan > Bantuan dan menghantarnya sendiri. Setiap mesej dan jejak dibersihkan daripada URL dan
/// koordinat dan dipendekkan, supaya lokasi tidak terdedah walaupun ralat berpunca daripada permintaan
/// rangkaian.
class ErrorLog {
  ErrorLog({
    SharedPreferences? prefs,
    this.capacity = 50,
    DateTime Function()? clock,
  }) : _prefs = prefs,
       _clock = clock ?? DateTime.now {
    _load();
  }

  final SharedPreferences? _prefs;
  final int capacity;
  final DateTime Function() _clock;
  final List<ErrorLogEntry> _entries = [];

  static const maxMessageLength = 300;
  static const maxStackLines = 8;

  List<ErrorLogEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;

  void record(String source, Object error, StackTrace? stack) {
    final message = _clip(redactForLog(error.toString()), maxMessageLength);
    final frames = (stack?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(maxStackLines)
        .map((l) => _clip(redactForLog(l), 160))
        .join('\n');
    _entries.add(
      ErrorLogEntry(
        time: _clock(),
        source: source,
        message: message,
        stack: frames,
      ),
    );
    while (_entries.length > capacity) {
      _entries.removeAt(0);
    }
    _persist();
  }

  /// Teks laporan untuk disalin: versi app, platform, dan entri terkini dahulu.
  String report({String? appVersion}) {
    final b = StringBuffer('FGMaps laporan ralat\n');
    if (appVersion != null) b.writeln('Versi: $appVersion');
    b.writeln('Platform: ${defaultTargetPlatform.name}');
    b.writeln('Bilangan: ${_entries.length}');
    for (final e in _entries.reversed) {
      b
        ..writeln()
        ..writeln('[${e.time.toIso8601String()}] ${e.source}: ${e.message}')
        ..writeln(e.stack);
    }
    return b.toString();
  }

  void clear() {
    _entries.clear();
    _persist();
  }

  void _load() {
    final raw = _prefs?.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final item in list) {
        final e = ErrorLogEntry.fromJson(item);
        if (e != null) _entries.add(e);
      }
      while (_entries.length > capacity) {
        _entries.removeAt(0);
      }
    } on FormatException {
      // Log rosak diabaikan.
    }
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    if (_entries.isEmpty) {
      prefs.remove(_prefsKey);
    } else {
      prefs.setString(
        _prefsKey,
        jsonEncode([for (final e in _entries) e.toJson()]),
      );
    }
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}

/// Log ralat aplikasi; di-override dalam `main()` dengan contoh yang sama dengan pengendali global.
final errorLogProvider = Provider<ErrorLog>((ref) => ErrorLog());
