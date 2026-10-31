import 'package:fgmap/features/music/domain/eq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pratetap: 5 jalur setiap satu, normal semua sifar', () {
    for (final p in EqPreset.values) {
      if (p == EqPreset.custom) continue;
      expect(eqPresetGainsDb[p], hasLength(eqBands), reason: p.name);
    }
    expect(eqPresetGainsDb[EqPreset.normal], everyElement(0));
    expect(eqPresetGainsDb[EqPreset.bass]!.first, greaterThan(0));
    expect(eqPresetGainsDb[EqPreset.treble]!.last, greaterThan(0));
  });

  test('EqSettings.gainsDb: pratetap atau tersuai', () {
    const s = EqSettings(preset: EqPreset.bass);
    expect(s.gainsDb, eqPresetGainsDb[EqPreset.bass]);
    const c = EqSettings(preset: EqPreset.custom, customGainsDb: [1, 2, 3, 4, 5]);
    expect(c.gainsDb, [1, 2, 3, 4, 5]);
    expect(c.copyWith(preset: EqPreset.normal).gainsDb, everyElement(0));
  });

  test('pemetaan ke jalur peranti: sama bilangan, lebih, kurang, dipotong', () {
    const gains = [6.0, 4.0, 0.0, 4.0, 6.0];
    expect(mapGainsToBands(gains, deviceBands: 5, minDb: -15, maxDb: 15), gains);
    final ten = mapGainsToBands(gains, deviceBands: 10, minDb: -15, maxDb: 15);
    expect(ten, hasLength(10));
    expect(ten.first, 6);
    expect(ten.last, 6);
    expect(ten[4], lessThan(ten.first));
    final three = mapGainsToBands(gains, deviceBands: 3, minDb: -15, maxDb: 15);
    expect(three, [6, 0, 6]);
    // Julat peranti lebih sempit: dipotong.
    expect(mapGainsToBands(gains, deviceBands: 5, minDb: -3, maxDb: 3), [3, 3, 0, 3, 3]);
    expect(mapGainsToBands(gains, deviceBands: 0, minDb: -3, maxDb: 3), isEmpty);
    expect(mapGainsToBands(const [], deviceBands: 2, minDb: -3, maxDb: 3), [0, 0]);
  });
}
