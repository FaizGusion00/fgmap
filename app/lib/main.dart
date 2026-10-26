import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/licenses.dart';
import 'core/storage/preferences.dart';
import 'features/offline_maps/data/offline_engine_host.dart';
import 'features/offline_maps/data/offline_map_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  registerBundledLicenses();

  // Dimuat sebelum frame pertama supaya tema yang disimpan digunakan serta-merta; jika tidak,
  // app yang dibuka dalam mod gelap akan berkelip putih seketika.
  //
  // Application Support: tidak kelihatan kepada pengguna dan tidak disandarkan ke galeri; pek peta
  // ialah data boleh dimuat turun semula, bukan data pengguna.
  //
  // Kedua-duanya panggilan platform yang bebas, jadi dijalankan serentak (satu round-trip, bukan dua).
  final (prefs, support) = await (
    SharedPreferences.getInstance(),
    getApplicationSupportDirectory(),
  ).wait;
  final offlineStore = OfflineMapStore(
    Directory(p.join(support.path, 'offline_maps')),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        offlineMapStoreProvider.overrideWithValue(offlineStore),
      ],
      child: const FgmapApp(),
    ),
  );
}
