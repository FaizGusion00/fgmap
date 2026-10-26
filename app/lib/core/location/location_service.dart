import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
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
  Future<LocationFix?> currentFix({Duration timeout});

  /// Aliran fix berketepatan tinggi untuk navigasi (sampel kerap, terus berjalan di latar belakang).
  /// Tidak pernah memaparkan dialog kebenaran. Aliran tamat dengan ralat jika kebenaran ditarik balik.
  Stream<LocationFix> navigationFixes();

  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// Di bawah kelajuan ini, nilai heading peranti tidak boleh dipercayai.
  static const _minSpeedForHeadingMps = 1.0;

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
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (await access() != LocationAccess.granted) return null;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _toFix(position);
    } on Object {
      // Tamat masa atau ralat platform: cuba kedudukan terakhir yang diketahui, tetapi HANYA jika segar.
      // Lokasi lapuk (cth. dari sesi lama atau peranti yang baru dihidupkan) bukan titik mula laluan yang
      // betul; lebih baik jatuh balik kepada pusat peta dan memberitahu pengguna.
      final last = await Geolocator.getLastKnownPosition();
      if (last == null || !isFresh(last.timestamp, DateTime.now())) return null;
      return _toFix(last);
    }
  }

  /// Umur maksimum fix "terakhir diketahui" yang masih boleh dipercayai sebagai lokasi semasa.
  static const maxLastKnownAge = Duration(minutes: 2);

  @visibleForTesting
  static bool isFresh(DateTime timestamp, DateTime now) =>
      now.difference(timestamp) <= maxLastKnownAge;

  @override
  Stream<LocationFix> navigationFixes() {
    return Geolocator.getPositionStream(
      locationSettings: navigationSettings(defaultTargetPlatform),
    ).map(_toFix);
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
            notificationTitle: 'FGMap',
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
  (ref) => const GeolocatorLocationService(),
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
