import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/preferences.dart';

/// Kelas peranti untuk Mod Lite dan cadangan model AI.
enum DeviceTier { low, mid, high }

/// RAM dan teras peranti (saluran `com.fguniversalempire.fgmaps/device`). Dibaca sekali dalam `main()`
/// sebelum bingkai pertama supaya Mod Lite tidak berkelip.
@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.totalMemBytes,
    required this.lowRamDevice,
    required this.cores,
  });

  /// Tidak diketahui (ujian, platform lain): dianggap sederhana.
  static const unknown = DeviceInfo(
    totalMemBytes: 0,
    lowRamDevice: false,
    cores: 0,
  );

  final int totalMemBytes;

  /// Bendera sistem Android "RAM rendah" (Android Go dan sebagainya).
  final bool lowRamDevice;
  final int cores;

  double get totalMemGb => totalMemBytes / (1024 * 1024 * 1024);

  /// Rendah: ≤ 3 GB, bendera RAM rendah, atau ≤ 4 teras. Sederhana: ≤ 6 GB. Tinggi: selebihnya.
  DeviceTier get tier {
    if (totalMemBytes <= 0) return DeviceTier.mid;
    if (lowRamDevice || totalMemGb <= 3.2 || (cores > 0 && cores <= 4)) {
      return DeviceTier.low;
    }
    if (totalMemGb <= 6.2) return DeviceTier.mid;
    return DeviceTier.high;
  }

  static const _channel = MethodChannel('com.fguniversalempire.fgmaps/device');

  static Future<DeviceInfo> read() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('deviceInfo');
      if (raw == null) return unknown;
      return DeviceInfo(
        totalMemBytes: (raw['totalMemBytes'] as num?)?.toInt() ?? 0,
        lowRamDevice: raw['lowRamDevice'] == true,
        cores: (raw['cores'] as num?)?.toInt() ?? 0,
      );
    } on Object {
      return unknown;
    }
  }
}

final deviceInfoProvider = Provider<DeviceInfo>((ref) => DeviceInfo.unknown);

/// Pilihan pengguna untuk Mod Lite.
enum LiteSetting { auto, on, off }

const liteSettingPrefsKey = 'app.liteMode';

class LiteSettingController extends Notifier<LiteSetting> {
  @override
  LiteSetting build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(liteSettingPrefsKey);
    return LiteSetting.values.where((v) => v.name == raw).firstOrNull ??
        LiteSetting.auto;
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> set(LiteSetting value) async {
    state = value;
    await _prefs.setString(liteSettingPrefsKey, value.name);
  }
}

final liteSettingProvider =
    NotifierProvider<LiteSettingController, LiteSetting>(
      LiteSettingController.new,
    );

/// Mod Lite berkuat kuasa: dimatikan kesan hiasan, bangunan 3D, bayang kabur dan animasi berterusan,
/// GPS terbiar lebih jarang, dan model AI asas disyorkan. Auto = hidup pada peranti kelas rendah.
final liteModeProvider = Provider<bool>((ref) {
  return switch (ref.watch(liteSettingProvider)) {
    LiteSetting.on => true,
    LiteSetting.off => false,
    LiteSetting.auto => ref.watch(deviceInfoProvider).tier == DeviceTier.low,
  };
});

/// Cermin statik [liteModeProvider] untuk pelukis dan widget kecil tanpa `ref` (corak sama dengan
/// `Haptics.enabled`). Ditetapkan oleh akar app setiap kali nilai berubah.
abstract final class LiteMode {
  static bool enabled = false;
}
