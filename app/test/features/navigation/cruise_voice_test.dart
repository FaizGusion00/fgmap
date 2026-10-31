import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/cruise_voice.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/speed_bubble_data.dart';
import 'package:fgmap/features/navigation/domain/speed_limit_trail.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 6, 1, 9);

  group('SpeedBubbleData', () {
    test('km/j, dan papan had hanya bila had dipulangkan', () {
      const moving = SpeedBubbleData(speedMps: 27.8);
      expect(moving.kmh, 100);
      expect(moving.showLimit, isFalse);

      const limited = SpeedBubbleData(speedMps: 13.9, limitKmh: 60);
      expect(limited.kmh, 50);
      expect(limited.showLimit, isTrue);
      expect(limited.limitKmh, 60);
    });
  });

  group('CruiseVoice', () {
    test('loceng laju berlebihan sekali setiap cooldown', () {
      final voice = CruiseVoice();
      List<Announcement> say(DateTime now, {required bool over}) =>
          voice.update(
            voiceEnabled: true,
            overspeed: over,
            limitKmh: 80,
            now: now,
            language: VoiceLanguage.ms,
          );

      final first = say(t0, over: true);
      expect(
        first.where((a) => a.kind == AnnouncementKind.speeding),
        hasLength(1),
      );
      expect(first.where((a) => a.chime == ChimeKind.warning), hasLength(1));

      expect(
        say(
          t0.add(const Duration(seconds: 5)),
          over: true,
        ).where((a) => a.kind == AnnouncementKind.speeding),
        isEmpty,
      );
      expect(
        say(t0.add(const Duration(seconds: 6)), over: false),
        isNot(
          contains(
            isA<Announcement>().having(
              (a) => a.kind,
              'kind',
              AnnouncementKind.speeding,
            ),
          ),
        ),
      );
      expect(
        say(
          t0.add(const Duration(seconds: 10)),
          over: true,
        ).where((a) => a.kind == AnnouncementKind.speeding),
        isEmpty,
      );
      // Kekal laju berlebihan tidak berbunyi lagi. Masuk semula selepas cooldown baharu berbunyi sekali.
      expect(
        say(
          t0.add(const Duration(seconds: 21)),
          over: false,
        ).where((a) => a.kind == AnnouncementKind.speeding),
        isEmpty,
      );
      final again = say(t0.add(const Duration(seconds: 26)), over: true);
      expect(
        again.where((a) => a.kind == AnnouncementKind.speeding),
        hasLength(1),
      );
    });

    test('had yang bertukar disebut sekali', () {
      final voice = CruiseVoice();
      List<Announcement> say(int? limit) => voice.update(
        voiceEnabled: true,
        overspeed: false,
        limitKmh: limit,
        now: t0,
        language: VoiceLanguage.ms,
      );

      final first = say(80);
      expect(first.single.kind, AnnouncementKind.speedLimit);
      expect(first.single.text, 'Had laju 80');
      expect(
        say(80).where((a) => a.kind == AnnouncementKind.speedLimit),
        isEmpty,
      );
      final changed = say(60);
      expect(changed.single.text, 'Had laju 60');
      expect(
        say(60).where((a) => a.kind == AnnouncementKind.speedLimit),
        isEmpty,
      );

      final english = CruiseVoice().update(
        voiceEnabled: true,
        overspeed: false,
        limitKmh: 90,
        now: t0,
        language: VoiceLanguage.en,
      );
      expect(english.single.text, 'Speed limit 90');
    });

    test('suara dimatikan: tiada loceng dan tiada ayat', () {
      final voice = CruiseVoice();
      expect(
        voice.update(
          voiceEnabled: false,
          overspeed: true,
          limitKmh: 80,
          now: t0,
          language: VoiceLanguage.en,
        ),
        isEmpty,
      );
    });
  });

  group('SpeedLimitTrail', () {
    test('segar setiap 20 s atau 250 m', () {
      final trail = SpeedLimitTrail();
      const a = GeoPoint(3, 101);
      final b = destinationPoint(a, 90, 40);
      trail.add(a);
      expect(trail.due(t0, a), isFalse);
      trail.add(b);
      expect(trail.due(t0, b), isTrue);
      trail.markQueried(t0, b);
      expect(trail.due(t0.add(const Duration(seconds: 10)), b), isFalse);
      final far = destinationPoint(b, 90, 250);
      expect(trail.due(t0.add(const Duration(seconds: 10)), far), isTrue);
      expect(trail.due(t0.add(const Duration(seconds: 20)), b), isTrue);
    });
  });
}
