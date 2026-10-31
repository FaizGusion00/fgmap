import 'package:flutter/foundation.dart';

/// Pratetap penyama (equalizer) 5 jalur (bes -> trebel), dalam dB. Dipetakan ke jalur sebenar
/// peranti mengikut frekuensi tengah oleh pemain.
enum EqPreset {
  normal,
  bass,
  treble,
  vocal,
  custom;

  static EqPreset fromName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return EqPreset.normal;
  }
}

const eqBands = 5;

/// Gandaan setiap pratetap (dB). `custom` menggunakan [EqSettings.customGainsDb].
const eqPresetGainsDb = <EqPreset, List<double>>{
  EqPreset.normal: [0, 0, 0, 0, 0],
  EqPreset.bass: [6, 4, 0, 0, 0],
  EqPreset.treble: [0, 0, 0, 4, 6],
  // Suara/podcast: kurangkan bes, angkat 1-4 kHz supaya kata-kata jelas dalam kereta.
  EqPreset.vocal: [-2, 0, 4, 3, 0],
};

/// Had gandaan tersuai yang dibenarkan UI (peranti mungkin lebih sempit; dipotong semasa dipakai).
const eqMinDb = -10.0;
const eqMaxDb = 10.0;

@immutable
class EqSettings {
  const EqSettings({
    this.enabled = false,
    this.preset = EqPreset.normal,
    this.customGainsDb = const [0, 0, 0, 0, 0],
  });

  final bool enabled;
  final EqPreset preset;
  final List<double> customGainsDb;

  /// Gandaan berkesan untuk pratetap semasa.
  List<double> get gainsDb =>
      preset == EqPreset.custom ? customGainsDb : eqPresetGainsDb[preset]!;

  EqSettings copyWith({
    bool? enabled,
    EqPreset? preset,
    List<double>? customGainsDb,
  }) => EqSettings(
    enabled: enabled ?? this.enabled,
    preset: preset ?? this.preset,
    customGainsDb: customGainsDb ?? this.customGainsDb,
  );

  @override
  bool operator ==(Object other) =>
      other is EqSettings &&
      other.enabled == enabled &&
      other.preset == preset &&
      listEquals(other.customGainsDb, customGainsDb);

  @override
  int get hashCode =>
      Object.hash(enabled, preset, Object.hashAll(customGainsDb));
}

/// Memetakan [gainsDb] (5 jalur UI) kepada N jalur peranti mengikut kedudukan relatif, dipotong
/// kepada julat peranti. Fungsi tulen supaya boleh diuji tanpa plugin.
List<double> mapGainsToBands(
  List<double> gainsDb, {
  required int deviceBands,
  required double minDb,
  required double maxDb,
}) {
  if (deviceBands <= 0) return const [];
  if (gainsDb.isEmpty) return List.filled(deviceBands, 0);
  return [
    for (var i = 0; i < deviceBands; i++)
      () {
        final pos = deviceBands == 1
            ? 0.0
            : i * (gainsDb.length - 1) / (deviceBands - 1);
        final lo = pos.floor();
        final hi = pos.ceil().clamp(0, gainsDb.length - 1);
        final t = pos - lo;
        final v = gainsDb[lo] * (1 - t) + gainsDb[hi] * t;
        return v.clamp(minDb, maxDb).toDouble();
      }(),
  ];
}
