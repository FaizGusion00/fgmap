import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/location/location_service.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/log.dart';
import '../navigation/presentation/navigation_controller.dart';
import '../route_preview/data/route_planner.dart';
import '../route_preview/domain/route_option.dart';
import '../saved_places/data/saved_places_controller.dart';
import '../saved_places/domain/saved_place.dart';
import 'eta_widget_payload.dart';

/// Penerima muatan widget (home_widget di produksi; palsu dalam ujian).
abstract interface class EtaWidgetSink {
  Future<void> publish(EtaWidgetPayload payload);
}

/// Menulis ke storan widget dan meminta widget dilukis semula. Gagal senyap jika platform tiada
/// widget (desktop/ujian) atau pelancar belum menambah widget.
class HomeWidgetSink implements EtaWidgetSink {
  const HomeWidgetSink();

  /// Nama kelas penuh pembekal Android (`EtaWidgetProvider.kt`).
  static const androidProvider =
      'com.fguniversalempire.fgmaps.widget.EtaWidgetProvider';

  /// `kind` widget WidgetKit (stub: ios/EtaWidget/EtaWidget.swift).
  static const iosKind = 'FgmapEtaWidget';

  /// App Group iOS yang dikongsi app dan sambungan widget (perlu didaftarkan dalam Xcode).
  static const appGroupId = 'group.com.fguniversalempire.fgmaps';

  @override
  Future<void> publish(EtaWidgetPayload payload) async {
    final platform = defaultTargetPlatform;
    if (kIsWeb ||
        (platform != TargetPlatform.android &&
            platform != TargetPlatform.iOS)) {
      return;
    }
    try {
      if (platform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      for (final entry in payload.toMap().entries) {
        await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iosKind,
      );
    } on MissingPluginException {
      // Tiada pemalam (ujian / platform lain).
    } on Object catch (error) {
      // PlatformException dll.: widget ialah tambahan, jangan ganggu app.
      logDiag('EtaWidget: gagal kemas kini widget: $error');
    }
  }
}

/// Mengira ETA Rumah/Kerja untuk widget. Polisi bateri (ADR 0013):
/// - tiada pemasa, tiada strim GPS: hanya fix terakhir yang sudah ada (`lastKnownFix`);
/// - dipanggil ketika app diteruskan (resume) atau Rumah/Kerja berubah, dengan had [minInterval];
/// - paling banyak dua permintaan laluan sekali jalan (tamat masa [routeTimeout]), lalu jatuh balik
///   ke anggaran jarak; tiada kerja semasa navigasi aktif.
class EtaWidgetUpdater {
  EtaWidgetUpdater({
    required this.savedPlaces,
    required this.lastKnownPoint,
    required this.planner,
    required this.sink,
    required this.vehicle,
    required this.navigating,
    required this.languageCode,
    DateTime Function()? clock,
    this.minInterval = const Duration(minutes: 15),
    this.routeTimeout = const Duration(seconds: 6),
  }) : _clock = clock ?? DateTime.now;

  final List<SavedPlace> Function() savedPlaces;
  final Future<GeoPoint?> Function() lastKnownPoint;
  final RoutePlanner Function() planner;
  final EtaWidgetSink sink;
  final RouteVehicle Function() vehicle;
  final bool Function() navigating;
  final String Function() languageCode;
  final DateTime Function() _clock;
  final Duration minInterval;
  final Duration routeTimeout;

  /// Anggaran bila laluan tidak tersedia: faktor lencongan jalan dan purata laju bandar.
  static const detourFactor = 1.3;
  static const fallbackSpeedMps = 40 / 3.6;

  /// Lebih jauh daripada ini, jangan minta laluan (tidak murah); terus anggaran jarak.
  static const maxRoutedDistanceM = 150000.0;

  /// Dalam jarak ini dianggap sudah sampai.
  static const hereRadiusM = 150.0;

  DateTime? _lastRun;
  String? _lastSignature;
  EtaWidgetPayload? _lastPayload;
  bool _inFlight = false;

  /// Kemas kini widget. [force] mengabaikan had masa (Rumah/Kerja baru ditukar).
  Future<void> refresh({bool force = false}) async {
    if (_inFlight || navigating()) return;
    final now = _clock();
    final places = savedPlaces();
    final home = _find(places, SavedKind.home);
    final work = _find(places, SavedKind.work);
    final signature = _signature(home, work);
    final changed = signature != _lastSignature;
    final last = _lastRun;
    if (!force &&
        !changed &&
        last != null &&
        now.difference(last) < minInterval) {
      return;
    }
    _inFlight = true;
    try {
      final text = EtaWidgetText.forLanguage(languageCode());
      final origin = home == null && work == null
          ? null
          : await lastKnownPoint();
      final payload = EtaWidgetPayload(
        home: await _row(text.homeLabel, home, origin, text),
        work: await _row(text.workLabel, work, origin, text),
        updatedAt: now,
      );
      _lastRun = now;
      _lastSignature = signature;
      // Elak lukis semula widget jika kandungan sama.
      if (_lastPayload != null && _sameContent(_lastPayload!, payload)) return;
      _lastPayload = payload;
      await sink.publish(payload);
    } on Object catch (error) {
      // Widget ialah tambahan: jangan sekali-kali ganggu app.
      logDiag('EtaWidget: refresh gagal: $error');
    } finally {
      _inFlight = false;
    }
  }

  Future<EtaWidgetRow> _row(
    String label,
    SavedPlace? place,
    GeoPoint? origin,
    EtaWidgetText text,
  ) async {
    if (place == null) return EtaWidgetRow.unset(label: label, cta: text.cta);
    if (origin == null) {
      return EtaWidgetRow(label: label, value: '—', isSet: true);
    }
    final destination = place.place.point;
    final distance = distanceMeters(origin, destination);
    if (distance < hereRadiusM) {
      return EtaWidgetRow(label: label, value: text.here, isSet: true);
    }
    final routed = distance <= maxRoutedDistanceM
        ? await _routedSeconds(origin, destination)
        : null;
    final value = routed != null
        ? text.duration(routed)
        : text.duration(
            (distance * detourFactor / fallbackSpeedMps).round(),
            approximate: true,
          );
    return EtaWidgetRow(label: label, value: value, isSet: true);
  }

  Future<int?> _routedSeconds(GeoPoint origin, GeoPoint destination) async {
    try {
      final options = await planner()
          .plan(
            RouteQuery(
              origin: origin,
              destination: destination,
              vehicle: vehicle(),
              alternates: 0,
            ),
          )
          .timeout(routeTimeout);
      if (options.isEmpty) return null;
      return options.first.durationS;
    } on Object {
      // Rangkaian / enjin offline / tamat masa: guna anggaran jarak.
      return null;
    }
  }

  static SavedPlace? _find(List<SavedPlace> places, SavedKind kind) {
    for (final p in places) {
      if (p.kind == kind) return p;
    }
    return null;
  }

  static String _signature(SavedPlace? home, SavedPlace? work) {
    String one(SavedPlace? p) => p == null
        ? '-'
        : '${p.place.point.lat.toStringAsFixed(5)},${p.place.point.lng.toStringAsFixed(5)}';
    return '${one(home)}|${one(work)}';
  }

  static bool _sameContent(EtaWidgetPayload a, EtaWidgetPayload b) =>
      a.home == b.home && a.work == b.work;
}

/// Pengemas kini widget. Dipanggil dari `map_screen` apabila app diteruskan, dan secara automatik
/// apabila Rumah/Kerja ditukar.
final etaWidgetUpdaterProvider = Provider<EtaWidgetUpdater>((ref) {
  final updater = EtaWidgetUpdater(
    savedPlaces: () => ref.read(savedPlacesControllerProvider),
    lastKnownPoint: () async =>
        (await ref.read(locationServiceProvider).lastKnownFix())?.point,
    planner: () => ref.read(routePlannerProvider),
    sink: const HomeWidgetSink(),
    vehicle: () => ref.read(routeVehicleProvider),
    navigating: () => ref.read(navigationControllerProvider).isActive,
    languageCode: () =>
        WidgetsBinding.instance.platformDispatcher.locale.languageCode,
  );
  ref.listen(savedPlacesControllerProvider, (prev, next) {
    unawaited(updater.refresh());
  });
  return updater;
});
