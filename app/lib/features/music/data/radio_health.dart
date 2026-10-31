import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/utils/log.dart';
import '../domain/track.dart';

/// Kunci stesen yang gagal disambung (kunci trek -> cap masa ms); dipadam oleh "Padam semua data saya".
const radioHealthKey = 'music.radio.failed.v1';

/// Berapa lama kegagalan diingati. Pendek kerana stesen sering pulih; cukup panjang supaya stesen
/// yang disekat mengikut negara (cth. KBS/MBC dari luar Korea) tidak terus menjadi pilihan teratas.
const radioFailureMemory = Duration(hours: 24);

/// Ingatan stesen yang gagal main pada peranti ini. Radio Browser menandakan stesen "hidup" daripada
/// pelayan mereka, bukan dari lokasi pengguna, jadi hanya peranti yang tahu stesen mana yang benar-benar
/// tidak boleh disambung di sini. Stesen yang gagal dibenam ke bawah senarai, bukan disembunyikan.
class RadioHealth extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(radioHealthKey);
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      final cutoff = DateTime.now()
          .subtract(radioFailureMemory)
          .millisecondsSinceEpoch;
      return {
        for (final e in json.entries)
          if (e.key is String && e.value is int && (e.value as int) > cutoff)
            e.key as String: e.value as int,
      };
    } on Object catch (e) {
      logDiag('Kesihatan radio rosak, diabaikan: $e');
      return const {};
    }
  }

  bool isFailed(Track t) {
    final at = state[t.key];
    return at != null &&
        DateTime.now().millisecondsSinceEpoch - at <
            radioFailureMemory.inMilliseconds;
  }

  /// Dipanggil pada setiap gambar enjin yang ralat: abaikan jika baru ditanda supaya tiada tulis
  /// SharedPreferences berulang.
  Future<void> markFailed(Track t) async {
    if (t.source != TrackSource.radio) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = state[t.key];
    if (last != null &&
        now - last < const Duration(minutes: 1).inMilliseconds) {
      return;
    }
    state = {...state, t.key: now};
    await _save();
  }

  /// Dipanggil pada setiap gambar "sedang main" (beberapa kali sesaat): tiada kerja melainkan stesen
  /// ini memang pernah ditanda gagal.
  Future<void> markOk(Track t) async {
    if (!state.containsKey(t.key)) return;
    state = {
      for (final e in state.entries)
        if (e.key != t.key) e.key: e.value,
    };
    await _save();
  }

  Future<void> clear() async {
    state = const {};
    await ref.read(sharedPreferencesProvider).remove(radioHealthKey);
  }

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(radioHealthKey, jsonEncode(state));
}

final radioHealthProvider = NotifierProvider<RadioHealth, Map<String, int>>(
  RadioHealth.new,
);
