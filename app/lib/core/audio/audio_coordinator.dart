import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sasaran yang perlu memberi laluan kepada suara navigasi (pemain muzik).
abstract interface class DuckTarget {
  /// Suara navigasi mula bercakap: perlahankan atau jeda.
  Future<void> onSpeechStart();

  /// Suara navigasi selesai: pulihkan.
  Future<void> onSpeechEnd();
}

/// Penyelaras audio dalam app: arahan suara navigasi mesti sentiasa jelas, jadi muzik dalam app
/// diperlahankan (atau dijeda, ikut tetapan) SEBELUM bunyi isyarat dan dipulihkan SELEPAS ayat.
///
/// Dilakukan pada peringkat Dart (bukan hanya fokus audio OS) supaya tingkah laku tetap sama di
/// Android dan iOS dan boleh diuji. Dikira rujukan: bunyi isyarat + ayat dalam satu pengumuman atau
/// dua pengumuman bertindih dikira satu tempoh bercakap.
class AudioCoordinator {
  final _targets = <DuckTarget>{};
  int _speaking = 0;

  bool get speaking => _speaking > 0;

  void register(DuckTarget target) {
    _targets.add(target);
    if (speaking) unawaited(_safe(target.onSpeechStart));
  }

  void unregister(DuckTarget target) => _targets.remove(target);

  Future<void> beginSpeech() async {
    _speaking++;
    if (_speaking == 1) {
      await Future.wait([for (final t in _targets) _safe(t.onSpeechStart)]);
    }
  }

  Future<void> endSpeech() async {
    if (_speaking == 0) return;
    _speaking--;
    if (_speaking == 0) {
      await Future.wait([for (final t in _targets) _safe(t.onSpeechEnd)]);
    }
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } on Object {
      // Pemain yang gagal tidak boleh menahan suara navigasi.
    }
  }
}

final audioCoordinatorProvider = Provider<AudioCoordinator>(
  (ref) => AudioCoordinator(),
);
