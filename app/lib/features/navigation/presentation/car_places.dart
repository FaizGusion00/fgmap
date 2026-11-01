import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../local_assistant/domain/intent_router.dart';
import '../../route_preview/presentation/route_format.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../search/data/nearby_search.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/nearby_category.dart';
import '../../search/domain/place.dart';
import '../../search/presentation/nearby_category_label.dart';

/// Carian dan "Berdekatan" untuk skrin kereta (Android Auto dan CarPlay).
///
/// Pemandu bercakap atau menaip ayat biasa ("kedai gunting terdekat", "bawa saya balik rumah",
/// "farmasi"), bukan nama tempat sahaja. Ayat itu melalui penghala arahan yang sama dengan FG AI,
/// jadi kereta dan chat memahami perkara yang sama. Setiap baris dipulangkan sudah siap dipaparkan:
/// jarak dan kawasan digabung dalam `subtitle` supaya Kotlin/Swift tidak perlu memformat apa-apa.
class CarPlaces {
  CarPlaces(this._ref, {this._live});

  final Ref _ref;

  /// Kedudukan navigasi/cruise semasa, jika ada (lebih tepat daripada GPS yang dipinta semula).
  final GeoPoint? Function()? _live;

  /// Kategori mengikut keperluan pemandu. Enam yang pertama dipaparkan ketika memandu (had hos
  /// Android Auto); selebihnya hanya bila kereta berhenti. Setiap kategori ada dalam pengurus ini.
  static const categoryOrder = <NearbyCategory>[
    NearbyCategory.fuel,
    NearbyCategory.food,
    NearbyCategory.mosque,
    NearbyCategory.toilets,
    NearbyCategory.atm,
    NearbyCategory.pharmacy,
    NearbyCategory.evCharging,
    NearbyCategory.hospital,
    NearbyCategory.clinic,
    NearbyCategory.convenience,
    NearbyCategory.parking,
    NearbyCategory.hotel,
    NearbyCategory.barber,
    NearbyCategory.carWash,
    NearbyCategory.workshop,
    NearbyCategory.tyres,
    NearbyCategory.bank,
    NearbyCategory.supermarket,
    NearbyCategory.mall,
    NearbyCategory.laundry,
    NearbyCategory.police,
    NearbyCategory.postOffice,
    NearbyCategory.trainStation,
  ];

  /// Baris maksimum yang dihantar ke hos. Hos kereta sendiri memotong lagi mengikut keadaan memandu.
  static const maxRows = 10;

  /// Bahasa skrin kereta: bahasa peranti (Melayu atau Inggeris), sama seperti teks manuver.
  static AppLocalizations l10nFor(String languageCode) =>
      lookupAppLocalizations(Locale(languageCode == 'ms' ? 'ms' : 'en'));

  AppLocalizations get _l10n =>
      l10nFor(WidgetsBinding.instance.platformDispatcher.locale.languageCode);

  /// Titik asal: kedudukan semasa navigasi/cruise, jika tidak GPS peranti. Skrin kereta dibuka
  /// ketika kereta berhenti (tiada cruise), jadi tanpa GPS ini "Berdekatan" dan memulakan laluan
  /// dari kereta tidak berfungsi.
  Future<GeoPoint?> origin() async {
    final live = _live?.call();
    if (live != null) return live;
    try {
      final service = _ref.read(locationServiceProvider);
      final fix = await service.currentFix(
        timeout: const Duration(seconds: 4),
        maxAccuracyMeters: 500,
        fallbackAccuracyMeters: 5000,
      );
      return (fix ?? await service.lastKnownFix())?.point;
    } on Object {
      return null;
    }
  }

  /// Senarai kategori untuk skrin "Berdekatan": `[{id, label}]`.
  List<Map<String, Object?>> categories() {
    final l10n = _l10n;
    return [
      for (final c in categoryOrder)
        {'id': c.name, 'label': nearbyCategoryLabel(l10n, c)},
    ];
  }

  /// Tempat terdekat bagi kategori [id] (nama enum), tersusun mengikut jarak.
  Future<List<Map<String, Object?>>> nearby(String id) async {
    final category = NearbyCategory.values
        .where((c) => c.name == id)
        .firstOrNull;
    if (category == null) return const [];
    return _nearby(category, _l10n);
  }

  /// Carian bebas daripada skrin kereta (suara atau papan kekunci).
  Future<List<Map<String, Object?>>> search(String text) async {
    final query = text.trim();
    if (query.isEmpty) return const [];
    final l10n = _l10n;
    final intent = parseIntent(query);
    switch (intent) {
      case NearbyIntent(:final category):
        return _nearby(category, l10n);
      case GoSavedPlaceIntent(:final slot):
        final saved = _ref.read(savedPlacesControllerProvider.notifier);
        final target = slot == SavedSlot.home ? saved.home : saved.work;
        if (target != null) {
          final from = await origin();
          final label = slot == SavedSlot.home
              ? l10n.savedHome
              : l10n.savedWork;
          return [_row(target.place, from, l10n, name: label)];
        }
      case RouteIntent(:final destination):
        final found = await _byName(destination, l10n);
        if (found.isNotEmpty) return found;
      case SearchIntent(query: final named):
        final found = await _byName(named, l10n);
        if (found.isNotEmpty) return found;
      default:
        break;
    }
    return _byName(query, l10n);
  }

  Future<List<Map<String, Object?>>> _nearby(
    NearbyCategory category,
    AppLocalizations l10n,
  ) async {
    final from = await origin();
    if (from == null) return const [];
    try {
      final result = await _ref
          .read(nearbySearchProvider)
          .search(
            category,
            from,
            fallbackName: nearbyCategoryLabel(l10n, category),
          )
          .timeout(const Duration(seconds: 15));
      return [for (final p in result.places.take(maxRows)) _row(p, from, l10n)];
    } on Object {
      return const [];
    }
  }

  Future<List<Map<String, Object?>>> _byName(
    String query,
    AppLocalizations l10n,
  ) async {
    final from = await origin();
    try {
      final places = await _ref
          .read(geocoderProvider)
          .search(query, near: from)
          .timeout(const Duration(seconds: 15));
      return [for (final p in places.take(maxRows)) _row(p, from, l10n)];
    } on Object {
      return const [];
    }
  }

  /// Satu baris untuk hos: nama, "jarak · kawasan", koordinat.
  Map<String, Object?> _row(
    Place p,
    GeoPoint? from,
    AppLocalizations l10n, {
    String? name,
  }) {
    final meters = from == null ? null : distanceMeters(from, p.point).round();
    final shown = name ?? p.name;
    final area = p.subtitle.split(',').first.trim();
    final detail = [
      if (meters != null) formatDistance(l10n, meters),
      if (area.isNotEmpty && area != shown) area,
    ].join(' · ');
    return {
      'name': shown,
      'subtitle': detail,
      'lat': p.point.lat,
      'lng': p.point.lng,
    };
  }
}
