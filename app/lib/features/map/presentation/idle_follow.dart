import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';

/// "Ikut saya" di peta apabila TIDAK bernavigasi (gaya Waze): kamera mengikut pengguna bergerak
/// sehingga pengguna menggerakkan peta sendiri, dan kembali apabila mereka menekan "Lokasi saya".
///
/// Strim lokasi hanya hidup ketika benar-benar diperlukan: pengguna mahu mengikut DAN tiada sebab
/// untuk menggantung (app di latar belakang, laluan sedang dipratonton, navigasi berjalan, dll.).
/// Peta yang sudah dilepaskan pengguna tidak menggunakan GPS atau bateri langsung.
///
/// Sengaja tidak bergantung pada Flutter atau peta: [fixes] dan [onFix] disuntik supaya mudah diuji.
class IdleFollow {
  IdleFollow({
    required this.fixes,
    required this.onFix,
    this.maxAccuracyMeters = 100,
  });

  final Stream<LocationFix> Function() fixes;
  final void Function(LocationFix fix) onFix;

  /// Fix yang lebih kasar daripada ini (cth. dari menara sel) tidak patut menyentak kamera.
  final double maxAccuracyMeters;

  StreamSubscription<LocationFix>? _subscription;
  bool _wanted = false;
  final Set<Object> _suspensions = {};

  /// Pengguna mahu kamera mengikut mereka (walaupun strim sedang digantung sementara).
  bool get following => _wanted;

  /// Strim lokasi sedang dilanggan.
  bool get listening => _subscription != null;

  /// Mula mengikut (cth. "Lokasi saya" ditekan, atau lokasi dijumpai semasa pelancaran).
  void engage() {
    _wanted = true;
    _sync();
  }

  /// Pengguna menggerakkan peta: berhenti mengikut dan lepaskan GPS.
  void release() {
    if (!_wanted) return;
    _wanted = false;
    _sync();
  }

  /// Gantung sementara atas [reason] tanpa melupakan bahawa pengguna mahu mengikut.
  void suspend(Object reason) {
    if (_suspensions.add(reason)) _sync();
  }

  /// Batalkan gantungan [reason]; strim hidup semula apabila tiada gantungan lain.
  void resume(Object reason) {
    if (_suspensions.remove(reason)) _sync();
  }

  void dispose() {
    _wanted = false;
    _suspensions.clear();
    _sync();
  }

  void _sync() {
    final shouldListen = _wanted && _suspensions.isEmpty;
    if (shouldListen && _subscription == null) {
      _subscription = fixes().listen(
        _handle,
        // Kebenaran ditarik balik / perkhidmatan dimatikan: berhenti senyap, jangan ranap.
        onError: (Object _) => release(),
        cancelOnError: true,
      );
    } else if (!shouldListen && _subscription != null) {
      unawaited(_subscription!.cancel());
      _subscription = null;
    }
  }

  void _handle(LocationFix fix) {
    final accuracy = fix.accuracyMeters;
    if (accuracy != null && accuracy > maxAccuracyMeters) return;
    onFix(fix);
  }
}

/// Selepas app berada di latar belakang selama ini, membukanya semula memusatkan peta pada pengguna
/// (mereka mungkin sudah berpindah jauh). Lebih singkat daripada ini, peta kekal di tempat pengguna
/// tinggalkan supaya bertukar app sebentar tidak membuang kedudukan yang sedang diteliti.
final idleRecenterAfterProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);
