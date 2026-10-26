import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fgmap/features/route_preview/presentation/route_format.dart';
import 'package:fgmap/l10n/generated/app_localizations.dart';

void main() {
  final ms = lookupAppLocalizations(const Locale('ms'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('formatDistance', () {
    test('di bawah 1 km dalam meter, dibundar ke 10 m', () {
      expect(formatDistance(ms, 800), '800 m');
      expect(formatDistance(ms, 804), '800 m');
      expect(formatDistance(ms, 994), '990 m');
      expect(formatDistance(ms, 996), '1.0 km');
    });

    test('sangat pendek tidak menjadi 0 m', () {
      expect(formatDistance(ms, 2), '10 m');
    });

    test('satu perpuluhan di bawah 100 km', () {
      expect(formatDistance(ms, 1000), '1.0 km');
      expect(formatDistance(ms, 67049), '67.0 km');
      expect(formatDistance(en, 17812), '17.8 km');
    });

    test('nombor bulat bermula 100 km', () {
      expect(formatDistance(ms, 359300), '359 km');
    });
  });

  group('formatDuration', () {
    test('minit', () {
      expect(formatDuration(ms, 3477), '58 min');
      expect(formatDuration(en, 3477), '58 min');
    });

    test('sekurang-kurangnya 1 minit', () {
      expect(formatDuration(ms, 0), '1 min');
      expect(formatDuration(ms, 20), '1 min');
    });

    test('jam dan minit, mengikut bahasa', () {
      expect(formatDuration(ms, 12840), '3 j 34 min');
      expect(formatDuration(en, 12840), '3 h 34 min');
      expect(formatDuration(ms, 3600), '1 j 0 min');
    });

    test('59.5 minit dibundar ke 1 j 0 min, bukan 60 min', () {
      expect(formatDuration(ms, 3570), '1 j 0 min');
    });
  });
}
