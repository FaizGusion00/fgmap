import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../navigation/domain/camera_planner.dart' show CameraPose;
import 'maplibre_view.dart';
import 'user_location.dart';

/// Kawalan kamera yang didedahkan oleh pandangan peta kepada skrin. Antara muka (bukan kelas
/// MapLibre) supaya skrin boleh diuji dengan peta palsu.
abstract interface class MapCameraController {
  /// Pusat peta semasa, atau null jika peta belum bersedia.
  GeoPoint? get center;

  Future<void> flyTo(GeoPoint target, {double zoom});

  /// Laraskan zum kamera tanpa menukar pusat peta.
  Future<void> zoomBy(double amount);

  /// Muatkan semua [points] dalam pandangan, dengan ruang tambahan [padding] (piksel logikal)
  /// untuk elemen UI yang menutup peta, cth. lembaran bawah.
  Future<void> fitTo(List<GeoPoint> points, {EdgeInsets padding});

  /// Pose kamera semasa (pusat, zum, condongan, arah), atau null jika peta belum bersedia.
  CameraPose? get pose;

  /// Memindahkan kamera serta-merta tanpa animasi. Dipanggil setiap bingkai semasa navigasi, jadi
  /// pelaksana patut menggabungkan panggilan: hanya satu berjalan, dan yang terkini dihantar selepas
  /// itu (jangan gugurkan nilai terakhir).
  void moveTo(CameraPose pose);

  /// Beralih ke [pose] dengan animasi lembut (cth. kembali ke peta 2D selepas navigasi). Tidak
  /// digugurkan seperti [moveTo].
  Future<void> animateTo(CameraPose pose);

  /// Menetapkan kedudukan dan arah marker kenderaan (null = sembunyikan).
  void showVehicle(VehicleMarker? marker);
}

@immutable
class VehicleMarker {
  const VehicleMarker({required this.point, required this.bearing});

  final GeoPoint point;
  final double bearing;
}

@immutable
class MapRouteLine {
  const MapRouteLine({required this.points, required this.isMain});

  final List<GeoPoint> points;
  final bool isMain;
}

/// Warna lapisan overlay di peta, dibaca daripada tema (bukan hard-code dalam pandangan peta).
@immutable
class MapOverlayColors {
  const MapOverlayColors({
    required this.mainRoute,
    required this.routeCasing,
    required this.alternativeRoute,
    required this.destination,
    this.vehicle = const Color(0xFF2F6BFF),
  });

  final Color vehicle;
  final Color mainRoute;
  final Color routeCasing;
  final Color alternativeRoute;
  final Color destination;

  @override
  bool operator ==(Object other) =>
      other is MapOverlayColors &&
      other.mainRoute == mainRoute &&
      other.routeCasing == routeCasing &&
      other.alternativeRoute == alternativeRoute &&
      other.destination == destination &&
      other.vehicle == vehicle;

  @override
  int get hashCode => Object.hash(
    mainRoute,
    routeCasing,
    alternativeRoute,
    destination,
    vehicle,
  );
}

@immutable
class MapViewConfig {
  const MapViewConfig({
    required this.styleUrl,
    required this.initialCenter,
    required this.initialZoom,
    required this.routes,
    required this.destination,
    required this.showUserLocation,
    required this.colors,
    required this.onLongPress,
    required this.onReady,
    this.userLocation,
    this.showCompass = true,
    this.onUserGesture,
    this.onTap,
  });

  final String styleUrl;
  final GeoPoint initialCenter;
  final double initialZoom;
  final List<MapRouteLine> routes;
  final GeoPoint? destination;
  final bool showUserLocation;

  /// Kedudukan pengguna yang telah ditapis untuk titik lokasi. Titik lokasi peta disuap daripadanya
  /// (bukan enjin GPS asli peta yang berasingan) supaya titik dan kamera "ikut saya" tidak berselisih.
  /// Null = tiada kedudukan untuk dipaparkan.
  final ValueListenable<UserLocation?>? userLocation;

  /// Butang kompas asli peta. Dimatikan semasa navigasi: ia muncul dan hilang setiap kali arah peta
  /// melintasi utara dan kelihatan berkelip.
  final bool showCompass;
  final MapOverlayColors colors;
  final ValueChanged<GeoPoint> onLongPress;

  /// Ketikan pada peta (cth. memilih laluan alternatif). Null = tidak dipantau.
  final ValueChanged<GeoPoint>? onTap;
  final ValueChanged<MapCameraController> onReady;

  /// Dipanggil apabila pengguna menyentuh dan menggerakkan peta (cth. semasa navigasi, untuk
  /// berhenti mengikut kenderaan). Null = tidak dipantau.
  final VoidCallback? onUserGesture;
}

typedef MapViewBuilder =
    Widget Function(BuildContext context, MapViewConfig config);

/// Pembina pandangan peta. Ujian meng-override ini dengan peta palsu.
final mapViewBuilderProvider = Provider<MapViewBuilder>(
  (ref) =>
      (context, config) => MapLibreView(config: config),
);
