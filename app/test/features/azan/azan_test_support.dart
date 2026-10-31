import 'dart:async';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/azan_player.dart';
import 'package:fgmap/features/azan/data/azan_scheduler.dart';
import 'package:fgmap/features/azan/domain/azan_plan.dart';
import 'package:fgmap/features/azan/domain/prayer.dart';
import 'package:fgmap/features/azan/domain/prayer_calculator.dart';
import 'package:fgmap/features/azan/domain/prayer_times.dart';
import 'package:flutter/material.dart';

/// Waktu tetap: Subuh 05:50, Syuruk 07:05, Zohor 13:05, Asar 16:25, Maghrib 19:05, Isyak 20:15.
class FakePrayerCalculator implements PrayerCalculator {
  FakePrayerCalculator({this.minuteOffset = 0});

  /// Ditambah pada semua waktu (untuk membezakan lokasi/kaedah dalam ujian).
  final int minuteOffset;
  final calls = <(GeoPoint, DateTime, AzanMethod, AzanMadhab)>[];

  @override
  DailyPrayerTimes compute({
    required GeoPoint at,
    required DateTime day,
    required AzanMethod method,
    required AzanMadhab madhab,
  }) {
    calls.add((at, day, method, madhab));
    DateTime t(int h, int m) =>
        DateTime(day.year, day.month, day.day, h, m + minuteOffset);
    return DailyPrayerTimes(
      day: DateTime(day.year, day.month, day.day),
      times: {
        Prayer.fajr: t(5, 50),
        Prayer.sunrise: t(7, 5),
        Prayer.dhuhr: t(13, 5),
        Prayer.asr: t(16, 25 + (madhab == AzanMadhab.hanafi ? 50 : 0)),
        Prayer.maghrib: t(19, 5),
        Prayer.isha: t(20, 15),
      },
    );
  }
}

class FakeAzanScheduler implements AzanScheduler {
  bool permissionGranted = true;
  bool exact = true;
  int initCalls = 0;
  int permissionRequests = 0;
  int openExactCalls = 0;
  int cancelAllCalls = 0;
  final replaced = <List<ScheduledAzan>>[];
  AzanNotificationTexts? lastTexts;
  final tapController = StreamController<String>.broadcast();

  List<ScheduledAzan> get pending => replaced.isEmpty ? const [] : replaced.last;

  @override
  Future<void> ensureInitialized() async => initCalls++;

  @override
  Future<bool> requestPermissions() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<void> openExactAlarmSettings() async => openExactCalls++;

  @override
  Future<void> replaceAll(
    List<ScheduledAzan> items,
    AzanNotificationTexts texts,
  ) async {
    replaced.add(List.of(items));
    lastTexts = texts;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    replaced.add(const []);
  }

  @override
  Future<Set<int>> pendingIds() async => {for (final p in pending) p.id};

  @override
  Stream<String> get taps => tapController.stream;
}

class FakeAzanPlayer implements AzanPlayer {
  final played = <AzanSound>[];
  int stops = 0;
  final _completed = StreamController<void>.broadcast();

  @override
  Future<void> play(AzanSound sound) async => played.add(sound);

  @override
  Future<void> stop() async {
    stops++;
    _completed.add(null);
  }

  /// Simulasi azan tamat sendiri.
  void finish() => _completed.add(null);

  @override
  Stream<void> get completed => _completed.stream;
}

AzanNotificationTexts testTexts() => AzanNotificationTexts(
  locale: const Locale('ms'),
  prayerNames: {for (final p in Prayer.values) p: p.name},
  azanTitle: (p) => 'Waktu $p',
  azanBody: 'Telah masuk waktu solat.',
  reminderTitle: (p, n) => '$p dalam $n minit',
  reminderBody: 'Bersedia.',
  channelFull: 'Azan',
  channelShort: 'Nada',
  channelSilent: 'Senyap',
  channelReminder: 'Peringatan',
);
