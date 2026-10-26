import 'dart:async';

import 'package:fgmap_valhalla/fgmap_valhalla.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_map_store.dart';

/// Enjin laluan dalam peranti. Antara muka supaya ujian boleh menggantikannya dengan palsu.
abstract interface class OfflineEngine {
  Future<void> open(String tarPath);
  Future<String> route(String requestJson);
  Future<void> close();
}

class PluginOfflineEngine implements OfflineEngine {
  const PluginOfflineEngine([this._plugin = const FgmapValhalla()]);

  final FgmapValhalla _plugin;

  @override
  Future<void> open(String tarPath) => _plugin.open(tarPath);

  @override
  Future<String> route(String requestJson) => _plugin.route(requestJson);

  @override
  Future<void> close() => _plugin.close();
}

/// Memiliki kitar hayat enjin: membukanya secara malas terhadap pek yang dipasang, dan MENUTUPnya
/// sebelum fail pek diganti atau dipadam (fail yang dimmap tidak boleh diganti dengan selamat).
///
/// Semua operasi disiri melalui satu baris gilir supaya `route` tidak berlumba dengan pemasangan.
class OfflineEngineHost {
  OfflineEngineHost(this._engine, this._store);

  final OfflineEngine _engine;
  final OfflineMapStore _store;

  Future<void> _tail = Future.value();
  String? _openedKey;

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    // Rantai tidak boleh putus kerana satu kegagalan.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Memulangkan JSON respons Valhalla. Melempar [OfflineEngineUnavailable] jika tiada pek dipasang.
  Future<String> route(String requestJson) => _serial(() async {
    final installed = await _store.readInstalled();
    if (installed == null) throw const OfflineEngineUnavailable();

    final key =
        '${installed.tarPath}|${installed.version}|${installed.sizeBytes}';
    if (_openedKey != key) {
      await _engine.open(installed.tarPath);
      _openedKey = key;
    }
    return _engine.route(requestJson);
  });

  /// Menjalankan [action] dengan enjin tertutup (cth. mengganti atau memadam pek).
  Future<T> withEngineClosed<T>(Future<T> Function() action) =>
      _serial(() async {
        await _closeNow();
        return action();
      });

  Future<void> close() => _serial(_closeNow);

  Future<void> _closeNow() async {
    if (_openedKey == null) return;
    _openedKey = null;
    try {
      await _engine.close();
    } on ValhallaEngineException {
      // Enjin tidak dapat ditutup (cth. tiada dibuka): tiada apa untuk dilepaskan.
    }
  }
}

class OfflineEngineUnavailable implements Exception {
  const OfflineEngineUnavailable();
}

/// Lokasi simpanan pek, disediakan oleh bootstrap (path_provider) dan di-override dalam ujian.
final offlineMapStoreProvider = Provider<OfflineMapStore>(
  (ref) => throw UnimplementedError(
    'offlineMapStoreProvider mesti di-override dalam main()',
  ),
);

final offlineEngineProvider = Provider<OfflineEngine>(
  (ref) => const PluginOfflineEngine(),
);

final offlineEngineHostProvider = Provider<OfflineEngineHost>(
  (ref) => OfflineEngineHost(
    ref.watch(offlineEngineProvider),
    ref.watch(offlineMapStoreProvider),
  ),
);
