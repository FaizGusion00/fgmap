import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/geo.dart';
import '../utils/log.dart';

/// Ketepatan bacaan sensor kompas. [unreliable] bermakna kompas perlu dikalibrasi (gerakkan telefon
/// dalam bentuk angka 8) atau ada gangguan magnet berhampiran.
enum CompassAccuracy { unreliable, low, medium, high }

/// Satu bacaan arah peranti.
class CompassReading {
  const CompassReading({
    required this.headingDegrees,
    required this.accuracy,
    this.trueNorth = false,
  });

  /// Arah bahagian atas telefon (0–360). Utara benar jika [trueNorth], jika tidak utara magnet.
  final double headingDegrees;
  final CompassAccuracy accuracy;

  /// Deklinasi magnet sudah diambil kira (lokasi diketahui).
  final bool trueNorth;
}

/// Sumber arah kompas. Antara muka supaya ujian boleh memalsukannya; pelaksanaan sebenar membaca
/// sensor natif (Android: sensor vektor putaran; iOS: CoreLocation heading). Aliran **tamat tanpa
/// data** jika peranti tiada sensor kompas; UI kemudian jatuh semula kepada arah GPS.
abstract interface class CompassHeadingSource {
  /// Aliran bacaan. Sensor berjalan hanya selama aliran didengar.
  Stream<CompassReading> readings();

  /// Beritahu lokasi pengguna supaya deklinasi magnet boleh digunakan (utara benar). Boleh dipanggil
  /// bila-bila masa; tidak berbuat apa-apa jika tidak disokong.
  Future<void> setLocation(GeoPoint point, {double altitudeM = 0});
}

class PlatformCompassHeadingSource implements CompassHeadingSource {
  const PlatformCompassHeadingSource();

  static const _events = EventChannel('com.fguniversalempire.fgmaps/heading');
  static const _control = MethodChannel(
    'com.fguniversalempire.fgmaps/heading_ctl',
  );

  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Stream<CompassReading> readings() {
    if (!_supported) return const Stream.empty();
    return _events.receiveBroadcastStream().transform(
      StreamTransformer<dynamic, CompassReading>.fromHandlers(
        handleData: (event, sink) {
          final r = parseCompassEvent(event);
          if (r != null) sink.add(r);
        },
        handleError: (Object e, StackTrace _, sink) {
          logDiag('Kompas gagal: $e');
          sink.close();
        },
      ),
    );
  }

  @override
  Future<void> setLocation(GeoPoint point, {double altitudeM = 0}) async {
    if (!_supported) return;
    try {
      await _control.invokeMethod<void>('setLocation', {
        'lat': point.lat,
        'lng': point.lng,
        'alt': altitudeM,
      });
    } on Object catch (e) {
      logDiag('Kompas setLocation gagal: $e');
    }
  }
}

/// Tukar peristiwa natif kepada [CompassReading]; null untuk peristiwa tidak sah atau "tiada sensor".
@visibleForTesting
CompassReading? parseCompassEvent(Object? event) {
  if (event is! Map) return null;
  final h = event['heading'];
  if (h is! num || !h.isFinite) return null;
  final acc = event['accuracy'];
  return CompassReading(
    headingDegrees: ((h.toDouble() % 360) + 360) % 360,
    accuracy: switch (acc is num ? acc.toInt() : 0) {
      >= 3 => CompassAccuracy.high,
      2 => CompassAccuracy.medium,
      1 => CompassAccuracy.low,
      _ => CompassAccuracy.unreliable,
    },
    trueNorth: event['trueNorth'] == true,
  );
}

final compassHeadingSourceProvider = Provider<CompassHeadingSource>(
  (ref) => const PlatformCompassHeadingSource(),
);
