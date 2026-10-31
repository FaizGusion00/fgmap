import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/diagnostics/error_log.dart';
import 'core/diagnostics/frame_monitor.dart';
import 'core/diagnostics/global_errors.dart';
import 'core/licenses.dart';
import 'core/storage/preferences.dart';
import 'features/map/data/map_style_loader.dart';
import 'features/music/data/local_library.dart';
import 'features/offline_maps/data/offline_engine_host.dart';
import 'features/offline_maps/data/offline_map_store.dart';
import 'features/reports/data/reports_repository.dart';
import 'features/reports/presentation/reports_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  registerBundledLicenses();
  _requireSecureEndpoints();
  if (FrameMonitor.enabled) FrameMonitor().start();

  // Dimuat sebelum frame pertama supaya tema yang disimpan digunakan serta-merta; jika tidak,
  // app yang dibuka dalam mod gelap akan berkelip putih seketika.
  //
  // Application Support: tidak kelihatan kepada pengguna dan tidak disandarkan ke galeri; pek peta
  // ialah data boleh dimuat turun semula, bukan data pengguna.
  //
  // Kedua-duanya panggilan platform yang bebas, jadi dijalankan serentak (satu round-trip, bukan dua).
  final (prefs, support, documents) = await (
    SharedPreferences.getInstance(),
    getApplicationSupportDirectory(),
    // Muzik yang diimport ialah kandungan pengguna: Documents (bukan Application Support).
    getApplicationDocumentsDirectory(),
  ).wait;
  // Log ralat tempatan (tidak dihantar); pengendali global memasangnya sebelum apa-apa kod app berjalan.
  final errorLog = ErrorLog(prefs: prefs);
  installGlobalErrorHandling(errorLog);

  final offlineStore = OfflineMapStore(
    Directory(p.join(support.path, 'offline_maps')),
  );

  final styleCache = Directory(p.join(support.path, 'map_styles'))
    ..createSync(recursive: true);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        errorLogProvider.overrideWithValue(errorLog),
        mapStyleCacheDirProvider.overrideWithValue(styleCache),
        offlineMapStoreProvider.overrideWithValue(offlineStore),
        localLibraryDirProvider.overrideWithValue(
          Directory(p.join(documents.path, 'music')),
        ),
        // Laporan komuniti: simpanan tempatan pada peranti ini (belum dikongsi; lihat ADR 0005).
        reportsRepositoryProvider.overrideWithValue(
          LocalReportsRepository(File(p.join(support.path, 'reports.json'))),
        ),
      ],
      child: const FgmapApp(),
    ),
  );
}

/// Build release menolak konfigurasi titik akhir bukan-HTTPS (lihat [AppConfig.insecureEndpoints]).
void _requireSecureEndpoints() {
  if (!kReleaseMode) return;
  final insecure = AppConfig.insecureEndpoints();
  if (insecure.isNotEmpty) {
    throw StateError(
      'Titik akhir bukan HTTPS dalam build release: ${insecure.join(', ')}',
    );
  }
}
