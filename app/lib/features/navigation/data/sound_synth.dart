import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/announcement_planner.dart';

/// Satu nada: frekuensi (Hz), mula (ms), tempoh (ms), kekuatan 0..1.
typedef Tone = ({double hz, int startMs, int durationMs, double gain});

const _sampleRate = 22050;

/// Resipi bunyi isyarat. Nada loceng lembut (asas + harmonik kedua) dengan serangan pantas dan
/// susutan eksponen: jelas di atas bunyi jalan tetapi tidak menyakitkan telinga.
const Map<ChimeKind, List<Tone>> chimeTones = {
  // Amaran awal: dua not naik.
  ChimeKind.early: [
    (hz: 659.25, startMs: 0, durationMs: 220, gain: 0.55),
    (hz: 880.0, startMs: 130, durationMs: 300, gain: 0.6),
  ],
  // Sekarang: ping terang berganda.
  ChimeKind.now: [
    (hz: 987.77, startMs: 0, durationMs: 150, gain: 0.7),
    (hz: 987.77, startMs: 150, durationMs: 220, gain: 0.7),
  ],
  // Mengira semula: dua not turun.
  ChimeKind.reroute: [
    (hz: 784.0, startMs: 0, durationMs: 200, gain: 0.55),
    (hz: 587.33, startMs: 140, durationMs: 300, gain: 0.55),
  ],
  // Tiba: arpeggio naik.
  ChimeKind.arrive: [
    (hz: 523.25, startMs: 0, durationMs: 220, gain: 0.5),
    (hz: 659.25, startMs: 150, durationMs: 220, gain: 0.55),
    (hz: 783.99, startMs: 300, durationMs: 420, gain: 0.6),
  ],
  // Amaran (GPS hilang): dua not rendah.
  ChimeKind.warning: [
    (hz: 440.0, startMs: 0, durationMs: 170, gain: 0.6),
    (hz: 440.0, startMs: 220, durationMs: 220, gain: 0.6),
  ],
};

/// Tempoh bunyi (ms) sehingga nada terakhir habis.
int chimeDurationMs(ChimeKind kind) =>
    chimeTones[kind]!.map((t) => t.startMs + t.durationMs).reduce(math.max);

/// Menjana fail WAV PCM 16-bit mono untuk [kind]. Dijana dalam kod supaya tiada aset binari.
Uint8List synthChime(ChimeKind kind) {
  final tones = chimeTones[kind]!;
  final totalSamples = (chimeDurationMs(kind) + 60) * _sampleRate ~/ 1000;
  final mix = Float64List(totalSamples);

  for (final tone in tones) {
    final start = tone.startMs * _sampleRate ~/ 1000;
    final length = tone.durationMs * _sampleRate ~/ 1000;
    for (var i = 0; i < length && start + i < totalSamples; i++) {
      final t = i / _sampleRate;
      // Serangan 6 ms, kemudian susutan eksponen.
      final attack = math.min(1.0, i / (0.006 * _sampleRate));
      final decay = math.exp(-5.5 * i / length);
      final wave =
          math.sin(2 * math.pi * tone.hz * t) +
          0.28 * math.sin(2 * math.pi * tone.hz * 2 * t);
      mix[start + i] += wave * attack * decay * tone.gain / 1.28;
    }
  }

  final data = ByteData(44 + totalSamples * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + totalSamples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, totalSamples * 2, Endian.little);
  for (var i = 0; i < totalSamples; i++) {
    final v = (mix[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}
