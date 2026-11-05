import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../data/osm_entrances.dart';
import '../data/saved_entrances.dart';
import '../domain/entrance.dart';

/// Tempat (pin destinasi asal) dan pintu masuk yang dipilih untuk laluan semasa.
@immutable
class DoorstepState {
  const DoorstepState({this.place, this.placeLabel, this.selected});

  /// Pin destinasi asal: kekal walaupun laluan kini menuju pintu masuk.
  final GeoPoint? place;
  final String? placeLabel;

  /// Pintu yang dituju; null = pin destinasi.
  final Entrance? selected;
}

/// Pintu masuk untuk pratonton laluan. Memerhati destinasi laluan: destinasi baharu = tempat baharu
/// (pintu lalai pengguna, jika ada, terus digunakan); laluan ke pintu = tempat yang sama.
class DoorstepController extends Notifier<DoorstepState> {
  /// Tempat yang sudah ditawarkan pintu lalai (sekali sahaja; pengguna boleh kembali ke pin).
  GeoPoint? _autoUsedFor;

  @override
  DoorstepState build() {
    ref.listen(routePreviewControllerProvider, (_, next) => _observe(next));
    final now = ref.read(routePreviewControllerProvider);
    final seed = _destinationOf(now);
    return seed == null
        ? const DoorstepState()
        : DoorstepState(place: seed.$1, placeLabel: seed.$2);
  }

  static (GeoPoint, String?)? _destinationOf(RoutePreviewState s) =>
      switch (s) {
        RouteLoading() => (s.destination, s.destinationLabel),
        RouteReady() => (s.query.destination, s.query.destinationLabel),
        RouteFailed() => (s.query.destination, s.query.destinationLabel),
        RouteLocationUnavailable() => (s.destination, s.destinationLabel),
        RouteIdle() => null,
      };

  static bool _same(GeoPoint a, GeoPoint b) => distanceMeters(a, b) < 1;

  void _observe(RoutePreviewState next) {
    final d = _destinationOf(next);
    if (d == null) return;
    final (dest, label) = d;
    final selected = state.selected;
    if (selected != null && _same(dest, selected.point)) return;
    final place = state.place;
    if (place != null && _same(dest, place)) {
      if (selected != null) {
        state = DoorstepState(place: place, placeLabel: state.placeLabel);
      }
      return;
    }
    // Destinasi baharu (carian, Google, masjid, FG AI...): tempat baharu.
    state = DoorstepState(place: dest, placeLabel: label);
    final saved = ref.read(savedEntrancesProvider.notifier).forPlace(dest);
    if (saved != null &&
        (_autoUsedFor == null || !_same(_autoUsedFor!, dest)) &&
        distanceMeters(saved.point, dest) > 10) {
      _autoUsedFor = dest;
      // Selepas notifikasi semasa selesai: pintu lalai pengguna terus digunakan.
      scheduleMicrotask(() => use(saved.entrance, label: label));
    }
  }

  /// Kira laluan terus ke [entrance] (tempat asal kekal untuk pilihan pintu lain).
  Future<void> use(Entrance entrance, {String? label}) async {
    final place = state.place;
    if (place == null) return;
    final name = label ?? state.placeLabel;
    state = DoorstepState(place: place, placeLabel: name, selected: entrance);
    await ref
        .read(routePreviewControllerProvider.notifier)
        .planTo(entrance.point, destinationLabel: name);
  }

  /// Kembali ke pin destinasi asal.
  Future<void> usePin() async {
    final place = state.place;
    if (place == null) return;
    state = DoorstepState(place: place, placeLabel: state.placeLabel);
    await ref
        .read(routePreviewControllerProvider.notifier)
        .planTo(place, destinationLabel: state.placeLabel);
  }
}

final doorstepProvider = NotifierProvider<DoorstepController, DoorstepState>(
  DoorstepController.new,
);

/// Bilangan percubaan semula carian pintu OSM bagi setiap tempat (had 3).
final _entranceRetries = <String, int>{};

/// Pintu masuk bagi [place]: pintu lalai pengguna dahulu, kemudian OSM (disusun, terhad).
final entrancesProvider = FutureProvider.autoDispose
    .family<List<Entrance>, GeoPoint>((ref, place) async {
      final saved = ref.watch(
        savedEntrancesProvider.select(
          (list) => list
              .where(
                (s) =>
                    distanceMeters(s.place, place) <=
                    SavedEntrancesController.matchRadiusM,
              )
              .firstOrNull,
        ),
      );
      final osm = await ref.watch(osmEntranceSearchProvider).near(place);
      if (osm == null) {
        // Overpass awam sibuk/luar talian: cuba lagi beberapa kali (makin jarang), bahagian muncul bila
        // berjaya. Pintu lalai pengguna tetap dipaparkan sementara itu.
        final key = '${place.lat},${place.lng}';
        final n = (_entranceRetries[key] ?? 0) + 1;
        _entranceRetries[key] = n;
        if (n <= 3) {
          final timer = Timer(Duration(seconds: 20 * n), ref.invalidateSelf);
          ref.onDispose(timer.cancel);
        }
      }
      final ranked = rankEntrances(osm ?? const [], place);
      if (saved == null) return ranked;
      return [
        saved.entrance,
        for (final e in ranked)
          if (distanceMeters(e.point, saved.point) > 8) e,
      ];
    });
