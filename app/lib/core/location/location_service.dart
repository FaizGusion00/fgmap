import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/geo.dart';

enum LocationAccess {
  /// Belum diberi, tetapi sistem masih membenarkan kita meminta: sama ada belum pernah diminta atau
  /// ditolak sekali (Android). geolocator tidak membezakan keduanya, jadi UI juga tidak.
  askable,
  granted,

  /// Ditolak kekal; hanya Tetapan sistem boleh mengubahnya.
  deniedForever,
  serviceDisabled,
}

class LocationFix {
  const LocationFix({
    required this.point,
    this.headingDegrees,
    this.accuracyMeters,
    this.speedMps,
    this.timestamp,
  });

  final GeoPoint point;

  /// Arah gerakan 0-359, hanya jika peranti sedang bergerak (arah semasa pegun tidak bermakna).
  final int? headingDegrees;
  final double? accuracyMeters;

  /// Kelajuan (m/s) jika peranti melaporkannya.
  final double? speedMps;

  /// Masa fix diambil oleh peranti; null bermaksud "sekarang".
  final DateTime? timestamp;
}

abstract interface class LocationService {
  /// Keadaan kebenaran semasa. Tidak pernah memaparkan dialog sistem.
  Future<LocationAccess> access();

  /// Memaparkan dialog kebenaran sistem. Panggil hanya selepas penjelasan kepada pengguna.
  Future<LocationAccess> request();

  /// Kedudukan semasa, atau null jika kebenaran tiada / GPS tidak memberi fix dalam [timeout].
  /// Tidak pernah memaparkan dialog kebenaran.
  Future<LocationFix?> currentFix({
    Duration timeout = const Duration(seconds: 8),
    double maxAccuracyMeters = 20,
  });

  /// Kedudukan terakhir yang diketahui peranti, TANPA had umur atau ketepatan, atau null jika
  /// kebenaran tiada / belum pernah ada fix. Pulang serta-merta (tidak menunggu GPS).
  ///
  /// Hanya untuk meletakkan kamera peta di kawasan yang betul semasa pelancaran. Jangan gunakan
  /// sebagai asal laluan: ia boleh lapuk; gunakan [currentFix] untuk itu.
  Future<LocationFix?> lastKnownFix();

  /// Aliran fix berkuasa rendah untuk mengikut pengguna di peta (bukan navigasi): sampel hanya apabila
  /// peranti bergerak >= ~10 m, tanpa notifikasi latar depan, dan berhenti apabila langganan dibatalkan.
  /// Tidak pernah memaparkan dialog kebenaran. Aliran tamat dengan ralat jika kebenaran ditarik balik.
  Stream<LocationFix> trackingFixes();

  /// Aliran fix berketepatan tinggi untuk navigasi (sampel kerap, terus berjalan di latar belakang).
  /// Tidak pernah memaparkan dialog kebenaran. Aliran tamat dengan ralat jika kebenaran ditarik balik.
  Stream<LocationFix> navigationFixes();

  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService();

  /// Di bawah kelajuan ini, nilai heading peranti tidak boleh dipercayai.
  static const _minSpeedForHeadingMps = 1.0;
  static const defaultMaxAccuracyMeters = 20.0;
  LocationFix? _recentFix;

  @override
  Future<LocationAccess> access() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    return _fromPermission(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    return _fromPermission(await Geolocator.requestPermission());
  }

  @override
  Future<LocationFix?> currentFix({
    Duration timeout = const Duration(seconds: 8),
    double maxAccuracyMeters = defaultMaxAccuracyMeters,
  }) async {
    if (await access() != LocationAccess.granted) return null;
    final now = DateTime.now();
    final recent = _recentFix;
    if (recent != null &&
        isUsableFix(recent, now, maxAccuracyMeters: maxAccuracyMeters)) {
      return recent;
    }

    // Lokasi cache yang masih segar dan tepat boleh digunakan terus. Tunggu GPS baharu hanya
    // apabila cache tiada atau tidak memenuhi syarat, supaya mula merancang tidak terasa lambat.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final cached = _toFix(last);
      if (isUsableFix(
        cached,
        DateTime.now(),
        maxAccuracyMeters: maxAccuracyMeters,
      )) {
        _recentFix = cached;
        return cached;
      }
    }

    final current = await _awaitAccurateFix(
      timeout: timeout,
      maxAccuracyMeters: maxAccuracyMeters,
    );
    if (current != null) return current;

    return null;
  }

  @override
  Future<LocationFix?> lastKnownFix() async {
    if (await access() != LocationAccess.granted) return null;
    final recent = _recentFix;
    if (recent != null) return recent;
    try {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : _toFix(last);
    } on Object {
      return null; // platform tidak menyokong / ralat sementara: pelancaran jatuh balik ke currentFix
    }
  }

  Future<LocationFix?> _awaitAccurateFix({
    required Duration timeout,
    required double maxAccuracyMeters,
  }) async {
    final result = Completer<LocationFix?>();
    StreamSubscription<Position>? subscription;
    final timer = Timer(timeout, () {
      if (!result.isCompleted) result.complete(null);
    });

    try {
      subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 0,
            ),
          ).listen(
            (position) {
              final fix = _toFix(position);
              final usable = isUsableFix(
                fix,
                DateTime.now(),
                maxAccuracyMeters: maxAccuracyMeters,
              );
              if (usable) _recentFix = fix;
              if (usable && !result.isCompleted) {
                result.complete(fix);
              }
            },
            onError: (Object error) {
              debugPrint('GPS acquisition failed: $error');
              if (!result.isCompleted) result.complete(null);
            },
          );
    } on Object catch (error) {
      debugPrint('GPS acquisition failed: $error');
      if (!result.isCompleted) result.complete(null);
    }

    try {
      return await result.future;
    } finally {
      timer.cancel();
      await subscription?.cancel();
    }
  }

  /// Umur maksimum fix yang masih boleh dipercayai sebagai lokasi semasa.
  static const maxLastKnownAge = Duration(seconds: 10);

  @visibleForTesting
  static bool isFresh(DateTime timestamp, DateTime now) {
    final age = now.difference(timestamp);
    return !age.isNegative && age <= maxLastKnownAge;
  }

  @visibleForTesting
  static bool isUsableFix(
    LocationFix fix,
    DateTime now, {
    double maxAccuracyMeters = defaultMaxAccuracyMeters,
  }) {
    final point = fix.point;
    final accuracy = fix.accuracyMeters;
    final time = fix.timestamp;
    return point.lat.isFinite &&
        point.lng.isFinite &&
        point.lat >= -90 &&
        point.lat <= 90 &&
        point.lng >= -180 &&
        point.lng <= 180 &&
        accuracy != null &&
        accuracy.isFinite &&
        accuracy >= 0 &&
        accuracy <= maxAccuracyMeters &&
        time != null &&
        isFresh(time, now);
  }

  @override
  Stream<LocationFix> trackingFixes() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map(_toFix);
  }

  @override
  Stream<LocationFix> navigationFixes() {
    return Geolocator.getPositionStream(
      locationSettings: navigationSettings(defaultTargetPlatform),
    ).map((position) {
      final fix = _toFix(position);
      if (isUsableFix(fix, DateTime.now())) _recentFix = fix;
      return fix;
    });
  }

  /// Tetapan aliran navigasi: ketepatan tertinggi, tiada penapis jarak, dan kekal hidup apabila app
  /// di latar belakang (notifikasi latar depan di Android; mod navigasi automotif di iOS).
  @visibleForTesting
  static LocationSettings navigationSettings(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'FGMaps',
            notificationText: 'Navigasi sedang berjalan',
            notificationChannelName: 'Navigasi',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static LocationAccess _fromPermission(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccess.granted;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.askable;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
    }
  }

  static LocationFix _toFix(Position p) {
    final moving = p.speed >= _minSpeedForHeadingMps && p.heading >= 0;
    return LocationFix(
      point: GeoPoint(p.latitude, p.longitude),
      headingDegrees: moving ? p.heading.round() % 360 : null,
      accuracyMeters: p.accuracy,
      speedMps: p.speed >= 0 ? p.speed : null,
      timestamp: p.timestamp,
    );
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

/// Keadaan kebenaran lokasi untuk UI; dimuat semula selepas permintaan dan bila app kembali aktif.
class LocationAccessController extends Notifier<LocationAccess> {
  @override
  LocationAccess build() {
    refresh();
    return LocationAccess.askable;
  }

  Future<void> refresh() async {
    final result = await ref.read(locationServiceProvider).access();
    if (ref.mounted) state = result;
  }

  Future<LocationAccess> request() async {
    final result = await ref.read(locationServiceProvider).request();
    if (ref.mounted) state = result;
    return result;
  }
}

final locationAccessProvider =
    NotifierProvider<LocationAccessController, LocationAccess>(
      LocationAccessController.new,
    );
