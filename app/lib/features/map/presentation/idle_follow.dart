import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_location.dart';

/// "Ikut saya" di peta apabila TIDAK bernavigasi (gaya Waze): kamera mengikut pengguna bergerak
/// sehingga pengguna menggerakkan peta sendiri, dan kembali apabila mereka menekan "Lokasi saya".
///
/// Ini hanya NIAT mengikut. Strim lokasi dimiliki oleh [UserLocationTracker] (satu langganan GPS untuk
/// titik lokasi DAN kamera); kelas ini sekadar meneruskan kedudukan segar ke kamera selagi pengguna
/// mahu mengikut dan tiada sebab untuk menggantung (laluan sedang dipratonton, navigasi berjalan).
///
/// Sengaja tidak bergantung pada Flutter atau peta: [updates] dan [onLocation] disuntik supaya mudah
/// diuji.
class IdleFollow {
  IdleFollow({required this.updates, required this.onLocation});

  final Stream<UserLocation> updates;
  final void Function(UserLocation location) onLocation;

  StreamSubscription<UserLocation>? _subscription;
  bool _wanted = false;
  final Set<Object> _suspensions = {};

  /// Pengguna mahu kamera mengikut mereka (walaupun sedang digantung sementara).
  bool get following => _wanted;

  /// Kedudukan sedang diteruskan ke kamera.
  bool get active => _subscription != null;

  /// Mula mengikut (cth. "Lokasi saya" ditekan, atau lokasi dijumpai semasa pelancaran).
  void engage() {
    _wanted = true;
    _sync();
  }

  /// Pengguna menggerakkan peta: berhenti mengikut.
  void release() {
    if (!_wanted) return;
    _wanted = false;
    _sync();
  }

  /// Gantung sementara atas [reason] tanpa melupakan bahawa pengguna mahu mengikut.
  void suspend(Object reason) {
    if (_suspensions.add(reason)) _sync();
  }

  /// Batalkan gantungan [reason]; kamera mengikut semula apabila tiada gantungan lain.
  void resume(Object reason) {
    if (_suspensions.remove(reason)) _sync();
  }

  void dispose() {
    _wanted = false;
    _suspensions.clear();
    _sync();
  }

  void _sync() {
    final shouldFollow = _wanted && _suspensions.isEmpty;
    if (shouldFollow && _subscription == null) {
      _subscription = updates.listen(_handle);
    } else if (!shouldFollow && _subscription != null) {
      unawaited(_subscription!.cancel());
      _subscription = null;
    }
  }

  void _handle(UserLocation location) {
    // Kedudukan lapuk (ditinggalkan semasa latar belakang) tidak patut menyentak kamera.
    if (location.stale) return;
    onLocation(location);
  }
}

/// Selepas app berada di latar belakang selama ini, membukanya semula memusatkan peta pada pengguna
/// (mereka mungkin sudah berpindah jauh). Lebih singkat daripada ini, peta kekal di tempat pengguna
/// tinggalkan supaya bertukar app sebentar tidak membuang kedudukan yang sedang diteliti.
final idleRecenterAfterProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);
