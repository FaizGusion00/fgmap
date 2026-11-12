import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../map/data/map_layer.dart';
import '../../music/presentation/player_controller.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_sheet.dart' show reportTypeLabel;
import '../../reports/presentation/reports_controller.dart';
import '../../route_preview/data/route_planner.dart';
import '../../route_preview/data/toll_finder.dart';
import '../../route_preview/domain/route_option.dart';
import '../../route_preview/domain/toll.dart';
import '../../route_preview/presentation/route_format.dart';
import '../../route_preview/presentation/route_summary_sheet.dart'
    show routeLabelText;
import '../../saved_places/data/saved_places_controller.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../search/domain/place.dart';
import '../../search/presentation/search_history_controller.dart';
import '../data/navigation_settings.dart';
import '../domain/instruction_text.dart' show VoiceLanguage;
import 'car_places.dart';
import 'navigation_controller.dart';

/// Ciri app telefon yang dibawa ke skrin kereta (Android Auto), selain carian dan "Berdekatan":
/// Tempat (Rumah, Kerja, kegemaran, terkini), pilihan laluan sebelum mula (masa, jarak, tol),
/// laporan jalan satu ketukan, tetapan ringkas dan muzik.
///
/// Setiap jawapan sudah siap dipaparkan (teks mengikut bahasa peranti), jadi Kotlin hanya menyusun
/// templat. Ciri yang Google larang di skrin kereta (chat AI, kiblat, muat turun peta) sengaja tiada.
class CarActions {
  CarActions(this._ref, this._places, {required this.heading});

  final Ref _ref;
  final CarPlaces _places;

  /// Arah pergerakan semasa (darjah), supaya laluan dari kereta yang bergerak tidak bermula ke belakang.
  final int? Function() heading;

  AppLocalizations get _l10n => CarPlaces.l10nFor(
    WidgetsBinding.instance.platformDispatcher.locale.languageCode,
  );

  // ---------------------------------------------------------------- Tempat

  /// Hab "Tempat": `{home, work, favorites, recents}`. Rumah/Kerja null jika belum ditetapkan.
  Future<Map<String, Object?>> places() async {
    final l10n = _l10n;
    final saved = _ref.read(savedPlacesControllerProvider.notifier);
    final from = await _places.origin();
    Map<String, Object?>? slot(SavedPlace? s, String label) =>
        s == null ? null : _places.row(s.place, from, l10n, name: label);
    final favorites = [
      for (final f in saved.favorites.take(CarPlaces.maxRows))
        _places.row(f.place, from, l10n),
    ];
    // Terkini: carian terakhir di telefon, tanpa pendua Rumah/Kerja.
    final homeId = saved.home?.place.point;
    final workId = saved.work?.place.point;
    final recents = [
      for (final p
          in _ref
              .read(searchHistoryControllerProvider)
              .where((p) => p.point != homeId && p.point != workId)
              .take(CarPlaces.maxRows))
        _places.row(p, from, l10n),
    ];
    return {
      'home': slot(saved.home, l10n.savedHome),
      'work': slot(saved.work, l10n.savedWork),
      'favorites': favorites,
      'recents': recents,
    };
  }

  // ---------------------------------------------------------------- Pilihan laluan

  RouteQuery? _previewQuery;
  List<RouteOption> _previewRoutes = const [];
  List<double?> _previewTolls = const [];
  int _previewToken = 0;

  /// Pilihan laluan ke [place] untuk templat pratonton laluan kereta. Setiap pilihan:
  /// `{durationS, distanceM, title, detail, points}`; `points` ialah garisan ringkas untuk peta kereta.
  ///
  /// Ralat dilempar sebagai [CarPlacesFailure] (`no-location` / `no-route`) supaya kereta tahu sebabnya.
  Future<List<Map<String, Object?>>> preview(Place place) async {
    final token = ++_previewToken;
    final origin = await _places.origin();
    if (origin == null) {
      throw const CarPlacesFailure(CarPlacesFailure.noLocation);
    }
    final query = RouteQuery(
      origin: origin,
      destination: place.point,
      headingDegrees: heading(),
      vehicle: _ref.read(routeVehicleProvider),
      avoidTolls: _ref.read(routeTollFilterProvider) == RouteTollFilter.noTolls,
      destinationLabel: place.name,
      destinationRadiusM: place.routingRadiusM,
    );
    List<RouteOption> options;
    try {
      options = await _ref
          .read(routeOptionsPlannerProvider)
          .plan(query)
          .timeout(const Duration(seconds: 25));
    } on Object {
      throw const CarPlacesFailure(CarActions.noRoute);
    }
    if (options.isEmpty) throw const CarPlacesFailure(CarActions.noRoute);
    // "Tanpa tol" dipilih di telefon: laluan tanpa tol didahulukan, bukan dibuang.
    if (query.avoidTolls) {
      options = [
        ...options.where((o) => !o.hasTolls),
        ...options.where((o) => o.hasTolls),
      ];
    }
    options = options.take(3).toList();
    final tolls = await Future.wait([
      for (final o in options) _tollRm(o, query.vehicle),
    ]);
    // Pratonton lebih baharu bermula semasa menunggu: jangan timpa pilihan yang sedang dipaparkan.
    if (token != _previewToken) {
      throw const CarPlacesFailure(CarPlacesFailure.failed);
    }
    _previewQuery = query;
    _previewRoutes = options;
    _previewTolls = [for (final t in tolls) t?.$1];
    final l10n = _l10n;
    return [
      for (var i = 0; i < options.length; i++)
        _routeRow(options[i], tolls[i], l10n),
    ];
  }

  Map<String, Object?> _routeRow(
    RouteOption o,
    (double, bool)? toll,
    AppLocalizations l10n,
  ) {
    final detail = [
      formatDistance(l10n, o.distanceM),
      _tollText(l10n, o, toll),
    ].join(' · ');
    return {
      'durationS': o.durationS,
      'distanceM': o.distanceM,
      'title': routeLabelText(l10n, o.label),
      'detail': detail,
      'points': [
        for (final p in _thin(o.points)) [p.lat, p.lng],
      ],
    };
  }

  /// "RM 12.40", "RM 12.40+" atau "Ada tol"/"Tiada tol" bila harga tidak diketahui (sama seperti telefon).
  static String _tollText(
    AppLocalizations l10n,
    RouteOption option,
    (double, bool)? toll,
  ) {
    if (!option.hasTolls) return l10n.routeNoTolls;
    if (toll == null || toll.$1 <= 0) return l10n.routeHasTolls;
    final amount = NumberFormat.decimalPatternDigits(
      locale: l10n.localeName,
      decimalDigits: 2,
    ).format(toll.$1);
    return toll.$2 ? l10n.routeTollRm(amount) : l10n.routeTollRmPartial(amount);
  }

  /// Anggaran tol (RM, tepat?) atau null bila tiada tol / harga tidak diketahui. Tidak pernah melambatkan
  /// pratonton lebih daripada 3 s.
  Future<(double, bool)?> _tollRm(
    RouteOption option,
    RouteVehicle vehicle,
  ) async {
    if (!option.hasTolls) return null;
    try {
      final rates = await _ref
          .read(tollRatesProvider.future)
          .timeout(const Duration(seconds: 3));
      final plazas = await DatasetTollFinder(
        () async => rates,
      ).find(option).timeout(const Duration(seconds: 3));
      if (plazas.isEmpty) return null;
      final TollEstimate e = rates.estimate(plazas, vehicle, route: option);
      if (e.knownRm <= 0) return null;
      return (e.knownRm, e.isExact);
    } on Object {
      return null;
    }
  }

  /// Garisan pratonton ringan untuk hos kereta: paling banyak ~400 titik.
  static List<GeoPoint> _thin(List<GeoPoint> points) {
    const cap = 400;
    if (points.length <= cap) return points;
    final step = points.length / cap;
    return [
      for (var i = 0.0; i < points.length - 1; i += step) points[i.floor()],
      points.last,
    ];
  }

  /// Mula navigasi dengan pilihan [index] daripada [preview] terakhir.
  Future<String?> startPreview(int index) async {
    final query = _previewQuery;
    if (query == null || index < 0 || index >= _previewRoutes.length) {
      return noRoute;
    }
    final language = VoiceLanguage.fromCode(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    try {
      final ok = await _ref
          .read(navigationControllerProvider.notifier)
          .start(
            _previewRoutes[index],
            query,
            uiLanguage: language,
            tollRm: _previewTolls[index],
          );
      if (!ok) return noRoute;
    } on Object {
      return noRoute;
    }
    _previewQuery = null;
    _previewRoutes = const [];
    _previewTolls = const [];
    return null;
  }

  static const noRoute = 'no-route';

  // ---------------------------------------------------------------- Laporan

  /// Jenis laporan untuk grid kereta: `[{id, label}]`, susunan sama seperti telefon.
  List<Map<String, Object?>> reportTypes() {
    final l10n = _l10n;
    return [
      for (final t in ReportType.values)
        {'id': t.id, 'label': reportTypeLabel(l10n, t)},
    ];
  }

  /// Hantar laporan [id] di kedudukan semasa. Pulangkan `created`, `confirmed`, `no-location` atau
  /// `failed`.
  Future<String> report(String id) async {
    final type = ReportType.fromId(id);
    if (type == null) return 'failed';
    try {
      final result = await _ref
          .read(reportsControllerProvider.notifier)
          .report(type)
          .timeout(const Duration(seconds: 15));
      return switch (result) {
        CreateReportResult.created => 'created',
        CreateReportResult.confirmedExisting => 'confirmed',
        CreateReportResult.noLocation => CarPlacesFailure.noLocation,
      };
    } on Object {
      return 'failed';
    }
  }

  // ---------------------------------------------------------------- Tetapan

  /// Tetapan yang selamat diubah di skrin kereta: `{voice, avoidTolls, cameras, satellite}`.
  Map<String, Object?> settings() {
    final nav = _ref.read(navigationSettingsProvider);
    return {
      'voice': nav.voiceEnabled,
      'avoidTolls':
          _ref.read(routeTollFilterProvider) == RouteTollFilter.noTolls,
      'cameras': nav.speedCameraAlerts,
      'satellite': _ref.read(mapLayerProvider) == MapLayer.satellite,
    };
  }

  Future<Map<String, Object?>> setSetting(String key, bool value) async {
    final nav = _ref.read(navigationSettingsProvider.notifier);
    switch (key) {
      case 'voice':
        await nav.setVoiceEnabled(value);
      case 'avoidTolls':
        await _ref
            .read(routeTollFilterProvider.notifier)
            .set(value ? RouteTollFilter.noTolls : RouteTollFilter.any);
      case 'cameras':
        await nav.setSpeedCameraAlerts(value);
      case 'satellite':
        await _ref
            .read(mapLayerProvider.notifier)
            .set(value ? MapLayer.satellite : MapLayer.standard);
    }
    return settings();
  }

  // ---------------------------------------------------------------- Muzik

  /// Android Auto membuka bahagian media FGMaps: mulakan perkhidmatan audio supaya senarai lagu dan
  /// radio dijawab (dahulu ia hanya bermula bila lagu pertama dimain di telefon).
  Future<void> startMedia() async {
    try {
      await _ref.read(playerControllerProvider.notifier).ensureMediaService();
    } on Object {
      // Muzik tidak tersedia: bahagian media kereta kosong, navigasi tidak terjejas.
    }
  }
}
