import 'announcement_planner.dart';
import 'instruction_text.dart';

/// Suara memandu bebas: loceng laju berlebihan (cooldown 20 s, sama seperti navigasi) dan satu ayat
/// apabila had laju bertukar. Tiada arahan belokan.
class CruiseVoice {
  static const overspeedCooldown = Duration(seconds: 20);

  DateTime? _lastChime;
  int? _spokenLimit;
  bool _wasOverspeed = false;

  void reset() {
    _lastChime = null;
    _spokenLimit = null;
    _wasOverspeed = false;
  }

  /// [limitKmh] null bermaksud had tidak diketahui (papan disembunyikan, tiada ayat).
  List<Announcement> update({
    required bool voiceEnabled,
    required bool overspeed,
    required int? limitKmh,
    required DateTime now,
    required VoiceLanguage language,
  }) {
    final out = <Announcement>[];
    if (overspeed && !_wasOverspeed) {
      final last = _lastChime;
      if (last == null || now.difference(last) >= overspeedCooldown) {
        _lastChime = now;
        if (voiceEnabled) {
          out.add(
            const Announcement(
              kind: AnnouncementKind.speeding,
              text: '',
              chime: ChimeKind.warning,
            ),
          );
        }
      }
    }
    _wasOverspeed = overspeed;

    if (limitKmh != null && limitKmh != _spokenLimit) {
      _spokenLimit = limitKmh;
      if (voiceEnabled) {
        out.add(
          Announcement(
            kind: AnnouncementKind.speedLimit,
            text: InstructionText(language).speedLimitChanged(limitKmh),
            chime: null,
          ),
        );
      }
    }
    return out;
  }
}
