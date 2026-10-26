import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/geo.dart';
import '../../navigation/domain/camera_planner.dart' show CameraPose;
import 'map_frame_pump.dart';
import 'map_view.dart';
import 'vehicle_icon.dart';

const _altSource = 'fg-route-alt-src';
const _mainSource = 'fg-route-main-src';
const _destSource = 'fg-destination-src';
const _vehicleSource = 'fg-vehicle-src';
const _vehicleLayer = 'fg-vehicle';
const _vehicleImage = 'fg-vehicle-icon';
const _altLayer = 'fg-route-alt';
const _casingLayer = 'fg-route-casing';
const _mainLayer = 'fg-route-main';
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

  @override
  void initState() {
    super.initState();
    _initialStyleUrl = widget.config.styleUrl;
    _activeStyleUrl = _initialStyleUrl;
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

    if (old.styleUrl != cfg.styleUrl) {
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
            old.destination != cfg.destination ||
            old.colors != cfg.colors)) {
      _enqueue(_pushData);
    }
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object e, StackTrace s) {
      // Peta boleh dilupuskan di tengah operasi (cth. skrin ditutup); itu bukan ralat pengguna.
      debugPrint('Overlay peta gagal: $e');
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    if (_activeStyleUrl != _initialStyleUrl) {
      _enqueue(() => controller.setStyle(_activeStyleUrl));
    }
    widget.config.onReady(_MapLibreCamera(controller, pump: _pump));
  }

  @override
  void dispose() {
    _pump.dispose();
    super.dispose();
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

  void _onStyleLoaded() => _enqueue(_initOverlays);

  Future<void> _initOverlays() async {
    final c = _controller;
    if (c == null) return;
    final colors = widget.config.colors;

    // Buang dahulu jika wujud (onStyleLoaded boleh dipanggil lebih daripada sekali bagi gaya yang sama).
    for (final layer in [
      _vehicleLayer,
      _destLayer,
      _mainLayer,
      _casingLayer,
      _altLayer,
    ]) {
      await _tryRemoveLayer(c, layer);
    }
    for (final source in [
      _vehicleSource,
      _destSource,
      _mainSource,
      _altSource,
    ]) {
      await _tryRemoveSource(c, source);
    }

    await c.addGeoJsonSource(_altSource, _emptyCollection);
    await c.addGeoJsonSource(_mainSource, _emptyCollection);
    await c.addGeoJsonSource(_destSource, _emptyCollection);

    // Urutan penting: alternatif di bawah, kemudian tepi laluan utama, laluan utama, destinasi.
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
      enableInteraction: false,
    );
    await c.addLineLayer(
      _mainSource,
      _casingLayer,
      LineLayerProperties(
        lineColor: _hex(colors.routeCasing),
        lineWidth: 10,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );
    await c.addLineLayer(
      _mainSource,
      _mainLayer,
      LineLayerProperties(
        lineColor: _hex(colors.mainRoute),
        lineWidth: 6,
        lineCap: 'round',
        lineJoin: 'round',
      ),
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

    // Marker kenderaan di atas segalanya. Anak panah rata di atas jalan (sejajar peta) supaya
    // condong 3D memberi perspektif sebenar, dan berputar mengikut arah peta, bukan skrin.
    await c.addImage(
      _vehicleImage,
      await renderVehicleIcon(fill: colors.vehicle),
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

  Future<void> _pushData() async {
    final c = _controller;
    if (c == null || !_overlaysReady) return;
    final cfg = widget.config;

    await c.setGeoJsonSource(
      _altSource,
      _lines(cfg.routes.where((r) => !r.isMain)),
    );
    await c.setGeoJsonSource(
      _mainSource,
      _lines(cfg.routes.where((r) => r.isMain)),
    );
    await c.setGeoJsonSource(_destSource, _point(cfg.destination));
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
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapLongClick: (_, latLng) =>
          cfg.onLongPress(GeoPoint(latLng.latitude, latLng.longitude)),
      onMapClick: cfg.onTap == null
          ? null
          : (_, latLng) =>
                cfg.onTap!(GeoPoint(latLng.latitude, latLng.longitude)),
      myLocationEnabled: cfg.showUserLocation,
      trackCameraPosition: true,
      zoomGesturesEnabled: true,
      compassEnabled: true,
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
  _MapLibreCamera(this._controller, {required this.pump});

  final MapLibreMapController _controller;
  final MapFramePump pump;

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
