import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/navigation/data/offline_voice.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/presentation/navigation_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class _Probe implements OfflineVoiceProbe {
  _Probe(this.result);

  OfflineVoiceStatus result;
  int opened = 0;

  @override
  Future<OfflineVoiceStatus> status(VoiceLanguage language) async => result;

  @override
  Future<bool> openInstaller() async {
    opened++;
    return true;
  }
}

void main() {
  group('pickOfflineVoice', () {
    test('suara luar talian berkualiti tertinggi bagi bahasa itu', () {
      final voices = [
        {
          'name': 'ms-my-x-net',
          'locale': 'ms-MY',
          'network_required': '1',
          'quality': 'very high',
          'features': '',
        },
        {
          'name': 'ms-my-x-local-low',
          'locale': 'ms-MY',
          'network_required': '0',
          'quality': 'normal',
          'features': '',
        },
        {
          'name': 'ms-my-x-local',
          'locale': 'ms-MY',
          'network_required': '0',
          'quality': 'high',
          'features': 'networkTimeoutMs',
        },
        {
          'name': 'en-us-x-local',
          'locale': 'en-US',
          'network_required': '0',
          'quality': 'very high',
          'features': '',
        },
      ];
      expect(pickOfflineVoice(voices, VoiceLanguage.ms), {
        'name': 'ms-my-x-local',
        'locale': 'ms-MY',
      });
      expect(
        pickOfflineVoice(voices, VoiceLanguage.en)?['name'],
        'en-us-x-local',
      );
    });

    test(
      'data suara belum dimuat turun atau hanya rangkaian: tiada pilihan',
      () {
        expect(
          pickOfflineVoice([
            {
              'name': 'ms-my-x-local',
              'locale': 'ms-MY',
              'network_required': '0',
              'features': 'notInstalled',
            },
            {'name': 'ms-my-x-net', 'locale': 'ms-MY', 'network_required': '1'},
          ], VoiceLanguage.ms),
          isNull,
        );
        expect(pickOfflineVoice(null, VoiceLanguage.ms), isNull);
        expect(pickOfflineVoice('x', VoiceLanguage.ms), isNull);
      },
    );
  });

  group('baris suara tanpa internet', () {
    Future<_Probe> pump(WidgetTester tester, OfflineVoiceStatus s) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final probe = _Probe(s);
      await pumpApp(
        tester,
        const Scaffold(body: OfflineVoiceRow(language: VoiceLanguage.ms)),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          offlineVoiceProbeProvider.overrideWithValue(probe),
        ],
      );
      await tester.pump();
      return probe;
    }

    testWidgets(
      'belum dipasang: amaran dan butang Pasang membuka tetapan suara',
      (tester) async {
        final probe = await pump(tester, OfflineVoiceStatus.missing);
        expect(
          find.byKey(const ValueKey('offline-voice-missing')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('offline-voice-install')));
        expect(probe.opened, 1);
      },
    );

    testWidgets('dipasang: sedia, tiada butang', (tester) async {
      await pump(tester, OfflineVoiceStatus.installed);
      expect(
        find.byKey(const ValueKey('offline-voice-installed')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('offline-voice-install')), findsNothing);
    });

    testWidgets('tidak diketahui (platform lain): tiada baris', (tester) async {
      await pump(tester, OfflineVoiceStatus.unknown);
      expect(find.byType(Container), findsNothing);
    });
  });
}
