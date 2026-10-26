import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../navigation/domain/fix_filter.dart';

/// Kedudukan pengguna yang telah ditapis dan dilicinkan, untuk paparan peta (titik lokasi dan kamera
/// "ikut saya"). Satu sumber kebenaran: titik di peta dan kamera sentiasa bercakap tentang kedudukan
/// yang sama, tidak lagi dua enjin GPS berasingan yang boleh berselisih.
@immutable
class UserLocation {
  const UserLocation({
    required this.point,
    required this.accuracyM,
    required this.time,
    this.headingDegrees,
    this.speedMps = 0,
    this.stale = false,
  });

  final GeoPoint point;
  final double accuracyM;
  final DateTime time;

  /// Arah gerakan; null jika hampir pegun.
  final double? headingDegrees;
  final double speedMps;

  /// Benar apabila kedudukan ini ditinggalkan semasa app di latar belakang dan fix segar belum tiba.
  /// Paparan menunjukkan ketidakpastian yang luas sehingga fix baharu mengesahkannya.
  final bool stale;

  UserLocation asStale() => UserLocation(
    point: point,
    accuracyM: accuracyM,
    time: time,
    headingDegrees: headingDegrees,
    speedMps: 0,
    stale: true,
  );
}

/// Memiliki strim lokasi untuk peta apabila TIDAK bernavigasi.
///
/// Masalah yang diselesaikan: dahulu titik lokasi datang daripada enjin asli peta (menunjukkan "lokasi
/// terakhir" yang lapuk sebaik app dibuka semula) dan kamera daripada strim berasingan tanpa semakan
/// umur. Sekarang setiap fix:
///  - dibuang jika lapuk (cache platform yang dihantar sebaik langganan), tidak tertib, terlalu kasar
///    atau melompat mustahil ([FixFilter]);
///  - dilicinkan, dan hingar ketika pegun ditahan supaya titik tidak bergoyang;
///  - dimulakan semula selepas app kembali dari latar belakang: keadaan penapis lama tidak lagi
///    menggambarkan pengguna yang mungkin sudah berpindah jauh.
///
/// Strim hanya hidup apabila diminta ([start]) DAN tiada sebab untuk menggantung (latar belakang,
/// navigasi mengambil alih GPS). Tidak bergantung pada Flutter widget atau peta supaya mudah diuji.
class UserLocationTracker {
  UserLocationTracker({
    required this.fixes,
    DateTime Function()? clock,
    this.maxAccuracyM = 100,
    this.assumedAccuracyM = 50,
  }) : _clock = clock ?? DateTime.now;

  final Stream<LocationFix> Function() fixes;

  final DateTime Function() _clock;

  /// Fix yang lebih kasar daripada ini (cth. menara sel) ditolak.
  final double maxAccuracyM;

  /// Ketepatan yang diandaikan jika peranti tidak melaporkannya.
  final double assumedAccuracyM;

  /// Kedudukan terkini; null sebelum fix pertama yang sah. Dikemas kini hanya apabila nilai benar-benar
  /// berubah.
  final ValueNotifier<UserLocation?> location = ValueNotifier(null);

  final StreamController<UserLocation> _updates =
      StreamController<UserLocation>.broadcast(sync: true);

  /// Setiap kedudukan baharu yang diterima (bukan penandaan lapuk).
  Stream<UserLocation> get updates => _updates.stream;

  StreamSubscription<LocationFix>? _subscription;
  late FixFilter _filter = _newFilter();
  bool _wanted = false;
  bool _disposed = false;
  final Set<Object> _suspensions = {};

  /// Strim lokasi sedang dilanggan.
  bool get listening => _subscription != null;

  /// Mula menjejak (kebenaran lokasi telah diberi).
  void start() {
    if (_disposed) return;
    _wanted = true;
    _sync();
  }

  /// Berhenti sepenuhnya (kebenaran ditarik balik) dan lupakan kedudukan.
  void stop() {
    _wanted = false;
    _sync();
    if (location.value != null) location.value = null;
  }

  /// Gantung sementara atas [reason] (cth. latar belakang) tanpa melupakan bahawa penjejakan diminta.
  void suspend(Object reason) {
    if (_suspensions.add(reason)) _sync();
  }

  /// Batalkan gantungan [reason]. Apabila gantungan terakhir ditarik balik, kedudukan lama ditandakan
  /// lapuk dan penapis dimulakan semula: fix pertama selepas itu dipercayai sepenuhnya.
  void resume(Object reason) {
    if (!_suspensions.remove(reason)) return;
    if (_suspensions.isEmpty) {
      _filter = _newFilter();
      final current = location.value;
      if (current != null && !current.stale) location.value = current.asStale();
    }
    _sync();
  }

  void dispose() {
    _disposed = true;
    _wanted = false;
    _suspensions.clear();
    _sync();
    unawaited(_updates.close());
    location.dispose();
  }

  FixFilter _newFilter() => FixFilter(maxAccuracyM: maxAccuracyM);

  void _sync() {
    final shouldListen = _wanted && _suspensions.isEmpty && !_disposed;
    if (shouldListen && _subscription == null) {
      _filter = _newFilter();
      _subscription = fixes().listen(
        _handle,
        // Kebenaran ditarik balik / perkhidmatan dimatikan: berhenti senyap, jangan ranap. UI akan
        // menyegarkan keadaan kebenaran dan memulakan semula jika perlu.
        onError: (Object _) {
          _wanted = false;
          _sync();
        },
        cancelOnError: true,
      );
    } else if (!shouldListen && _subscription != null) {
      unawaited(_subscription!.cancel());
      _subscription = null;
    }
  }

  void _handle(LocationFix raw) {
    if (_disposed) return;
    final accuracy = raw.accuracyMeters;
    final input = (accuracy == null || accuracy <= 0)
        ? LocationFix(
            point: raw.point,
            headingDegrees: raw.headingDegrees,
            accuracyMeters: assumedAccuracyM,
            speedMps: raw.speedMps,
            timestamp: raw.timestamp,
          )
        : raw;
    final accepted = _filter.accept(input, now: _clock());
    if (accepted == null) return;

    var point = accepted.point;
    var heading = accepted.headingDegrees;
    final previous = location.value;
    // Pegun: GPS bergoyang beberapa meter di tempat yang sama. Tahan titik lama supaya titik lokasi
    // dan kamera tidak menggeletar.
    if (previous != null &&
        !previous.stale &&
        accepted.speedMps < 0.8 &&
        distanceMeters(previous.point, point) <
            math.max(3.0, accepted.accuracyM * 0.5)) {
      point = previous.point;
      heading = previous.headingDegrees;
    }

    final next = UserLocation(
      point: point,
      accuracyM: accepted.accuracyM,
      time: accepted.time,
      headingDegrees: heading,
      speedMps: accepted.speedMps,
    );
    location.value = next;
    _updates.add(next);
  }
}
