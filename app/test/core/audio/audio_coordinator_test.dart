import 'package:fgmap/core/audio/audio_coordinator.dart';
import 'package:fgmap/features/navigation/data/voice_guide.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:flutter_test/flutter_test.dart';

class _Target implements DuckTarget {
  final events = <String>[];
  bool fail = false;

  @override
  Future<void> onSpeechStart() async {
    events.add('start');
    if (fail) throw StateError('rosak');
  }

  @override
  Future<void> onSpeechEnd() async => events.add('end');
}

class _Tts implements TtsEngine {
  _Tts(this.log);
  final List<String> log;
  bool fail = false;

  @override
  Future<void> speak(String text, VoiceLanguage language) async {
    log.add('speak:$text');
    if (fail) throw StateError('tts rosak');
  }

  @override
  Future<void> stop() async {}
}

class _Chimes implements ChimePlayer {
  _Chimes(this.log);
  final List<String> log;

  @override
  Future<void> play(ChimeKind kind) async => log.add('chime:${kind.name}');

  @override
  Future<void> stop() async {}
}

void main() {
  test('dikira rujukan: bertindih dikira satu tempoh', () async {
    final c = AudioCoordinator();
    final t = _Target();
    c.register(t);
    await c.beginSpeech();
    await c.beginSpeech();
    expect(t.events, ['start']);
    await c.endSpeech();
    expect(t.events, ['start']);
    await c.endSpeech();
    expect(t.events, ['start', 'end']);
    await c.endSpeech(); // berlebihan: diabaikan
    expect(t.events, ['start', 'end']);
    expect(c.speaking, isFalse);
  });

  test('sasaran yang mendaftar semasa bercakap terus diperlahankan; gagal tidak menyekat', () async {
    final c = AudioCoordinator();
    await c.beginSpeech();
    final t = _Target()..fail = true;
    c.register(t);
    await Future<void>.delayed(Duration.zero);
    expect(t.events, ['start']);
    await c.endSpeech();
    expect(t.events, ['start', 'end']);
    c.unregister(t);
    await c.beginSpeech();
    expect(t.events, hasLength(2));
  });

  test('QueuedVoiceGuide membalut bunyi isyarat + ayat dengan begin/end, juga apabila TTS gagal', () async {
    final c = AudioCoordinator();
    final target = _Target();
    c.register(target);
    final log = <String>[];
    final tts = _Tts(log);
    final guide = QueuedVoiceGuide(
      tts: tts,
      chimes: _Chimes(log),
      coordinator: c,
    );
    await guide.announce(
      const Announcement(
        kind: AnnouncementKind.now,
        text: 'Belok kiri',
        chime: ChimeKind.now,
      ),
      VoiceLanguage.ms,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(log, ['chime:now', 'speak:Belok kiri']);
    expect(target.events, ['start', 'end']);

    tts.fail = true;
    await guide.announce(
      const Announcement(
        kind: AnnouncementKind.near,
        text: 'Belok kanan',
        chime: null,
      ),
      VoiceLanguage.ms,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(target.events, ['start', 'end', 'start', 'end']);
    await guide.dispose();
  });
}
