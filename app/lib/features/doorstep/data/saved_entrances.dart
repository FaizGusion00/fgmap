import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../domain/entrance.dart';

/// Kunci storan pintu masuk pengguna; dipadam oleh "Padam semua data saya".
const savedEntrancesKey = 'doorstep.saved.v1';

/// Pintu masuk lalai pengguna bagi satu tempat (satu bagi setiap tempat). Disimpan pada telefon sahaja.
@immutable
class SavedEntrance {
  const SavedEntrance({
    required this.place,
    required this.point,
    this.placeName,
    this.kind = EntranceKind.saved,
    this.detail,
  });

  /// Pin destinasi asal (tempat yang dicari).
  final GeoPoint place;
  final String? placeName;

  /// Pintu masuk yang dituju.
  final GeoPoint point;
  final EntranceKind kind;
  final String? detail;

  Entrance get entrance => Entrance(
    point: point,
    kind: kind,
    detail: detail,
    onBuilding: true,
    distanceM: distanceMeters(place, point),
  );

  Map<String, Object?> toJson() => {
    'pl': place.lat,
    'pn': place.lng,
    'name': placeName,
    'lat': point.lat,
    'lng': point.lng,
    'kind': kind.name,
    'detail': detail,
  };

  static SavedEntrance? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final pl = j['pl'], pn = j['pn'], lat = j['lat'], lng = j['lng'];
    if (pl is! num || pn is! num || lat is! num || lng is! num) return null;
    final kind = EntranceKind.values
        .where((k) => k.name == j['kind'])
        .firstOrNull;
    return SavedEntrance(
      place: GeoPoint(pl.toDouble(), pn.toDouble()),
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
      placeName: j['name'] is String ? j['name'] as String : null,
      kind: kind ?? EntranceKind.saved,
      detail: j['detail'] is String ? j['detail'] as String : null,
    );
  }
}

/// Pintu masuk lalai pengguna. Satu bagi setiap tempat (pin dalam [matchRadiusM]); had [maxItems].
class SavedEntrancesController extends Notifier<List<SavedEntrance>> {
  static const matchRadiusM = 150.0;
  static const maxItems = 100;

  @override
  List<SavedEntrance> build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(savedEntrancesKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final j in list) ?SavedEntrance.fromJson(j)];
    } on FormatException {
      return const [];
    }
  }

  /// Pintu lalai bagi tempat di [place] (yang paling hampir dalam [matchRadiusM]), atau null.
  SavedEntrance? forPlace(GeoPoint place) {
    SavedEntrance? best;
    var bestD = matchRadiusM;
    for (final s in state) {
      final d = distanceMeters(s.place, place);
      if (d <= bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  /// Simpan [entrance] sebagai pintu lalai bagi [place] (menggantikan yang lama bagi tempat itu).
  Future<void> save(
    GeoPoint place,
    Entrance entrance, {
    String? placeName,
  }) async {
    final item = SavedEntrance(
      place: place,
      placeName: placeName,
      point: entrance.point,
      kind: entrance.kind,
      detail: entrance.detail,
    );
    state = [
      item,
      for (final s in state)
        if (distanceMeters(s.place, place) > matchRadiusM) s,
    ].take(maxItems).toList();
    await _persist();
  }

  Future<void> remove(GeoPoint place) async {
    state = [
      for (final s in state)
        if (distanceMeters(s.place, place) > matchRadiusM) s,
    ];
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(sharedPreferencesProvider).remove(savedEntrancesKey);
  }

  Future<void> _persist() => ref
      .read(sharedPreferencesProvider)
      .setString(
        savedEntrancesKey,
        jsonEncode([for (final s in state) s.toJson()]),
      );
}

final savedEntrancesProvider =
    NotifierProvider<SavedEntrancesController, List<SavedEntrance>>(
      SavedEntrancesController.new,
    );
