import 'package:fgmap/core/settings/device_tier.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/search/presentation/search_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gb = 1024 * 1024 * 1024;

DeviceInfo _device(double gb, {bool lowRam = false, int cores = 8}) =>
    DeviceInfo(
      totalMemBytes: (gb * _gb).round(),
      lowRamDevice: lowRam,
      cores: cores,
    );

void main() {
  test('kelas peranti daripada RAM, bendera RAM rendah dan teras', () {
    expect(_device(2).tier, DeviceTier.low);
    expect(_device(3).tier, DeviceTier.low);
    expect(_device(8, lowRam: true).tier, DeviceTier.low);
    expect(_device(6, cores: 4).tier, DeviceTier.low);
    expect(_device(4).tier, DeviceTier.mid);
    expect(_device(6).tier, DeviceTier.mid);
    expect(_device(8).tier, DeviceTier.high);
    expect(DeviceInfo.unknown.tier, DeviceTier.mid, reason: 'tidak diketahui');
  });

  Future<ProviderContainer> container(
    DeviceInfo device, {
    String? stored,
  }) async {
    SharedPreferences.setMockInitialValues({
      liteSettingPrefsKey: ?stored,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceInfoProvider.overrideWithValue(device),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'Auto: hidup hanya pada telefon kelas rendah; pilihan pengguna mengatasi',
    () async {
      expect((await container(_device(2))).read(liteModeProvider), isTrue);
      expect((await container(_device(8))).read(liteModeProvider), isFalse);
      expect(
        (await container(_device(8), stored: 'on')).read(liteModeProvider),
        isTrue,
      );
      expect(
        (await container(_device(2), stored: 'off')).read(liteModeProvider),
        isFalse,
      );
    },
  );

  test('pilihan disimpan dan dibaca semula', () async {
    final c = await container(_device(8));
    await c.read(liteSettingProvider.notifier).set(LiteSetting.on);
    expect(c.read(liteModeProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(liteSettingPrefsKey), 'on');
  });

  testWidgets(
    'Mod Lite: ikon carian tanpa gelombang, tiada bingkai berjadual',
    (tester) async {
      LiteMode.enabled = true;
      addTearDown(() => LiteMode.enabled = false);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SearchWaveIcon(firstDelay: Duration(milliseconds: 10)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
