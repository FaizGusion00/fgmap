/// Masa masuk dan keluar mod memandu bebas (tiada laluan).
///
/// Masuk apabila kelajuan kekal pada atau melebihi 2.5 m/s selama kira-kira 1.5 s dan arah diketahui.
/// Lampu isyarat tidak menjatuhkan peta ke 2D: berhenti di bawah 1 m/s kurang daripada 45 s kekal
/// dalam mod ini. Selepas 45 s di bawah 1 m/s, kembali ke peta biasa.
class CruiseGate {
  static const enterSpeedMps = 2.5;
  static const enterHold = Duration(milliseconds: 1500);
  static const exitSpeedMps = 1.0;
  static const exitHold = Duration(seconds: 45);

  bool active = false;
  DateTime? _movingSince;
  DateTime? _stoppedSince;

  /// Pulihkan mod yang sudah aktif (selepas proses mati). [stoppedSince] menyambung kiraan 45 s
  /// jika kereta sudah perlahan sebelum proses mati.
  void seedActive({DateTime? stoppedSince}) {
    active = true;
    _movingSince = null;
    _stoppedSince = stoppedSince;
  }

  void reset() {
    active = false;
    _movingSince = null;
    _stoppedSince = null;
  }

  /// [blocked] apabila navigasi atau pratonton laluan memiliki kamera: mod ini mesti mati.
  bool update({
    required DateTime time,
    required double speedMps,
    required bool headingKnown,
    required bool blocked,
  }) {
    if (blocked) {
      reset();
      return false;
    }
    final speed = speedMps.isFinite ? speedMps : 0.0;
    if (!active) {
      if (speed >= enterSpeedMps && headingKnown) {
        final since = _movingSince ??= time;
        if (time.difference(since) >= enterHold) {
          active = true;
          _stoppedSince = null;
        }
      } else {
        _movingSince = null;
      }
      return active;
    }
    if (speed < exitSpeedMps) {
      final since = _stoppedSince ??= time;
      if (time.difference(since) >= exitHold) {
        reset();
      }
    } else {
      _stoppedSince = null;
    }
    return active;
  }
}
