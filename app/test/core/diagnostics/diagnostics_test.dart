import 'dart:ui';

import 'package:fgmap/core/diagnostics/error_log.dart';
import 'package:fgmap/core/diagnostics/frame_monitor.dart';
import 'package:fgmap/core/diagnostics/global_errors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ErrorLog', () {
    test('merekod mesej dibersihkan daripada URL dan koordinat', () {
      final log = ErrorLog();
      log.record(
        'async',
        Exception(
          'gagal https://valhalla.example/route?lat=3.15790&lon=101.71160 pada 3.1579, 101.7116',
        ),
        StackTrace.fromString('#0 fungsi (package:fgmap/a.dart:1:1)\n#1 lain'),
      );
      final e = log.entries.single;
      expect(e.message, isNot(contains('valhalla')));
      expect(e.message, isNot(contains('3.1579')));
      expect(e.message, isNot(contains('101.71')));
      expect(e.source, 'async');
      expect(e.stack, contains('package:fgmap/a.dart'));
    });

    test('cincin 50 entri: yang lama dibuang; mesej dan jejak dipendekkan', () {
      final log = ErrorLog();
      for (var i = 0; i < 60; i++) {
        log.record('flutter', 'ralat $i', null);
      }
      expect(log.length, 50);
      expect(log.entries.first.message, 'ralat 10');
      expect(log.entries.last.message, 'ralat 59');

      log.record(
        'flutter',
        'x' * 5000,
        StackTrace.fromString(List.filled(40, 'baris').join('\n')),
      );
      expect(
        log.entries.last.message.length,
        lessThanOrEqualTo(ErrorLog.maxMessageLength + 1),
      );
      expect(
        log.entries.last.stack.split('\n'),
        hasLength(ErrorLog.maxStackLines),
      );
    });

    test(
      'disimpan dan dipulihkan; log rosak diabaikan; clear memadam',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        ErrorLog(prefs: prefs).record('flutter', 'satu', null);
        final reloaded = ErrorLog(prefs: prefs);
        expect(reloaded.entries.single.message, 'satu');
        reloaded.clear();
        expect(ErrorLog(prefs: prefs).length, 0);
        expect(prefs.containsKey('diag.errors.v1'), isFalse);

        await prefs.setString('diag.errors.v1', '{rosak');
        expect(ErrorLog(prefs: prefs).length, 0);
      },
    );

    test('laporan: versi, bilangan dan entri terkini dahulu', () {
      var t = DateTime(2026, 10, 26, 10);
      final log = ErrorLog(clock: () => t);
      log.record('flutter', 'pertama', null);
      t = t.add(const Duration(minutes: 1));
      log.record('async', 'kedua', null);
      final report = log.report(appVersion: '0.5.0+10');
      expect(report, contains('Versi: 0.5.0+10'));
      expect(report, contains('Bilangan: 2'));
      expect(report.indexOf('kedua'), lessThan(report.indexOf('pertama')));
    });
  });

  group('installGlobalErrorHandling', () {
    late FlutterExceptionHandler? previousFlutter;
    late ErrorCallback? previousPlatform;
    late ErrorWidgetBuilder previousBuilder;

    setUp(() {
      previousFlutter = FlutterError.onError;
      previousPlatform = PlatformDispatcher.instance.onError;
      previousBuilder = ErrorWidget.builder;
    });

    tearDown(() {
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
      ErrorWidget.builder = previousBuilder;
    });

    test('ralat Flutter dan async direkod; async dianggap dikendalikan', () {
      final log = ErrorLog();
      installGlobalErrorHandling(log);
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('boom'),
          stack: StackTrace.current,
        ),
      );
      final handled = PlatformDispatcher.instance.onError!(
        ArgumentError('async boom'),
        StackTrace.current,
      );
      expect(handled, isTrue);
      expect(log.entries.map((e) => e.source), ['flutter', 'async']);
    });

    testWidgets('FriendlyErrorWidget memaparkan mesej ramah', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FriendlyErrorWidget())),
      );
      expect(find.text('Bahagian ini tidak dapat dipaparkan.'), findsOneWidget);
    });
  });

  group('JankStats', () {
    test('mengira jank dan jank teruk mengikut anggaran 16.7 ms', () {
      final stats = JankStats();
      stats.add(
        const Duration(milliseconds: 5),
        const Duration(milliseconds: 4),
      );
      stats.add(
        const Duration(milliseconds: 20),
        const Duration(milliseconds: 4),
      );
      stats.add(
        const Duration(milliseconds: 4),
        const Duration(milliseconds: 40),
      );
      expect(stats.frames, 3);
      expect(stats.janky, 2);
      expect(stats.severe, 1);
      expect(stats.worst, const Duration(milliseconds: 40));
      expect(stats.jankPercent, closeTo(66.7, 0.1));
      expect(stats.summary(), contains('3 bingkai'));
      stats.reset();
      expect(stats.frames, 0);
      expect(stats.jankPercent, 0);
    });
  });
}
