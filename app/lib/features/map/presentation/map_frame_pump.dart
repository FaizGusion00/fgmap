import 'dart:async';

import '../../navigation/domain/camera_planner.dart' show CameraPose;
import 'map_view.dart';
import '../../../core/utils/log.dart';

/// Menghantar kedudukan marker dan pose kamera ke peta semasa navigasi (60 kali sesaat) dengan
/// panggilan platform yang tak segerak.
///
/// Hanya SATU hantaran berjalan pada satu masa, tetapi nilai yang tiba ketika itu TIDAK digugurkan:
/// yang terkini disimpan dan dihantar sebaik hantaran lama selesai ("nilai terkini menang"). Dahulu
/// bingkai yang tiba semasa panggilan lama berjalan digugurkan, jadi bingkai terakhir sebelum kereta
/// berhenti atau sebelum belokan boleh hilang dan marker/kamera tertahan di kedudukan lapuk.
///
/// Marker dan kamera yang ditetapkan dalam bingkai yang sama dihantar serentak (dua panggilan
/// berturutan dalam satu detik), supaya kereta kekal pada kedudukan skrin yang dikira dan tidak
/// "terapung" kerana satu daripadanya ketinggalan satu bingkai.
class MapFramePump {
  MapFramePump({required this.sendVehicle, required this.sendCamera});

  /// Menghantar marker ke peta; pelaksana memulangkan serta-merta jika peta belum bersedia.
  final Future<void> Function(VehicleMarker? marker) sendVehicle;
  final Future<void> Function(CameraPose pose) sendCamera;

  /// Diagnostik (`--dart-define=FG_DIAG=true`): kadar hantaran kamera dan masa pergi-balik ke peta, dicetak
  /// setiap 5 s. Jika peta terasa lambat pada zum tertentu, angka ini menunjukkan sama ada platform
  /// (peta) atau app yang menjadi punca.
  static const diagnostics = bool.fromEnvironment('FG_DIAG');
  final Stopwatch _diagClock = Stopwatch()..start();
  int _diagSends = 0;
  int _diagRttUs = 0;
  int _diagMaxRttUs = 0;
  int _diagReportedAtMs = 0;

  VehicleMarker? _vehicle;
  bool _vehicleDirty = false;
  CameraPose? _camera;
  bool _running = false;
  bool _disposed = false;

  /// Marker terkini yang diminta (walaupun belum dihantar).
  VehicleMarker? get vehicle => _vehicle;

  void setVehicle(VehicleMarker? marker) {
    _vehicle = marker;
    _vehicleDirty = true;
    _kick();
  }

  void moveCamera(CameraPose pose) {
    _camera = pose;
    _kick();
  }

  /// Buang gerakan kamera yang menunggu, cth. apabila animasi (terbang, muat laluan) bermula; gerakan
  /// lapuk yang tiba selepasnya akan membatalkan animasi itu.
  void cancelCamera() => _camera = null;

  void dispose() {
    _disposed = true;
    _camera = null;
    _vehicleDirty = false;
  }

  void _kick() {
    if (_running || _disposed) return;
    _running = true;
    // Mikrotugas: panggilan setVehicle dan moveCamera dalam bingkai yang sama dikumpul bersama.
    scheduleMicrotask(_run);
  }

  Future<void> _run() async {
    try {
      while (!_disposed && (_vehicleDirty || _camera != null)) {
        final sends = <Future<void>>[];
        if (_vehicleDirty) {
          _vehicleDirty = false;
          sends.add(_guard(() => sendVehicle(_vehicle), 'Marker kenderaan'));
        }
        final camera = _camera;
        if (camera != null) {
          _camera = null;
          sends.add(_guard(() => _timedCamera(camera), 'Gerak kamera'));
        }
        await Future.wait(sends);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _timedCamera(CameraPose pose) async {
    if (!diagnostics) return sendCamera(pose);
    final started = _diagClock.elapsedMicroseconds;
    await sendCamera(pose);
    final rtt = _diagClock.elapsedMicroseconds - started;
    _diagSends++;
    _diagRttUs += rtt;
    if (rtt > _diagMaxRttUs) _diagMaxRttUs = rtt;
    final nowMs = _diagClock.elapsedMilliseconds;
    if (nowMs - _diagReportedAtMs >= 5000) {
      final seconds = (nowMs - _diagReportedAtMs) / 1000;
      logDiag(
        'FGDIAG kamera: ${(_diagSends / seconds).toStringAsFixed(1)}/s, '
        'RTT purata ${(_diagRttUs / _diagSends / 1000).toStringAsFixed(1)} ms, '
        'maks ${(_diagMaxRttUs / 1000).toStringAsFixed(1)} ms',
      );
      _diagSends = 0;
      _diagRttUs = 0;
      _diagMaxRttUs = 0;
      _diagReportedAtMs = nowMs;
    }
  }

  Future<void> _guard(Future<void> Function() send, String what) async {
    try {
      await send();
    } on Object catch (e) {
      // Peta boleh dilupuskan di tengah hantaran; satu hantaran gagal tidak menghentikan yang lain.
      logDiag('$what gagal: $e');
    }
  }
}
