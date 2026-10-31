import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/log.dart';
import '../domain/azan_plan.dart';
import '../domain/prayer.dart';

/// Teks notifikasi mengikut bahasa; diberi oleh lapisan UI (l10n) supaya lapisan data tiada
/// kebergantungan pada BuildContext.
@immutable
class AzanNotificationTexts {
  const AzanNotificationTexts({
    required this.locale,
    required this.prayerNames,
    required this.azanTitle,
    required this.azanBody,
    required this.reminderTitle,
    required this.reminderBody,
    required this.channelFull,
    required this.channelShort,
    required this.channelSilent,
    required this.channelReminder,
  });

  final Locale locale;
  final Map<Prayer, String> prayerNames;

  /// Tajuk azan, cth. "Waktu {prayer}".
  final String Function(String prayer) azanTitle;
  final String azanBody;
  final String Function(String prayer, int minutes) reminderTitle;
  final String reminderBody;
  final String channelFull;
  final String channelShort;
  final String channelSilent;
  final String channelReminder;
}

/// Penjadual notifikasi azan. Antara muka supaya pengawal boleh diuji dengan palsu.
abstract interface class AzanScheduler {
  /// Pangkalan data zon masa, plugin dan saluran. Selamat dipanggil berulang kali.
  Future<void> ensureInitialized();

  /// Kebenaran notifikasi (Android 13+ POST_NOTIFICATIONS; iOS alert + sound).
  Future<bool> requestPermissions();

  /// Android 12+: adakah penggera tepat dibenarkan? Platform lain: true.
  Future<bool> canScheduleExact();

  /// Buka tetapan sistem untuk membenarkan penggera tepat (Android).
  Future<void> openExactAlarmSettings();

  /// Gantikan semua notifikasi tertunda dengan [items].
  Future<void> replaceAll(
    List<ScheduledAzan> items,
    AzanNotificationTexts texts,
  );

  Future<void> cancelAll();

  /// ID notifikasi yang masih tertunda.
  Future<Set<int>> pendingIds();

  /// Muatan (`azan:<waktu>:<iso>`) apabila pengguna mengetik notifikasi.
  Stream<String> get taps;
}

/// Pelaksanaan sebenar melalui `flutter_local_notifications` + `timezone`.
///
/// Saluran Android: bunyi saluran tidak boleh diubah selepas dicipta, jadi setiap profil bunyi ada
/// saluran sendiri (`_v1`; naikkan versi jika bunyi ditukar). Azan penuh menggunakan atribut audio
/// ALARM supaya kedengaran walaupun kelantangan notifikasi rendah (tetap menghormati Jangan Ganggu).
class LocalNotificationsAzanScheduler implements AzanScheduler {
  LocalNotificationsAzanScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    Future<String?> Function()? timezoneId,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _timezoneId = timezoneId ?? _deviceTimezoneId;

  static const channelFull = 'azan_full_v1';
  static const channelShort = 'azan_short_v1';
  static const channelSilent = 'azan_silent_v1';
  static const channelReminder = 'azan_reminder_v1';
  static const payloadPrefix = 'azan:';

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String?> Function() _timezoneId;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _init;

  static Future<String?> _deviceTimezoneId() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> ensureInitialized() => _init ??= () async {
    tzdata.initializeTimeZones();
    final id = await _timezoneId();
    try {
      tz.setLocalLocation(tz.getLocation(id ?? 'Asia/Kuala_Lumpur'));
    } on Object {
      // Peranti dengan ID zon yang tidak dikenali: Malaysia tiada DST, jadi KL selamat.
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith(payloadPrefix)) {
          _taps.add(payload);
        }
      },
    );
    // Dibuka daripada notifikasi semasa app ditutup.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.startsWith(payloadPrefix)) {
      _taps.add(payload);
    }
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      !kIsWeb && Platform.isAndroid
      ? _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;

  IOSFlutterLocalNotificationsPlugin? get _ios => !kIsWeb && Platform.isIOS
      ? _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
      : null;

  @override
  Future<bool> requestPermissions() async {
    await ensureInitialized();
    try {
      final android = _android;
      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }
      final ios = _ios;
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
    } on Object catch (e) {
      logDiag('Kebenaran notifikasi azan gagal: $e');
      return false;
    }
    return true;
  }

  @override
  Future<bool> canScheduleExact() async {
    await ensureInitialized();
    final android = _android;
    if (android == null) return true;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> openExactAlarmSettings() async {
    await ensureInitialized();
    try {
      await _android?.requestExactAlarmsPermission();
    } on Object catch (e) {
      logDiag('Tetapan penggera tepat gagal dibuka: $e');
    }
  }

  @override
  Future<void> replaceAll(
    List<ScheduledAzan> items,
    AzanNotificationTexts texts,
  ) async {
    await ensureInitialized();
    await _createChannels(texts);
    await _plugin.cancelAllPendingNotifications();
    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);
    for (final item in items) {
      final when = tz.TZDateTime.from(item.at, tz.local);
      if (!when.isAfter(now)) continue;
      final name = texts.prayerNames[item.prayer] ?? item.prayer.name;
      try {
        await _plugin.zonedSchedule(
          id: item.id,
          scheduledDate: when,
          title: item.reminder
              ? texts.reminderTitle(name, item.reminderMinutes)
              : texts.azanTitle(name),
          body: item.reminder ? texts.reminderBody : texts.azanBody,
          notificationDetails: _details(item, texts),
          androidScheduleMode: mode,
          payload:
              '$payloadPrefix${item.prayer.name}:${item.at.toIso8601String()}',
        );
      } on Object catch (e) {
        logDiag('Jadual azan gagal (${item.prayer.name}): $e');
      }
    }
  }

  NotificationDetails _details(ScheduledAzan item, AzanNotificationTexts t) {
    final (channelId, channelName, sound, usage, playSound) = item.reminder
        ? (
            channelReminder,
            t.channelReminder,
            null,
            AudioAttributesUsage.notification,
            true,
          )
        : switch (item.sound) {
            AzanSound.full => (
              channelFull,
              t.channelFull,
              const RawResourceAndroidNotificationSound('azan'),
              AudioAttributesUsage.alarm,
              true,
            ),
            AzanSound.short => (
              channelShort,
              t.channelShort,
              const RawResourceAndroidNotificationSound('azan_short'),
              AudioAttributesUsage.notification,
              true,
            ),
            AzanSound.silent => (
              channelSilent,
              t.channelSilent,
              null,
              AudioAttributesUsage.notification,
              false,
            ),
          };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound,
        sound: sound,
        audioAttributesUsage: usage,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        // iOS mengehadkan bunyi notifikasi kepada 30 saat: versi pendek sahaja.
        sound: item.reminder || item.sound == AzanSound.silent
            ? null
            : 'azan_short.caf',
        presentSound: item.sound != AzanSound.silent || item.reminder,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> _createChannels(AzanNotificationTexts t) async {
    final android = _android;
    if (android == null) return;
    final channels = [
      AndroidNotificationChannel(
        channelFull,
        t.channelFull,
        importance: Importance.max,
        sound: const RawResourceAndroidNotificationSound('azan'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      AndroidNotificationChannel(
        channelShort,
        t.channelShort,
        importance: Importance.max,
        sound: const RawResourceAndroidNotificationSound('azan_short'),
      ),
      AndroidNotificationChannel(
        channelSilent,
        t.channelSilent,
        importance: Importance.high,
        playSound: false,
      ),
      AndroidNotificationChannel(
        channelReminder,
        t.channelReminder,
        importance: Importance.high,
      ),
    ];
    for (final c in channels) {
      try {
        await android.createNotificationChannel(c);
      } on Object catch (e) {
        logDiag('Saluran notifikasi ${c.id} gagal: $e');
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    await ensureInitialized();
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<Set<int>> pendingIds() async {
    await ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final p in pending) p.id};
  }

  @override
  Stream<String> get taps => _taps.stream;
}

final azanSchedulerProvider = Provider<AzanScheduler>(
  (ref) => LocalNotificationsAzanScheduler(),
);
