import 'dart:math' as math;

import '../../reports/domain/report.dart';

import 'nav_route.dart';

/// Bahasa arahan. Ayat dijana sendiri daripada jenis manuver (Bahagian 8.2 pelan), bukan teks
/// Valhalla, supaya sebutan dan nada terkawal.
enum VoiceLanguage {
  ms('ms-MY', 'ms'),
  en('en-US', 'en');

  const VoiceLanguage(this.ttsLocale, this.code);

  /// Locale untuk enjin TTS.
  final String ttsLocale;
  final String code;

  static VoiceLanguage fromCode(String? code) =>
      code == 'en' ? VoiceLanguage.en : VoiceLanguage.ms;
}

/// Pembina teks arahan untuk satu bahasa. Kelas tulen tanpa kebergantungan UI.
class InstructionText {
  const InstructionText(this.language);

  final VoiceLanguage language;

  bool get _ms => language == VoiceLanguage.ms;

  /// Tindakan sahaja, cth. "Belok kanan". Digunakan pada kad manuver dan dalam ayat bersuara.
  String action(NavManeuver m) {
    return switch (m.kind) {
      ManeuverKind.depart => _ms ? 'Mulakan perjalanan' : 'Start driving',
      ManeuverKind.straight => _ms ? 'Teruskan lurus' : 'Continue straight',
      ManeuverKind.slightRight => _ms ? 'Belok sedikit ke kanan' : 'Bear right',
      ManeuverKind.right => _ms ? 'Belok kanan' : 'Turn right',
      ManeuverKind.sharpRight => _ms ? 'Belok kanan tajam' : 'Turn sharp right',
      ManeuverKind.slightLeft => _ms ? 'Belok sedikit ke kiri' : 'Bear left',
      ManeuverKind.left => _ms ? 'Belok kiri' : 'Turn left',
      ManeuverKind.sharpLeft => _ms ? 'Belok kiri tajam' : 'Turn sharp left',
      ManeuverKind.uTurn => _ms ? 'Buat pusingan U' : 'Make a U-turn',
      ManeuverKind.rampStraight => _ms ? 'Ambil susur lurus' : 'Take the ramp',
      ManeuverKind.rampRight =>
        _ms ? 'Ambil susur di sebelah kanan' : 'Take the ramp on the right',
      ManeuverKind.rampLeft =>
        _ms ? 'Ambil susur di sebelah kiri' : 'Take the ramp on the left',
      ManeuverKind.exitRight =>
        _ms ? 'Ambil susur keluar di kanan' : 'Take the exit on the right',
      ManeuverKind.exitLeft =>
        _ms ? 'Ambil susur keluar di kiri' : 'Take the exit on the left',
      ManeuverKind.keepStraight => _ms ? 'Kekal lurus' : 'Keep straight',
      ManeuverKind.keepRight => _ms ? 'Kekal di sebelah kanan' : 'Keep right',
      ManeuverKind.keepLeft => _ms ? 'Kekal di sebelah kiri' : 'Keep left',
      ManeuverKind.merge => _ms ? 'Bergabung dengan lalu lintas' : 'Merge',
      ManeuverKind.mergeRight =>
        _ms ? 'Bergabung ke sebelah kanan' : 'Merge right',
      ManeuverKind.mergeLeft =>
        _ms ? 'Bergabung ke sebelah kiri' : 'Merge left',
      ManeuverKind.roundabout => _roundabout(m.roundaboutExit),
      ManeuverKind.ferry => _ms ? 'Naik feri' : 'Board the ferry',
      ManeuverKind.arrive => _ms ? 'Anda telah sampai' : 'You have arrived',
      ManeuverKind.arriveRight =>
        _ms
            ? 'Destinasi anda di sebelah kanan'
            : 'Your destination is on the right',
      ManeuverKind.arriveLeft =>
        _ms
            ? 'Destinasi anda di sebelah kiri'
            : 'Your destination is on the left',
      ManeuverKind.none => _ms ? 'Teruskan' : 'Continue',
    };
  }

  /// Teks pendek untuk kad manuver. Sama seperti [action] kecuali bulatan: ikon sudah menunjukkan
  /// bulatan dan nombor keluar, jadi kad hanya menyebut tindakan ("Ambil simpang keluar ke-2" /
  /// "Take the 2nd exit"). Ayat bersuara penuh kekal dalam [spoken].
  String cardAction(NavManeuver m) {
    final exit = m.roundaboutExit;
    if (m.kind == ManeuverKind.roundabout && exit != null && exit > 0) {
      return _ms
          ? 'Ambil simpang keluar ke-$exit'
          : 'Take the ${ordinalNumber(exit)} exit';
    }
    return action(m);
  }

  /// Tindakan dengan nama jalan, cth. "Belok kanan ke Jalan Ampang".
  String actionWithStreet(NavManeuver m) {
    final street = m.street;
    final base = action(m);
    if (street == null || m.isArrival) return base;
    return switch (m.kind) {
      ManeuverKind.depart => _ms ? '$base di $street' : '$base on $street',
      ManeuverKind.roundabout => base,
      _ => _ms ? '$base ke $street' : '$base onto $street',
    };
  }

  /// Ayat bersuara penuh. [distanceM] null = "sekarang" (tiada klausa jarak).
  String spoken(NavManeuver m, {double? distanceM, NavManeuver? then}) {
    final main = m.isArrival && distanceM != null
        ? _arrivalAhead(m.kind)
        : actionWithStreet(m);
    final buffer = StringBuffer();
    if (distanceM != null && !m.kind.isDepart) {
      final d = distance(distanceM);
      buffer.write(_ms ? 'Dalam $d, ' : 'In $d, ');
      buffer.write(_lowerFirst(main));
    } else {
      buffer.write(main);
    }
    if (then != null && !then.isArrival) {
      buffer.write(
        _ms
            ? ', kemudian ${_lowerFirst(action(then))}'
            : ', then ${_lowerFirst(action(then))}',
      );
    }
    buffer.write('.');
    return buffer.toString();
  }

  /// Destinasi masih di hadapan (belum sampai).
  String _arrivalAhead(ManeuverKind kind) {
    return switch (kind) {
      ManeuverKind.arriveRight =>
        _ms
            ? 'destinasi anda di sebelah kanan'
            : 'your destination is on the right',
      ManeuverKind.arriveLeft =>
        _ms
            ? 'destinasi anda di sebelah kiri'
            : 'your destination is on the left',
      _ => _ms ? 'destinasi anda di hadapan' : 'your destination is ahead',
    };
  }

  /// "Ikut Lebuhraya Utara-Selatan sejauh 11 kilometer."
  String keepGoing(String? street, double distanceM) {
    final d = distance(distanceM);
    if (street == null) return _ms ? 'Teruskan sejauh $d.' : 'Continue for $d.';
    return _ms ? 'Ikut $street sejauh $d.' : 'Follow $street for $d.';
  }

  String get navigationStarted =>
      _ms ? 'Navigasi bermula.' : 'Navigation started.';
  String get rerouting => _ms ? 'Mengira semula laluan.' : 'Recalculating.';
  String get newRoute => _ms ? 'Laluan baharu.' : 'New route found.';
  String get gpsLost => _ms ? 'Isyarat GPS lemah.' : 'GPS signal lost.';
  String get gpsBack => _ms ? 'Isyarat GPS pulih.' : 'GPS signal restored.';

  /// Nama jenis laporan untuk suara (tanpa BuildContext, jadi tidak melalui l10n app).
  String reportTypeName(ReportType type) => switch (type) {
    ReportType.police => _ms ? 'Polis' : 'Police',
    ReportType.accident => _ms ? 'Kemalangan' : 'Accident',
    ReportType.hazard => _ms ? 'Bahaya' : 'Hazard',
    ReportType.trafficJam => _ms ? 'Kesesakan' : 'Traffic jam',
    ReportType.roadClosed => _ms ? 'Jalan ditutup' : 'Road closed',
    ReportType.brokenDown => _ms ? 'Kenderaan rosak' : 'Broken-down vehicle',
    ReportType.flood => _ms ? 'Banjir' : 'Flooding',
  };

  /// "Had laju 80" / "Speed limit 80". Satu ayat pendek apabila had bertukar semasa memandu bebas.
  String speedLimitChanged(int kmh) =>
      _ms ? 'Had laju $kmh' : 'Speed limit $kmh';

  /// "Polis di hadapan, 300 meter." / "Police ahead, 300 meters."
  String reportAhead(ReportType type, double meters) {
    final name = reportTypeName(type);
    final d = distance(meters);
    return _ms ? '$name di hadapan, $d.' : '$name ahead, $d.';
  }

  /// Frasa jarak yang dibundar mengikut cara orang menyebutnya: 50, 100, ... 900 m, 1 km, 1.5 km, 2 km.
  String distance(double meters) {
    final m = math.max(0.0, meters);
    if (m >= 950) {
      final km = m < 3000 ? (m / 500).round() / 2 : (m / 1000).roundToDouble();
      final text = km == km.truncateToDouble()
          ? km.toInt().toString()
          : km.toStringAsFixed(1);
      return _ms || km == 1 ? '$text kilometer' : '$text kilometers';
    }
    final step = m >= 400 ? 100 : 50;
    final r = math.max(step, (m / step).round() * step);
    return _ms ? '$r meter' : '$r meters';
  }

  String _roundabout(int? exit) {
    if (exit == null || exit <= 0) {
      return _ms ? 'Masuk bulatan' : 'Enter the roundabout';
    }
    return _ms
        ? 'Di bulatan, ambil simpang keluar ke-$exit'
        : 'At the roundabout, take the ${_ordinal(exit)} exit';
  }

  /// Ordinal bersuara: dieja untuk 1-6 (lebih semula jadi dalam TTS), angka selepas itu.
  static String _ordinal(int n) => switch (n) {
    1 => 'first',
    2 => 'second',
    3 => 'third',
    4 => 'fourth',
    5 => 'fifth',
    6 => 'sixth',
    _ => ordinalNumber(n),
  };

  /// Ordinal angka Inggeris: 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th ... 21st, 22nd.
  static String ordinalNumber(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}

extension on ManeuverKind {
  bool get isDepart => this == ManeuverKind.depart;
}
