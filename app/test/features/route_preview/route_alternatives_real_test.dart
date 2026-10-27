import 'dart:io';

import 'package:fgmap/features/route_preview/data/valhalla_codec.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/route_options_merge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respons SEBENAR Valhalla awam (FOSSGIS, 2026-10-27; `alternates: 2`) bagi perjalanan dari KLCC / Pulau
/// Pinang. Menguji penggabungan pada geometri sebenar, bukan laluan sintetik: pendua palsu, label dan
/// "Disyorkan" yang menyesatkan.
List<RouteOption> _load(String name) => parseRouteResponse(
  File('test/fixtures/alternatives/${name}_alt2.json').readAsStringSync(),
  source: RouteSource.online,
);

void main() {
  for (final name in ['t25km', 't60km', 't140km', 'penang']) {
    group('laluan sebenar $name', () {
      final raw = _load(name);

      test('respons ada laluan utama + alternatif', () {
        expect(raw.length, inInclusiveRange(2, 3));
      });

      test(
        'alternatif sebenar yang berbeza tidak digugurkan sebagai pendua',
        () {
          final merged = mergeRouteCandidates(standard: raw);
          expect(merged.length, greaterThanOrEqualTo(2));
        },
      );

      test(
        'tepat satu Disyorkan dan ia tidak lebih jauh DAN lebih lama daripada yang lain',
        () {
          final merged = mergeRouteCandidates(standard: raw);
          final rec = merged.where((r) => r.label == RouteLabel.recommended);
          expect(rec, hasLength(1));
          final r = rec.single;
          for (final o in merged) {
            final worseBoth =
                r.distanceM - o.distanceM >= o.distanceM * 0.03 &&
                r.durationS - o.durationS >= o.durationS * 0.03;
            expect(
              worseBoth,
              isFalse,
              reason:
                  '${r.distanceM}m/${r.durationS}s vs ${o.distanceM}m/${o.durationS}s',
            );
          }
        },
      );

      test('Terpantas = masa minimum; Terpendek = jarak minimum', () {
        final merged = mergeRouteCandidates(standard: raw);
        final fastest = merged
            .map((r) => r.durationS)
            .reduce((a, b) => a < b ? a : b);
        final shortest = merged
            .map((r) => r.distanceM)
            .reduce((a, b) => a < b ? a : b);
        for (final r in merged) {
          if (r.label == RouteLabel.fastest) expect(r.durationS, fastest);
          if (r.label == RouteLabel.shortest) expect(r.distanceM, shortest);
        }
      });
    });
  }

  test(
    'gabungan semua perjalanan sebenar memberi sekurang-kurangnya 3 pilihan berbeza (alternates 2)',
    () {
      for (final name in ['t25km', 't60km', 'penang']) {
        final merged = mergeRouteCandidates(standard: _load(name));
        expect(merged.length, greaterThanOrEqualTo(3), reason: name);
      }
    },
  );
}
