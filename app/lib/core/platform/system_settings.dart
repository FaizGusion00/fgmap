import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/log.dart';

/// Pintasan ke tetapan sistem yang tidak dilindungi plugin lain (Android: tetapan notifikasi app dan
/// pengecualian bateri; iOS: tetapan app). Antara muka supaya ujian boleh memalsukannya.
abstract interface class SystemSettings {
  /// Buka skrin notifikasi app. Mengembalikan false jika gagal dibuka.
  Future<bool> openNotificationSettings();

  /// Buka senarai pengecualian pengoptimuman bateri (Android sahaja). Senarai ini lalai menapis
  /// "Not optimized" sehingga app yang masih dioptimumkan tidak kelihatan; guna
  /// [requestIgnoreBatteryOptimizations] dahulu.
  Future<bool> openBatterySettings();

  /// Android: tunjuk dialog sistem "benarkan app ini berjalan di latar belakang" terus untuk app ini.
  /// Jika dialog tidak tersedia, buka senarai bateri, kemudian butiran app. True jika sesuatu dibuka
  /// atau app sudah dikecualikan. Platform lain: false.
  Future<bool> requestIgnoreBatteryOptimizations();

  /// Android: app dikecualikan daripada pengoptimuman bateri? Platform lain: true.
  Future<bool> isIgnoringBatteryOptimizations();
}

class PlatformSystemSettings implements SystemSettings {
  const PlatformSystemSettings();

  static const _channel = MethodChannel('com.fguniversalempire.fgmaps/system');

  bool get _android => !kIsWeb && Platform.isAndroid;

  Future<bool> _call(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on Object catch (e) {
      logDiag('Tetapan sistem ($method) gagal: $e');
      return false;
    }
  }

  @override
  Future<bool> openNotificationSettings() async {
    if (_android) return _call('openNotificationSettings');
    if (!kIsWeb && Platform.isIOS) {
      return launchUrl(Uri.parse('app-settings:'));
    }
    return false;
  }

  @override
  Future<bool> openBatterySettings() async =>
      _android ? _call('openBatterySettings') : false;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async =>
      _android ? _call('requestIgnoreBatteryOptimizations') : false;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async =>
      _android ? _call('isIgnoringBatteryOptimizations') : true;
}

final systemSettingsProvider = Provider<SystemSettings>(
  (ref) => const PlatformSystemSettings(),
);
