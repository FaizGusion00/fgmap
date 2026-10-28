import 'dart:math' as math;

import 'instruction_text.dart';
import 'nav_route.dart';

/// Bunyi isyarat pendek sebelum suara (atau sendiri).
enum ChimeKind { early, now, reroute, arrive, warning }

enum AnnouncementKind {
  start,
  far,
  near,
  now,
  keepGoing,
  reroute,
  newRoute,
  gpsLost,
  gpsBack,
  speeding,
  report,
  speedLimit,
}

class Announcement {
  const Announcement({
    required this.kind,
    required this.text,
    required this.chime,
    this.interrupt = false,
  });

  final AnnouncementKind kind;
  final String text;
  final ChimeKind? chime;

  /// Benar jika ayat ini menggantikan apa yang sedang disebut (cth. "belok sekarang").
  final bool interrupt;

  @override
  String toString() => 'Announcement($kind, "$text")';
}

/// Jarak pencetus tiga peringkat bagi satu kelajuan.
class StageDistances {
  const StageDistances({
    required this.far,
    required this.near,
    required this.now,
  });

  final double far;
  final double near;
  final double now;
}

/// Pengumuman awal mengikut kelajuan (Bahagian 8.3 #4): lebuh raya lebih awal daripada bandar.
/// Kelajuan serendah 6 m/s diandaikan supaya trafik perlahan tidak membuat arahan terlalu lewat.
StageDistances stageDistancesFor(double speedMps) {
  final v = math.max(speedMps, 6.0);
  return StageDistances(
    far: (v * 55).clamp(600.0, 3000.0),
    near: (v * 22).clamp(150.0, 700.0),
    now: (v * 5).clamp(35.0, 140.0),
  );
}

enum _Stage { far, near, now }

/// Memutuskan bila dan apa yang diumumkan. Kelas tulen: diberi kemajuan, ia memulangkan senarai
/// pengumuman baharu (kosong pada kebanyakan fix). Setiap peringkat bagi setiap manuver hanya sekali.
class AnnouncementPlanner {
  AnnouncementPlanner({required this.route, required InstructionText text})
    : _text = text;

  final NavRoute route;
  InstructionText _text;

  set language(VoiceLanguage language) => _text = InstructionText(language);

  final Set<(int, _Stage)> _fired = {};
  final Set<int> _keepGoingFired = {};
  bool _startAnnounced = false;
  bool _arrived = false;

  /// Ucapan pembukaan navigasi. Sekali sahaja.
  List<Announcement> start({bool isReroute = false}) {
    if (_startAnnounced) return const [];
    _startAnnounced = true;
    return [
      Announcement(
        kind: isReroute ? AnnouncementKind.newRoute : AnnouncementKind.start,
        text: isReroute ? _text.newRoute : _text.navigationStarted,
        chime: isReroute ? ChimeKind.reroute : ChimeKind.early,
      ),
    ];
  }

  /// [alongM] ialah kemajuan sepanjang laluan; [speedMps] kelajuan semasa.
  List<Announcement> update({
    required double alongM,
    required double speedMps,
  }) {
    if (_arrived) return const [];
    final out = <Announcement>[];

    final next = route.nextActionable(alongM);
    if (next == null) return out;

    final distance = next.startM - alongM;
    final stages = stageDistancesFor(speedMps);

    // Peringkat terbaru yang sudah tiba. Yang lebih awal ditandakan "sudah" supaya tidak diumumkan
    // terlambat (cth. navigasi bermula 200 m sebelum belok: terus "dalam 200 meter", bukan "dalam 2 km").
    _Stage? due;
    if (distance <= stages.now) {
      due = _Stage.now;
    } else if (distance <= stages.near) {
      due = _Stage.near;
    } else if (distance <= stages.far) {
      due = _Stage.far;
    }

    if (due != null) {
      final index = _Stage.values.indexOf(due);
      var alreadyFired = false;
      for (var i = 0; i <= index; i++) {
        final key = (next.index, _Stage.values[i]);
        if (i == index && _fired.contains(key)) alreadyFired = true;
        _fired.add(key);
      }
      // "Anda telah sampai" tidak diumumkan oleh peringkat ini: ia hanya betul apabila destinasi
      // benar-benar dicapai, dan itu ditentukan oleh sesi (arrival()).
      final skip = due == _Stage.now && next.isArrival;
      if (!alreadyFired && !skip) {
        out.add(_announce(next, due, distance, stages));
      }
    }

    // Selepas melepasi manuver dan jalan lurus panjang menanti: beritahu pemandu berapa jauh.
    final passed = route.maneuverAt(alongM);
    if (passed != null &&
        passed.index > 0 &&
        passed.isActionable &&
        !_keepGoingFired.contains(passed.index) &&
        alongM - passed.startM <= 800 &&
        distance >= 4000) {
      _keepGoingFired.add(passed.index);
      out.add(
        Announcement(
          kind: AnnouncementKind.keepGoing,
          text: _text.keepGoing(passed.street, distance),
          chime: null,
        ),
      );
    }
    return out;
  }

  Announcement _announce(
    NavManeuver m,
    _Stage stage,
    double distance,
    StageDistances stages,
  ) {
    // Manuver rapat berikutnya digabungkan: "belok kanan, kemudian belok kiri".
    final following = route.actionableAfter(m);
    final chained =
        following != null &&
            following.startM - m.startM < math.max(150, stages.now * 1.6)
        ? following
        : null;

    switch (stage) {
      case _Stage.far:
        return Announcement(
          kind: AnnouncementKind.far,
          text: _text.spoken(m, distanceM: distance),
          chime: ChimeKind.early,
        );
      case _Stage.near:
        return Announcement(
          kind: AnnouncementKind.near,
          text: _text.spoken(m, distanceM: distance, then: chained),
          chime: ChimeKind.early,
        );
      case _Stage.now:
        return Announcement(
          kind: AnnouncementKind.now,
          text: _text.spoken(m, then: chained),
          chime: m.isArrival ? ChimeKind.arrive : ChimeKind.now,
          interrupt: true,
        );
    }
  }

  /// Dipanggil sesi apabila destinasi dicapai. Sekali sahaja.
  Announcement? arrival() {
    if (_arrived) return null;
    _arrived = true;
    final last = route.maneuvers.isEmpty ? null : route.maneuvers.last;
    final text = last != null && last.isArrival
        ? _text.spoken(last)
        : _text.spoken(
            NavManeuver(
              index: 0,
              kind: ManeuverKind.arrive,
              startM: route.totalM,
              lengthM: 0,
              timeS: 0,
              streetNames: const [],
            ),
          );
    return Announcement(
      kind: AnnouncementKind.now,
      text: text,
      chime: ChimeKind.arrive,
      interrupt: true,
    );
  }

  Announcement get reroutingNotice => Announcement(
    kind: AnnouncementKind.reroute,
    text: _text.rerouting,
    chime: ChimeKind.reroute,
    interrupt: true,
  );

  Announcement get gpsLostNotice => Announcement(
    kind: AnnouncementKind.gpsLost,
    text: _text.gpsLost,
    chime: ChimeKind.warning,
  );

  Announcement get gpsBackNotice => Announcement(
    kind: AnnouncementKind.gpsBack,
    text: _text.gpsBack,
    chime: null,
  );
}
