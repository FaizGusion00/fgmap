import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/geo.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_icon.dart';
import '../../navigation/domain/camera_planner.dart' show CameraPose;
import 'map_frame_pump.dart';
import 'map_view.dart';
import 'nav_route_line.dart';
import 'vehicle_icon.dart';
import '../../../core/utils/log.dart';

const _altSource = 'fg-route-alt-src';
const _mainSource = 'fg-route-main-src';
const _destSource = 'fg-destination-src';
const _legSource = 'fg-route-leg-src';
const _legLayer = 'fg-route-leg';
const _vehicleSource = 'fg-vehicle-src';
const _reportSource = 'fg-reports-src';
const _reportLayer = 'fg-reports';
const _vehicleLayer = 'fg-vehicle';
const _vehicleImage = 'fg-vehicle-icon';
const _altLayer = 'fg-route-alt';
const _casingLayer = 'fg-route-casing';
const _mainLayer = 'fg-route-main';
// Keping laluan navigasi selepas keping semasa: dilukis penuh (tanpa gradient). Lihat NavRouteLine.chunkM.
const _casingFarLayer = 'fg-route-casing-far';
const _mainFarLayer = 'fg-route-main-far';
const _destLayer = 'fg-destination';

const _emptyCollection = <String, dynamic>{
  'type': 'FeatureCollection',
  'features': <dynamic>[],
};

/// Pandangan peta MapLibre. Semua pengetahuan tentang `maplibre_gl` tertumpu di sini; selebihnya
/// bercakap dengan [MapViewConfig] dan [MapCameraController].
class MapLibreView extends StatefulWidget {
  const MapLibreView({super.key, required this.config});

  final MapViewConfig config;

  @override
  State<MapLibreView> createState() => _MapLibreViewState();
}

class _MapLibreViewState extends State<MapLibreView> {
  MapLibreMapController? _controller;
  late final String _initialStyleUrl;
  late String _activeStyleUrl;

  /// Benar selepas sumber dan lapisan overlay ditambah pada gaya semasa. Menukar gaya (cerah/gelap)
  /// membuang semuanya, jadi ia diset semula dan dibina semula bila gaya baharu siap dimuatkan.
  bool _overlaysReady = false;

  /// Operasi overlay dijalankan satu demi satu; panggilan platform tak segerak tidak boleh bertindih.
  Future<void> _queue = Future.value();

  /// Marker kenderaan dan gerakan kamera dikemas kini 60 kali sesaat semasa navigasi. Pam ini
  /// menghantarnya satu demi satu (nilai terkini menang, tiada yang digugurkan) dan serentak.
  late final MapFramePump _pump = MapFramePump(
    sendVehicle: _sendVehicle,
    sendCamera: _sendCamera,
  );
  double _pixelRatio = 1;
  double _gestureTravel = 0;
  bool _gestureReported = false;

  // Data terakhir yang SUDAH dihantar ke setiap sumber, supaya hanya yang berubah ditulis semula.
  // Dahulu satu perubahan kecil (cth. laluan baki bertambah pendek setiap 15 m) menulis semula ketiga-tiga
  // sumber, termasuk yang kosong, dan setiap tulisan menyebabkan peta menjana jubin semula.
  List<MapRouteLine> _sentAlt = const [];
  List<MapRouteLine> _sentMain = const [];
  GeoPoint? _sentDestination;
  List<MapReport> _sentReports = const [];
  List<GeoPoint> _sentLeg = const [];

  // Pemangkasan laluan navigasi. `line-gradient` memangkas bahagian yang telah dilalui tanpa menjana
  // semula geometri; jika platform menolaknya, jatuh balik ke menghantar baki laluan (jarang-jarang).
  bool _gradientOk = true;
  NavRouteLine? _sentNav;
  double? _trimAlong;
  int? _trimChunk;
  bool _trimQueued = false;

  /// Titik lokasi asli peta bertukar kelabu ("lapuk") jika tiada kemas kini selama 30 saat. Pengguna
  /// yang pegun memang tidak menerima fix baharu (penapis jarak), jadi kedudukan semasa dihantar semula
  /// secara berkala supaya titik kekal berwarna selagi kedudukannya sah.
  Timer? _userLocationHeartbeat;
  static const _userLocationHeartbeatEvery = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _initialStyleUrl = widget.config.styleUrl;
    _activeStyleUrl = _initialStyleUrl;
    widget.config.userLocation?.addListener(_pushUserLocation);
    widget.config.navAlong?.addListener(_onNavAlong);
    _userLocationHeartbeat = Timer.periodic(
      _userLocationHeartbeatEvery,
      (_) => _pushUserLocation(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pixelRatio = MediaQuery.devicePixelRatioOf(context);
  }

  @override
  void didUpdateWidget(MapLibreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.config;
    final cfg = widget.config;

    if (!identical(old.navAlong, cfg.navAlong)) {
      old.navAlong?.removeListener(_onNavAlong);
      cfg.navAlong?.addListener(_onNavAlong);
    }
    if (!identical(old.userLocation, cfg.userLocation)) {
      old.userLocation?.removeListener(_pushUserLocation);
      cfg.userLocation?.addListener(_pushUserLocation);
    }
    if (!old.showUserLocation && cfg.showUserLocation) {
      // Komponen lokasi asli diaktifkan selepas bingkai ini; hantar kedudukan sebaik ia sedia.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _pushUserLocation();
      });
    }

    if (_overlaysReady && old.vehicleKind != cfg.vehicleKind) {
      // Sprite kenderaan baharu (kereta <-> motosikal): bina semula overlay dengan imej yang betul.
      _enqueue(_initOverlays);
    }

    if (old.styleId != cfg.styleId) {
      final styleUrl = cfg.styleUrl;
      _activeStyleUrl = styleUrl;
      _overlaysReady = false;
      final controller = _controller;
      if (controller != null) {
        _enqueue(() => controller.setStyle(styleUrl));
      }
      return; // onStyleLoaded akan membina semula overlay dengan data terkini.
    }
    if (_overlaysReady &&
        (!_sameRoutes(old.routes, cfg.routes) ||
            !listEquals(old.reports, cfg.reports) ||
            !identical(old.navRoute, cfg.navRoute) ||
            !_sameLeg(old.finalLeg, cfg.finalLeg) ||
            old.destination != cfg.destination ||
            old.colors != cfg.colors)) {
      _enqueue(_pushData);
    }
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object e, StackTrace s) {
      // Peta boleh dilupuskan di tengah operasi (cth. skrin ditutup); itu bukan ralat pengguna.
      logDiag('Overlay peta gagal: $e');
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    if (_activeStyleUrl != _initialStyleUrl) {
      _enqueue(() => controller.setStyle(_activeStyleUrl));
    }
    widget.config.onReady(
      _MapLibreCamera(controller, pump: _pump, pixelRatio: () => _pixelRatio),
    );
  }

  @override
  void dispose() {
    _userLocationHeartbeat?.cancel();
    widget.config.navAlong?.removeListener(_onNavAlong);
    widget.config.userLocation?.removeListener(_pushUserLocation);
    _pump.dispose();
    super.dispose();
  }

  /// Menyuap titik lokasi peta daripada kedudukan yang telah ditapis (bukan enjin GPS asli peta yang
  /// berasingan dan boleh menunjukkan lokasi lapuk sebaik app dibuka semula).
  void _pushUserLocation() {
    final c = _controller;
    final cfg = widget.config;
    final location = cfg.userLocation?.value;
    if (c == null || location == null || !cfg.showUserLocation) return;
    // Kedudukan lapuk dipaparkan dengan cincin ketidakpastian yang luas sehingga fix segar tiba.
    final accuracy = location.stale
        ? math.max(location.accuracyM, 120.0)
        : location.accuracyM;
    unawaited(
      c
          .updateManualLocation(
            ManualLocationUpdate(
              target: LatLng(location.point.lat, location.point.lng),
              horizontalAccuracy: accuracy,
              bearing: location.headingDegrees,
              speed: location.speedMps,
              timestamp: location.time,
            ),
          )
          .catchError((Object e) {
            // Komponen belum aktif (peta/gaya baru dimuat): kemas kini seterusnya akan berjaya.
            logDiag('Titik lokasi belum sedia: $e');
          }),
    );
  }

  Future<void> _sendVehicle(VehicleMarker? marker) async {
    final c = _controller;
    // Overlay belum siap: _initOverlays membaca marker terkini daripada pam apabila ia siap.
    if (c == null || !_overlaysReady) return;
    await c.setGeoJsonSource(_vehicleSource, _vehiclePoint(marker));
  }

  Future<void> _sendCamera(CameraPose pose) async {
    final c = _controller;
    if (c == null) return;
    await c.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pose.center.lat, pose.center.lng),
          zoom: pose.zoom,
          tilt: pose.tilt,
          bearing: pose.bearing,
        ),
      ),
    );
  }

  void _onStyleLoaded() {
    _enqueue(_initOverlays);
    // Menukar gaya mengaktifkan semula komponen lokasi tanpa kedudukan: hantar semula yang terkini.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pushUserLocation();
    });
  }

  Future<void> _initOverlays() async {
    final c = _controller;
    if (c == null) return;
    final colors = widget.config.colors;
    _labelAnchor = firstSymbolLayerId(widget.config.styleUrl);
    if (MapFramePump.diagnostics) {
      // Untuk menala gaya peta (cth. kontras mod gelap) tanpa meneka id lapisan.
      logDiag('FGDIAG lapisan gaya: ${(await c.getLayerIds()).join(', ')}');
    }

    // Buang dahulu jika wujud (onStyleLoaded boleh dipanggil lebih daripada sekali bagi gaya yang sama).
    for (final layer in [
      _vehicleLayer,
      _reportLayer,
      _destLayer,
      _legLayer,
      _mainLayer,
      _mainFarLayer,
      _casingLayer,
      _casingFarLayer,
      _altLayer,
    ]) {
      await _tryRemoveLayer(c, layer);
    }
    for (final source in [
      _vehicleSource,
      _reportSource,
      _destSource,
      _legSource,
      _mainSource,
      _altSource,
    ]) {
      await _tryRemoveSource(c, source);
    }

    await c.addGeoJsonSource(_altSource, _emptyCollection);
    await _addMainSource(c);
    await c.addGeoJsonSource(_legSource, _emptyCollection);
    await c.addGeoJsonSource(_destSource, _emptyCollection);
    await c.addGeoJsonSource(_reportSource, _emptyCollection);
    // Sumber baharu kosong: tiada apa yang dihantar lagi.
    _sentAlt = const [];
    _sentMain = const [];
    _sentNav = null;
    _sentLeg = const [];
    _trimAlong = null;
    _trimChunk = null;
    _sentDestination = null;
    _sentReports = const [];

    // Urutan penting: alternatif di bawah, kemudian tepi laluan utama, laluan utama, sambungan akhir,
    // destinasi.
    await c.addLineLayer(
      _altSource,
      _altLayer,
      LineLayerProperties(
        lineColor: _hex(colors.alternativeRoute),
        lineWidth: 5,
        lineCap: 'round',
        lineJoin: 'round',
        lineOpacity: 0.9,
      ),
      belowLayerId: _labelAnchor,
      enableInteraction: false,
    );
    await _addMainLayers(c, colors);
    await c.addLineLayer(
      _legSource,
      _legLayer,
      LineLayerProperties(
        lineColor: _hex(colors.destination),
        lineWidth: 4,
        lineCap: 'butt',
        lineJoin: 'round',
        lineDasharray: const [1.2, 1.6],
      ),
      belowLayerId: _labelAnchor,
      enableInteraction: false,
    );
    await c.addCircleLayer(
      _destSource,
      _destLayer,
      CircleLayerProperties(
        circleRadius: 8,
        circleColor: _hex(colors.destination),
        circleStrokeColor: _hex(colors.routeCasing),
        circleStrokeWidth: 3,
      ),
      enableInteraction: false,
    );

    // Penanda laporan komuniti: di atas laluan dan destinasi, di bawah kenderaan. Ikon dilukis sekali
    // setiap jenis dan dipilih mengikut sifat `icon` pada setiap titik.
    for (final type in ReportType.values) {
      await c.addImage(reportImageName(type), await renderReportIcon(type));
    }
    await c.addSymbolLayer(
      _reportSource,
      _reportLayer,
      SymbolLayerProperties(
        iconImage: ['get', 'icon'],
        iconSize:
            0.45 *
            (defaultTargetPlatform == TargetPlatform.android ? _pixelRatio : 1),
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      enableInteraction: false,
    );

    // Marker kenderaan di atas segalanya. Anak panah rata di atas jalan (sejajar peta) supaya
    // condong 3D memberi perspektif sebenar, dan berputar mengikut arah peta, bukan skrin.
    await c.addImage(
      _vehicleImage,
      await renderVehicleIcon(
        fill: colors.vehicle,
        kind: widget.config.vehicleKind,
        dark: colors.dark,
      ),
    );
    await c.addGeoJsonSource(_vehicleSource, _vehiclePoint(_pump.vehicle));
    await c.addSymbolLayer(
      _vehicleSource,
      _vehicleLayer,
      SymbolLayerProperties(
        iconImage: _vehicleImage,
        // Android MapLibre menganggap imej sebagai piksel fizikal (bukan dp), jadi tanpa pengganda ini
        // ikon hanya ~1/3 saiz sebenar pada skrin 3x. iOS menggunakan titik.
        iconSize:
            0.3 *
            (defaultTargetPlatform == TargetPlatform.android ? _pixelRatio : 1),
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconRotationAlignment: 'map',
        iconPitchAlignment: 'map',
        iconRotate: ['get', 'bearing'],
      ),
      enableInteraction: false,
    );

    _overlaysReady = true;
    await _pushData();
  }

  /// Sumber laluan utama dengan `lineMetrics` (diperlukan oleh `line-gradient`). Jika platform
  /// menolaknya, sumber biasa digunakan dan laluan dipangkas dengan menghantar baki (sandaran).
  Future<void> _addMainSource(MapLibreMapController c) async {
    _gradientOk = true;
    try {
      await c.addSource(
        _mainSource,
        const GeojsonSourceProperties(
          data: _emptyCollection,
          lineMetrics: true,
        ),
      );
    } on Object catch (e) {
      logDiag('Sumber lineMetrics tidak disokong, guna sandaran: $e');
      _gradientOk = false;
      await _tryRemoveSource(c, _mainSource);
      await c.addGeoJsonSource(_mainSource, _emptyCollection);
    }
  }

  /// Lapisan simbol pertama dalam gaya JSON: garisan laluan dipasang DI BAWAHNYA supaya label jalan dan
  /// tempat kekal terbaca di atas laluan. Null untuk gaya URL (id tidak diketahui): di atas semua.
  String? _labelAnchor;

  Future<void> _addMainLayers(
    MapLibreMapController c,
    MapOverlayColors colors,
  ) async {
    Future<void> add(bool gradient) async {
      // Urutan: tepi (jauh, dekat) di bawah, kemudian laluan (jauh, dekat). Lapisan "dekat" memuat keping
      // semasa (atau laluan tanpa keping, cth. pratonton) dan ialah satu-satunya yang dipangkas.
      await c.addLineLayer(
        _mainSource,
        _casingFarLayer,
        _plainProps(_hex(colors.routeCasing), 10),
        belowLayerId: _labelAnchor,
        filter: _farFilter(_noChunk),
        enableInteraction: false,
      );
      await c.addLineLayer(
        _mainSource,
        _casingLayer,
        _casingProps(colors, gradient ? 1.0 : null, gradient: gradient),
        belowLayerId: _labelAnchor,
        filter: _nearFilter(_noChunk),
        enableInteraction: false,
      );
      await c.addLineLayer(
        _mainSource,
        _mainFarLayer,
        _plainProps(_hex(colors.mainRoute), 6),
        belowLayerId: _labelAnchor,
        filter: _farFilter(_noChunk),
        enableInteraction: false,
      );
      await c.addLineLayer(
        _mainSource,
        _mainLayer,
        _mainProps(colors, gradient ? 1.0 : null, gradient: gradient),
        belowLayerId: _labelAnchor,
        filter: _nearFilter(_noChunk),
        enableInteraction: false,
      );
    }

    try {
      await add(_gradientOk);
    } on Object catch (e) {
      if (!_gradientOk) rethrow;
      logDiag('line-gradient ditolak, guna sandaran: $e');
      _gradientOk = false;
      for (final id in [
        _mainLayer,
        _mainFarLayer,
        _casingLayer,
        _casingFarLayer,
      ]) {
        await _tryRemoveLayer(c, id);
      }
      await _tryRemoveSource(c, _mainSource);
      await c.addGeoJsonSource(_mainSource, _emptyCollection);
      await add(false);
    }
  }

  LineLayerProperties _plainProps(String hex, double width) =>
      LineLayerProperties(
        lineColor: hex,
        lineWidth: width,
        lineCap: 'round',
        lineJoin: 'round',
      );

  /// Indeks keping "tiada navigasi": tiada keping sepadan, jadi lapisan jauh kosong dan lapisan dekat
  /// hanya memaparkan ciri tanpa indeks (laluan pratonton).
  static const _noChunk = 1 << 30;

  /// Keping selepas [chunk] (lapisan jauh).
  static List<Object> _farFilter(int chunk) => [
    'all',
    ['has', 'i'],
    [
      '>',
      ['get', 'i'],
      chunk,
    ],
  ];

  /// Keping [chunk] atau ciri tanpa indeks (lapisan dekat, dipangkas dengan gradient).
  static List<Object> _nearFilter(int chunk) => [
    'any',
    [
      '!',
      ['has', 'i'],
    ],
    [
      '==',
      ['get', 'i'],
      chunk,
    ],
  ];

  /// Menukar keping semasa pada keempat-empat lapisan (penapis sahaja; geometri tidak dihantar semula).
  Future<void> _setChunkFilters(MapLibreMapController c, int chunk) async {
    await c.setFilter(_casingFarLayer, _farFilter(chunk));
    await c.setFilter(_mainFarLayer, _farFilter(chunk));
    await c.setFilter(_casingLayer, _nearFilter(chunk));
    await c.setFilter(_mainLayer, _nearFilter(chunk));
    _trimChunk = chunk;
  }

  LineLayerProperties _mainProps(
    MapOverlayColors colors,
    double? fraction, {
    required bool gradient,
  }) {
    final hex = _hex(colors.mainRoute);
    return LineLayerProperties(
      lineColor: hex,
      lineWidth: 6,
      lineCap: 'round',
      lineJoin: 'round',
      lineGradient: !gradient
          ? null
          : (fraction == null || fraction >= 1
                ? solidGradient(hex)
                : trimGradient(fraction, hex)),
    );
  }

  LineLayerProperties _casingProps(
    MapOverlayColors colors,
    double? fraction, {
    required bool gradient,
  }) {
    final hex = _hex(colors.routeCasing);
    return LineLayerProperties(
      lineColor: hex,
      lineWidth: 10,
      lineCap: 'round',
      lineJoin: 'round',
      lineGradient: !gradient
          ? null
          : (fraction == null || fraction >= 1
                ? solidGradient(hex)
                : trimGradient(fraction, hex)),
    );
  }

  void _onNavAlong() {
    if (_trimQueued) return;
    _trimQueued = true;
    _enqueue(() async {
      _trimQueued = false;
      await _applyTrim();
    });
  }

  /// Memangkas laluan navigasi pada kedudukan kenderaan semasa. Dikumpulkan: banyak perubahan kecil
  /// menghasilkan satu panggilan yang membaca nilai terkini.
  Future<void> _applyTrim() async {
    final c = _controller;
    final nav = widget.config.navRoute;
    if (c == null ||
        !_overlaysReady ||
        nav == null ||
        !identical(_sentNav, nav)) {
      return;
    }
    final along = widget.config.navAlong?.value ?? 0;
    final last = _trimAlong;
    if (last != null && (along - last).abs() < (_gradientOk ? 0.5 : 5)) return;
    _trimAlong = along;
    if (_gradientOk) {
      try {
        final chunk = nav.chunkIndexAt(along);
        if (_trimChunk != chunk) await _setChunkFilters(c, chunk);
        await _setTrim(c, nav.chunkFractionAt(along));
        return;
      } on Object catch (e) {
        logDiag('Pemangkasan line-gradient gagal, guna sandaran: $e');
        _gradientOk = false;
        await _resetChunkFilters(c);
      }
    }
    await c.setGeoJsonSource(
      _mainSource,
      _lines([MapRouteLine(points: nav.remainingFrom(along), isMain: true)]),
    );
  }

  /// Menetapkan pemangkasan pada lapisan laluan dan tepinya. Plugin menghantar semua sifat (termasuk
  /// yang null, yang menetapkannya semula), jadi sifat garisan dihantar lengkap setiap kali.
  Future<void> _setTrim(MapLibreMapController c, double? fraction) async {
    final colors = widget.config.colors;
    await c.setLayerProperties(
      _casingLayer,
      _casingProps(colors, fraction, gradient: true),
    );
    await c.setLayerProperties(
      _mainLayer,
      _mainProps(colors, fraction, gradient: true),
    );
  }

  /// Kembalikan penapis ke keadaan tanpa navigasi (lapisan jauh kosong, lapisan dekat = ciri tanpa indeks).
  Future<void> _resetChunkFilters(MapLibreMapController c) async {
    try {
      await _setChunkFilters(c, _noChunk);
    } on Object catch (e) {
      logDiag('Tetapan semula penapis keping gagal: $e');
    }
    _trimChunk = null;
  }

  Future<void> _pushData() async {
    final c = _controller;
    if (c == null || !_overlaysReady) return;
    final cfg = widget.config;

    final alt = cfg.routes.where((r) => !r.isMain).toList(growable: false);
    final main = cfg.routes.where((r) => r.isMain).toList(growable: false);
    if (!_sameRoutes(_sentAlt, alt)) {
      _sentAlt = alt;
      await c.setGeoJsonSource(_altSource, _lines(alt));
    }
    final nav = cfg.navRoute;
    if (nav != null) {
      // Geometri penuh dihantar SEKALI setiap laluan; selepas itu hanya pemangkasan berubah.
      if (!identical(_sentNav, nav)) {
        _sentNav = nav;
        _sentMain = const [];
        _trimAlong = null;
        final along = cfg.navAlong?.value ?? 0;
        if (_gradientOk) {
          // Penapis dahulu, kemudian data: jika tidak, seluruh laluan kelihatan seketika (lapisan jauh).
          try {
            await _setChunkFilters(c, nav.chunkIndexAt(along));
            await _setTrim(c, nav.chunkFractionAt(along));
          } on Object catch (e) {
            logDiag('Penapis keping ditolak, guna sandaran: $e');
            _gradientOk = false;
            await _resetChunkFilters(c);
          }
        }
        await c.setGeoJsonSource(
          _mainSource,
          _gradientOk
              ? _chunkCollection(nav)
              : _lines([
                  MapRouteLine(points: nav.remainingFrom(along), isMain: true),
                ]),
        );
      }
      await _applyTrim();
    } else {
      if (_sentNav != null) {
        // Navigasi tamat: kosongkan laluan dan pulihkan warna penuh (tanpa pemangkasan).
        _sentNav = null;
        _sentMain = const [];
        _trimAlong = null;
        await c.setGeoJsonSource(_mainSource, _emptyCollection);
        if (_gradientOk) {
          await _resetChunkFilters(c);
          await _setTrim(c, null);
        }
      }
      if (!_sameRoutes(_sentMain, main)) {
        _sentMain = main;
        await c.setGeoJsonSource(_mainSource, _lines(main));
      }
    }
    if (!_sameLeg(_sentLeg, cfg.finalLeg)) {
      _sentLeg = cfg.finalLeg;
      await c.setGeoJsonSource(_legSource, _legLine(cfg.finalLeg));
    }
    if (_sentDestination != cfg.destination) {
      _sentDestination = cfg.destination;
      await c.setGeoJsonSource(_destSource, _point(cfg.destination));
    }
    if (!listEquals(_sentReports, cfg.reports)) {
      _sentReports = cfg.reports;
      await c.setGeoJsonSource(_reportSource, _reportFeatures(cfg.reports));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final map = MapLibreMap(
      // Kekalkan parameter asal; pertukaran gaya dibuat melalui controller.setStyle.
      styleString: _initialStyleUrl,
      initialCameraPosition: CameraPosition(
        target: LatLng(cfg.initialCenter.lat, cfg.initialCenter.lng),
        zoom: cfg.initialZoom,
        bearing: cfg.initialBearing,
        tilt: cfg.initialTilt,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapLongClick: (_, latLng) =>
          cfg.onLongPress(GeoPoint(latLng.latitude, latLng.longitude)),
      onMapClick: cfg.onTap == null
          ? null
          : (_, latLng) =>
                cfg.onTap!(GeoPoint(latLng.latitude, latLng.longitude)),
      // Titik lokasi disuap oleh kita sendiri (kedudukan tertapis yang sama dengan kamera), bukan enjin
      // GPS asli peta.
      myLocationEnabled: cfg.showUserLocation,
      locationSource: const ManualLocationSource(),
      trackCameraPosition: true,
      zoomGesturesEnabled: true,
      compassEnabled: cfg.showCompass,
      logoEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonColor: cfg.colors.vehicle,
    );
    // Sentiasa dibalut (walaupun tiada pendengar): jika pokok widget berubah bentuk apabila navigasi
    // bermula, peta dicipta semula dan kawalan kamera lama menuding ke saluran platform yang sudah mati.
    // Listener tidak menyertai arena gestur, jadi tidak mengganggu peta; ia hanya memerhati sama
    // ada jari menggerakkan peta (seret / cubit) untuk melepaskan kamera navigasi.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _gestureTravel = 0;
        _gestureReported = false;
      },
      onPointerMove: (event) {
        _gestureTravel += event.delta.distance;
        if (!_gestureReported && _gestureTravel > 14) {
          _gestureReported = true;
          widget.config.onUserGesture?.call();
        }
      },
      child: map,
    );
  }
}

class _MapLibreCamera implements MapCameraController {
  _MapLibreCamera(
    this._controller, {
    required this.pump,
    required this.pixelRatio,
  });

  final MapLibreMapController _controller;
  final MapFramePump pump;
  final double Function() pixelRatio;

  @override
  Future<Offset?> screenPointOf(GeoPoint point) async {
    try {
      final p = await _controller.toScreenLocation(
        LatLng(point.lat, point.lng),
      );
      final x = p.x.toDouble(), y = p.y.toDouble();
      if (!x.isFinite || !y.isFinite) return null;
      // Android memulangkan piksel fizikal; iOS memulangkan titik logikal.
      final scale = defaultTargetPlatform == TargetPlatform.android
          ? pixelRatio()
          : 1.0;
      return Offset(x / scale, y / scale);
    } on Object {
      return null; // peta dilupuskan atau belum bersedia
    }
  }

  @override
  CameraPose? get pose {
    final p = _controller.cameraPosition;
    if (p == null) return null;
    return CameraPose(
      center: GeoPoint(p.target.latitude, p.target.longitude),
      zoom: p.zoom,
      tilt: p.tilt,
      bearing: p.bearing,
    );
  }

  @override
  Duration get cameraLatency => pump.cameraLatency;

  @override
  void moveTo(CameraPose pose) => pump.moveCamera(pose);

  @override
  Future<void> animateTo(CameraPose pose) async {
    pump.cancelCamera();
    await _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pose.center.lat, pose.center.lng),
          zoom: pose.zoom,
          tilt: pose.tilt,
          bearing: pose.bearing,
        ),
      ),
      duration: Motion.emphasized,
    );
  }

  @override
  void showVehicle(VehicleMarker? marker) => pump.setVehicle(marker);

  @override
  GeoPoint? get center {
    final target = _controller.cameraPosition?.target;
    return target == null ? null : GeoPoint(target.latitude, target.longitude);
  }

  @override
  Future<void> flyTo(GeoPoint target, {double zoom = 15}) async {
    pump.cancelCamera();
    await _controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(target.lat, target.lng), zoom),
      duration: Motion.emphasized,
    );
  }

  @override
  Future<void> zoomBy(double amount) async {
    pump.cancelCamera();
    final currentZoom = pose?.zoom ?? 11;
    final targetZoom = (currentZoom + amount).clamp(2.0, 20.0).toDouble();
    if (targetZoom == currentZoom) return;
    await _controller.animateCamera(
      CameraUpdate.zoomBy(targetZoom - currentZoom),
      duration: Motion.normal,
    );
  }

  @override
  Future<void> fitTo(
    List<GeoPoint> points, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    if (points.isEmpty) return;
    if (points.length == 1) return flyTo(points.first);
    pump.cancelCamera();

    var south = points.first.lat, north = points.first.lat;
    var west = points.first.lng, east = points.first.lng;
    for (final p in points) {
      if (p.lat < south) south = p.lat;
      if (p.lat > north) north = p.lat;
      if (p.lng < west) west = p.lng;
      if (p.lng > east) east = p.lng;
    }

    await _controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
      duration: Motion.emphasized,
    );
  }
}

/// Skrin membina senarai [MapRouteLine] baharu pada setiap build, jadi bandingkan ikut identiti
/// senarai titik di dalamnya (yang stabil selagi data laluan tidak berubah) dan bukan senarai luar.
bool _sameRoutes(List<MapRouteLine> a, List<MapRouteLine> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i].points, b[i].points) || a[i].isMain != b[i].isMain) {
      return false;
    }
  }
  return true;
}

bool _sameLeg(List<GeoPoint> a, List<GeoPoint> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, dynamic> _legLine(List<GeoPoint> leg) =>
    _lines([if (leg.length >= 2) MapRouteLine(points: leg, isMain: false)]);

Future<void> _tryRemoveLayer(MapLibreMapController c, String id) async {
  try {
    await c.removeLayer(id);
  } on Object {
    // Tiada lapisan sedemikian; itu yang dijangka pada muat pertama.
  }
}

Future<void> _tryRemoveSource(MapLibreMapController c, String id) async {
  try {
    await c.removeSource(id);
  } on Object {
    // Tiada sumber sedemikian.
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Laluan navigasi sebagai satu ciri bagi setiap keping (sifat `i` = indeks keping).
Map<String, dynamic> _chunkCollection(NavRouteLine nav) {
  return {
    'type': 'FeatureCollection',
    'features': [
      for (var i = 0; i < nav.chunks.length; i++)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{'i': i},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in nav.chunks[i].points) [p.lng, p.lat],
            ],
          },
        },
    ],
  };
}

Map<String, dynamic> _lines(Iterable<MapRouteLine> lines) {
  return {
    'type': 'FeatureCollection',
    'features': [
      for (final line in lines)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            // GeoJSON: [longitud, latitud].
            'coordinates': [
              for (final p in line.points) [p.lng, p.lat],
            ],
          },
        },
    ],
  };
}

Map<String, dynamic> _vehiclePoint(VehicleMarker? v) {
  return {
    'type': 'FeatureCollection',
    'features': [
      if (v != null)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{'bearing': v.bearing},
          'geometry': {
            'type': 'Point',
            'coordinates': [v.point.lng, v.point.lat],
          },
        },
    ],
  };
}

Map<String, dynamic> _point(GeoPoint? p) {
  return {
    'type': 'FeatureCollection',
    'features': [
      if (p != null)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [p.lng, p.lat],
          },
        },
    ],
  };
}

Map<String, dynamic> _reportFeatures(List<MapReport> reports) => {
  'type': 'FeatureCollection',
  'features': [
    for (final r in reports)
      {
        'type': 'Feature',
        'properties': {'id': r.id, 'icon': reportImageName(r.type)},
        'geometry': {
          'type': 'Point',
          'coordinates': [r.point.lng, r.point.lat],
        },
      },
  ],
};

/// Id lapisan simbol pertama dalam gaya JSON, atau null jika [style] ialah URL/tidak dapat dihuraikan.
@visibleForTesting
String? firstSymbolLayerId(String style) {
  if (!style.trimLeft().startsWith('{')) return null;
  try {
    final decoded = jsonDecode(style);
    final layers = decoded is Map ? decoded['layers'] : null;
    if (layers is! List) return null;
    for (final l in layers) {
      if (l is Map && l['type'] == 'symbol' && l['id'] is String) {
        return l['id'] as String;
      }
    }
  } on FormatException {
    return null;
  }
  return null;
}
