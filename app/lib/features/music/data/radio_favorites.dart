import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/utils/log.dart';
import '../domain/track.dart';

/// Kunci senarai stesen kegemaran (JSON); dipadam oleh "Padam semua data saya".
const radioFavoritesKey = 'music.radio.favorites.v1';
const maxRadioFavorites = 60;

/// Stesen radio kegemaran, paling baharu dahulu. Disimpan pada peranti sahaja. Hanya stesen radio:
/// lagu Audius boleh hilang dari katalog, jadi tiada gunanya menyimpannya.
class RadioFavorites extends Notifier<List<Track>> {
  @override
  List<Track> build() {
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(radioFavoritesKey);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final item in json)
          if (item is Map)
            if (Track.fromJson(Map<String, Object?>.from(item)) case final t?
                when t.source == TrackSource.radio)
              t,
      ];
    } on Object catch (e) {
      logDiag('Kegemaran radio rosak, diabaikan: $e');
      return const [];
    }
  }

  bool isFavorite(Track t) => state.contains(t);

  Future<void> toggle(Track t) async {
    if (t.source != TrackSource.radio) return;
    state = state.contains(t)
        ? [
            for (final x in state)
              if (x != t) x,
          ]
        : [t, ...state].take(maxRadioFavorites).toList();
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(sharedPreferencesProvider).remove(radioFavoritesKey);
  }

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(
        radioFavoritesKey,
        jsonEncode([for (final t in state) t.toJson()]),
      );
}

final radioFavoritesProvider = NotifierProvider<RadioFavorites, List<Track>>(
  RadioFavorites.new,
);
