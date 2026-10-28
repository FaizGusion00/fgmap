import 'package:fgmap/features/navigation/domain/cruise_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 8);

  CruiseGate gate() => CruiseGate();

  test('belum bergerak: kekal peta biasa', () {
    final g = gate();
    expect(
      g.update(time: t0, speedMps: 1, headingKnown: true, blocked: false),
      isFalse,
    );
    expect(
      g.update(
        time: t0.add(const Duration(minutes: 5)),
        speedMps: 0,
        headingKnown: false,
        blocked: false,
      ),
      isFalse,
    );
  });

  test('masuk selepas 1.5 s pada atau melebihi 2.5 m/s dengan arah', () {
    final g = gate();
    expect(
      g.update(time: t0, speedMps: 3, headingKnown: true, blocked: false),
      isFalse,
    );
    expect(
      g.update(
        time: t0.add(const Duration(milliseconds: 1400)),
        speedMps: 3,
        headingKnown: true,
        blocked: false,
      ),
      isFalse,
    );
    expect(
      g.update(
        time: t0.add(const Duration(milliseconds: 1500)),
        speedMps: 2.5,
        headingKnown: true,
        blocked: false,
      ),
      isTrue,
    );
  });

  test('tiada arah: tidak masuk', () {
    final g = gate();
    expect(
      g.update(
        time: t0.add(const Duration(seconds: 5)),
        speedMps: 10,
        headingKnown: false,
        blocked: false,
      ),
      isFalse,
    );
  });

  test('berhenti singkat kekal 3D; berhenti 45 s kembali rata', () {
    final g = gate();
    g.seedActive();
    expect(
      g.update(
        time: t0,
        speedMps: 0,
        headingKnown: false,
        blocked: false,
      ),
      isTrue,
    );
    expect(
      g.update(
        time: t0.add(const Duration(seconds: 20)),
        speedMps: 0.2,
        headingKnown: false,
        blocked: false,
      ),
      isTrue,
    );
    expect(
      g.update(
        time: t0.add(const Duration(seconds: 44)),
        speedMps: 0,
        headingKnown: false,
        blocked: false,
      ),
      isTrue,
    );
    expect(
      g.update(
        time: t0.add(const Duration(seconds: 45)),
        speedMps: 0.4,
        headingKnown: false,
        blocked: false,
      ),
      isFalse,
    );
  });

  test('navigasi menyekat cruise serta-merta', () {
    final g = gate();
    g.seedActive();
    expect(
      g.update(time: t0, speedMps: 15, headingKnown: true, blocked: true),
      isFalse,
    );
    expect(g.active, isFalse);
  });
}
