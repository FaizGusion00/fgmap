import 'dart:io';

import 'package:fgmap/core/config/app_config.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/core/utils/log.dart';
import 'package:fgmap/features/search/domain/location_link.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('log: tiada URL atau koordinat bocor', () {
    test('URL penuh dan nombor perpuluhan panjang dibuang', () {
      const raw =
          'Re-route gagal: DioException [connection error] https://valhalla.example/route?lat=3.15790&lon=101.71160 di 3.1579, 101.7116';
      final out = redactForLog(raw);
      expect(out, isNot(contains('valhalla')));
      expect(out, isNot(contains('3.1579')));
      expect(out, isNot(contains('101.7116')));
      expect(out, contains('Re-route gagal'));
    });

    test('mesej biasa dikekalkan', () {
      expect(
        redactForLog('Suara navigasi gagal: timeout 5 s'),
        'Suara navigasi gagal: timeout 5 s',
      );
    });

    test('tiada debugPrint mentah dalam kod app (hanya melalui logDiag)', () {
      final offenders = <String>[];
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        final skip =
            !f.path.endsWith('.dart') || f.path.endsWith('core/utils/log.dart');
        if (skip) continue;
        if (f.readAsStringSync().contains('debugPrint(')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('titik akhir HTTPS', () {
    test('konfigurasi lalai semuanya https', () {
      expect(AppConfig.insecureEndpoints(), isEmpty);
    });

    test('insecureOf menandakan http dan campuran dalam senarai koma', () {
      expect(
        AppConfig.insecureOf({
          'A': 'https://a.example',
          'B': 'http://10.0.2.2:8099/manifest.json',
          'C': 'https://x.example, http://y.example',
          'D': '',
        }),
        ['B', 'C'],
      );
    });
  });

  group('label pautan luaran dibersihkan', () {
    test('aksara kawalan dan arah teks dua hala dibuang', () {
      // Titik kod, bukan aksara mentah: penganalisis menolak U+202E/U+202C dalam literal.
      final rlo = String.fromCharCode(0x202E);
      final pdf = String.fromCharCode(0x202C);
      expect(
        sanitizeSharedLabel('Kedai\u0000 ${rlo}evil$pdf\nMakan'),
        'Kedai evil Makan',
      );
    });

    test('dihad 80 aksara dengan elipsis', () {
      final out = sanitizeSharedLabel('a' * 500)!;
      expect(out.runes.length, 81);
      expect(out, endsWith('…'));
    });

    test('kosong atau hanya kawalan -> null', () {
      expect(sanitizeSharedLabel('   \n\t'), isNull);
      expect(sanitizeSharedLabel(null), isNull);
    });

    test(
      'pautan geo dengan label panjang berbahaya dibersihkan hujung ke hujung',
      () {
        final rlo = String.fromCharCode(0x202E);
        final uri = Uri.parse(
          'geo:0,0?q=${Uri.encodeComponent('${'x' * 300}$rlo')}',
        );
        final shared = sharedLocationFromUri(uri)!;
        expect(shared.label!.runes.length, lessThanOrEqualTo(81));
        expect(shared.label, isNot(contains(rlo)));
      },
    );

    test('titik koordinat tidak terjejas', () {
      final shared = sharedLocationFromUri(Uri.parse('geo:3.15,101.71'))!;
      expect(shared.point, const GeoPoint(3.15, 101.71));
    });
  });

  group('konfigurasi natif (pengawal regresi)', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');

    test('Android: tiada sandaran, tiada cleartext, ada peraturan ekstrak', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(manifest, contains('@xml/network_security_config'));
      expect(manifest, contains('@xml/data_extraction_rules'));
      expect(manifest, contains('@xml/backup_rules'));
    });

    test('Android: R8 menyimpan konstruktor Room (WorkManager dari home_widget)', () {
      // Tanpa ini build release ranap ketika bermula: "Failed to create an instance of
      // androidx.work.impl.WorkDatabase" (peraturan Room 2.2.5 tidak menyimpan <init>()).
      final rules = _read('android/app/proguard-rules.pro');
      expect(
        RegExp(
          r'-keep class \* extends androidx\.room\.RoomDatabase\s*\{\s*<init>\(\);\s*\}',
        ).hasMatch(rules),
        isTrue,
      );
    });

    test('Android: Azan dan Muzik: kebenaran dan sumber yang betul', () {
      // Penggera tepat yang diminta pengguna, bukan USE_EXACT_ALARM (polisi Play: app jam sahaja).
      expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
      expect(manifest, isNot(contains('android.permission.USE_EXACT_ALARM')));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
      expect(
        manifest,
        contains('android:foregroundServiceType="mediaPlayback"'),
      );
      // Tiada lokasi latar belakang.
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      // Bunyi azan dirujuk melalui nama sahaja: mesti dilindungi daripada pengecilan sumber.
      final keep = _read('android/app/src/main/res/raw/keep.xml');
      expect(keep, contains('@raw/azan'));
      expect(keep, contains('@raw/azan_short'));
      for (final f in ['azan.mp3', 'azan_short.mp3']) {
        expect(
          File('android/app/src/main/res/raw/$f').existsSync(),
          isTrue,
          reason: f,
        );
      }
      // Kawalan skrin kunci memerlukan aktiviti audio_service.
      expect(
        _read(
          'android/app/src/main/kotlin/com/fguniversalempire/fgmaps/MainActivity.kt',
        ),
        contains('AudioServiceActivity'),
      );
      expect(
        _read('android/app/build.gradle.kts'),
        contains('isCoreLibraryDesugaringEnabled = true'),
      );
    });

    test(
      'Android: kategori intent betul (bukan action.DEFAULT yang tersalah taip)',
      () {
        expect(manifest, isNot(contains('android.intent.action.DEFAULT')));
        // Setiap penapis VIEW mesti DEFAULT + BROWSABLE supaya benar-benar menerima pautan.
        final filters =
            RegExp(r'<intent-filter>.*?</intent-filter>', dotAll: true)
                .allMatches(manifest)
                .map((m) => m.group(0)!)
                .where((f) => f.contains('android.intent.action.VIEW'));
        expect(filters, isNotEmpty);
        for (final f in filters) {
          expect(f, contains('android.intent.category.DEFAULT'));
          expect(f, contains('android.intent.category.BROWSABLE'));
        }
      },
    );

    test(
      'Android: konfigurasi rangkaian utama melarang cleartext; hanya debug dikecualikan',
      () {
        final main = _read(
          'android/app/src/main/res/xml/network_security_config.xml',
        );
        expect(main, contains('cleartextTrafficPermitted="false"'));
        expect(main, isNot(contains('cleartextTrafficPermitted="true"')));
        expect(
          main,
          isNot(contains('user')),
          reason: 'tiada CA pengguna dipercayai',
        );

        final debug = _read(
          'android/app/src/debug/res/xml/network_security_config.xml',
        );
        for (final host in ['10.0.2.2', 'localhost', '127.0.0.1']) {
          expect(debug, contains(host));
        }
        expect(debug, isNot(contains('<domain includeSubdomains="true">')));
      },
    );

    test('Android: peraturan sandaran mengecualikan semua domain', () {
      for (final f in ['data_extraction_rules.xml', 'backup_rules.xml']) {
        final xml = _read('android/app/src/main/res/xml/$f');
        for (final d in ['file', 'database', 'sharedpref']) {
          expect(xml, contains('domain="$d"'), reason: f);
        }
        expect(xml, isNot(contains('<include')), reason: f);
      }
    });

    test(
      'Android: R8 dan pengecilan sumber eksplisit; kunci hilang gagal untuk build kedai',
      () {
        final gradle = _read('android/app/build.gradle.kts');
        expect(gradle, contains('isMinifyEnabled = true'));
        expect(gradle, contains('isShrinkResources = true'));
        expect(gradle, contains('FGMAP_STORE_BUILD'));
        expect(gradle, contains('GradleException'));
      },
    );

    test(
      'iOS: manifes privasi sah, tanpa penjejakan, daftar dalam projek Xcode',
      () {
        final xml = _read('ios/Runner/PrivacyInfo.xcprivacy');
        expect(xml, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
        expect(xml, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
        expect(xml, contains('CA92.1'));
        final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
        expect(
          RegExp('PrivacyInfo.xcprivacy').allMatches(pbx).length,
          greaterThanOrEqualTo(5),
        );
        expect(pbx, contains('PrivacyInfo.xcprivacy in Resources'));
      },
    );

    test('Makefile: AAB berkod terkaburkan dan memaksa kunci release', () {
      final make = _read('../Makefile');
      expect(make, contains('--obfuscate'));
      expect(make, contains('FGMAP_STORE_BUILD=1 flutter build appbundle'));
    });

    test('CI keselamatan: Dependabot dan imbasan kebergantungan wujud', () {
      expect(
        _read('../.github/dependabot.yml'),
        contains('package-ecosystem: pub'),
      );
      final wf = _read('../.github/workflows/security.yml');
      expect(wf, contains('codeql-action'));
      expect(wf, contains('osv-scanner'));
      expect(wf, contains('sbom-action'));
    });
  });
}
