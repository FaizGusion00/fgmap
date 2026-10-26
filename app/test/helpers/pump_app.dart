import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:fgmap/features/map/presentation/map_view.dart';
import 'package:fgmap/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Saiz skrin telefon biasa (iPhone 14) pada DPR 3.
const phoneSize = Size(390, 844);

void usePhoneSurface(WidgetTester tester, {Size size = phoneSize}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Mematikan animasi seperti "Reduce Motion" sistem: kilau skeleton berhenti dan tempoh gerakan
/// menjadi sifar, supaya `pumpAndSettle` boleh selesai.
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  ThemeData? theme,
  Locale locale = const Locale('ms'),
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
}

/// Memuatkan fon sebenar untuk golden: Plus Jakarta Sans (teks) dan MaterialIcons (ikon).
/// Tanpa ini teks dirender dengan Ahem (kotak lebar) dan ikon sebagai segi empat kosong.
///
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader(
    'PlusJakartaSans',
  )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

/// Menjalankan [body] dengan bayang-bayang dihidupkan, untuk golden. Secara lalai flutter_test
/// mematikannya dan melukis bentuk hitam pekat, yang bukan rupa app sebenar. Golden hanya
/// dijalankan pada satu platform (macOS) jadi perbezaan render bayang antara platform tidak
/// menjadi masalah.
///
/// Pembolehubah mesti dipulihkan dalam badan ujian (try/finally), bukan addTearDown: rangka kerja
/// menyemak invarian sebelum teardown berjalan.
Future<void> withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

class FakeCamera implements MapCameraController {
  @override
  GeoPoint? center = const GeoPoint(3.139, 101.687);

  final List<(GeoPoint, double)> flyToCalls = [];
  final List<double> zoomByCalls = [];
  final List<(List<GeoPoint>, EdgeInsets)> fitToCalls = [];
  final List<CameraPose> moveToCalls = [];
  final List<VehicleMarker?> vehicleCalls = [];

  @override
  CameraPose? pose = const CameraPose(
    center: GeoPoint(3.139, 101.687),
    zoom: 11,
    tilt: 0,
    bearing: 0,
  );

  @override
  void moveTo(CameraPose p) {
    moveToCalls.add(p);
    pose = p;
  }

  final List<CameraPose> animateToCalls = [];

  @override
  Future<void> animateTo(CameraPose p) async {
    animateToCalls.add(p);
    pose = p;
  }

  @override
  void showVehicle(VehicleMarker? marker) => vehicleCalls.add(marker);

  /// Pengganti unjuran peta sebenar; null (lalai) = tidak diketahui.
  Offset? Function(GeoPoint point)? screenPoint;
  int screenPointCalls = 0;

  @override
  Future<Offset?> screenPointOf(GeoPoint point) async {
    screenPointCalls++;
    return screenPoint?.call(point);
  }

  @override
  Future<void> flyTo(GeoPoint target, {double zoom = 15}) async =>
      flyToCalls.add((target, zoom));

  @override
  Future<void> zoomBy(double amount) async {
    zoomByCalls.add(amount);
    final current = pose;
    if (current != null) {
      pose = CameraPose(
        center: current.center,
        zoom: current.zoom + amount,
        tilt: current.tilt,
        bearing: current.bearing,
      );
    }
  }

  @override
  Future<void> fitTo(
    List<GeoPoint> points, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async => fitToCalls.add((points, padding));
}

/// Pengganti pandangan peta: merekod konfigurasi terkini dan membolehkan ujian memicu long-press.
class FakeMapHarness {
  final camera = FakeCamera();
  MapViewConfig? config;
  bool _announced = false;

  Widget build(BuildContext context, MapViewConfig cfg) {
    config = cfg;
    if (!_announced) {
      _announced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => cfg.onReady(camera));
    }
    return const ColoredBox(key: ValueKey('fake-map'), color: Colors.blueGrey);
  }

  Override get override => mapViewBuilderProvider.overrideWithValue(build);
}
