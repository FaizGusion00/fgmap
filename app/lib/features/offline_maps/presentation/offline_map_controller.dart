import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../data/offline_engine_host.dart';
import '../data/offline_map_installer.dart';
import '../domain/offline_models.dart';
import '../../../core/utils/log.dart';

enum OfflineOp { idle, checking, downloading, verifying, installing }

@immutable
class OfflineMapState {
  const OfflineMapState({
    this.configured = false,
    this.installed,
    this.latest,
    this.op = OfflineOp.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  /// Benar jika URL manifest ditetapkan; jika tidak, muat turun dimatikan.
  final bool configured;
  final InstalledMap? installed;

  /// Manifest terkini yang diketahui daripada hos (null jika belum/tidak dapat disemak).
  final OfflineManifest? latest;
  final OfflineOp op;
  final int receivedBytes;
  final int totalBytes;

  /// Kegagalan operasi terakhir yang dimulakan pengguna; dibuang bila operasi seterusnya bermula.
  final OfflineMapFailure? error;

  bool get busy => op != OfflineOp.idle;

  bool get updateAvailable {
    final i = installed;
    final l = latest;
    return i != null && l != null && l.version.compareTo(i.version) > 0;
  }

  bool get canDownload =>
      configured &&
      !busy &&
      (installed == null || updateAvailable) &&
      latest != null;

  double? get progress => op == OfflineOp.downloading && totalBytes > 0
      ? receivedBytes / totalBytes
      : null;

  OfflineMapState copyWith({
    bool? configured,
    InstalledMap? Function()? installed,
    OfflineManifest? Function()? latest,
    OfflineOp? op,
    int? receivedBytes,
    int? totalBytes,
    OfflineMapFailure? Function()? error,
  }) {
    return OfflineMapState(
      configured: configured ?? this.configured,
      installed: installed != null ? installed() : this.installed,
      latest: latest != null ? latest() : this.latest,
      op: op ?? this.op,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error != null ? error() : this.error,
    );
  }
}

final offlineManifestUrlProvider = Provider<String>(
  (ref) => AppConfig.offlineManifestUrl,
);

final offlineMapInstallerProvider = Provider<OfflineMapInstaller>(
  (ref) => OfflineMapInstaller(
    dio: ref.watch(dioProvider),
    store: ref.watch(offlineMapStoreProvider),
    host: ref.watch(offlineEngineHostProvider),
  ),
);

class OfflineMapController extends Notifier<OfflineMapState> {
  CancelToken? _cancel;

  @override
  OfflineMapState build() {
    ref.onDispose(() => _cancel?.cancel());
    final configured = ref.watch(offlineManifestUrlProvider).isNotEmpty;
    // Pek yang dipasang dibaca serta-merta; semakan versi terkini berlaku di latar.
    Future.microtask(() => refresh());
    return OfflineMapState(configured: configured);
  }

  /// Membaca pek yang dipasang dan (jika [checkRemote]) menyemak manifest terkini.
  /// Kegagalan semakan dipaparkan jika belum ada pek; pek yang telah dipasang kekal boleh digunakan.
  Future<void> refresh({bool checkRemote = true}) async {
    if (state.busy) return;
    final store = ref.read(offlineMapStoreProvider);
    final installed = await store.readInstalled();
    if (!ref.mounted) return;
    state = state.copyWith(installed: () => installed);

    final url = ref.read(offlineManifestUrlProvider);
    if (!checkRemote || url.isEmpty) return;

    state = state.copyWith(op: OfflineOp.checking, error: () => null);
    try {
      final manifest = await ref
          .read(offlineMapInstallerProvider)
          .fetchManifest(url);
      if (!ref.mounted) return;
      state = state.copyWith(op: OfflineOp.idle, latest: () => manifest);
    } on OfflineMapException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        op: OfflineOp.idle,
        error: () => installed == null ? e.kind : null,
      );
    } on Object catch (e, st) {
      logDiag('Semakan peta offline gagal tanpa dijangka: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(
        op: OfflineOp.idle,
        error: () => installed == null ? OfflineMapFailure.generic : null,
      );
    }
  }

  /// Memuat turun dan memasang pek terkini (pemasangan pertama atau kemas kini).
  Future<void> download() async {
    if (state.busy) return;
    final url = ref.read(offlineManifestUrlProvider);
    final installer = ref.read(offlineMapInstallerProvider);
    final token = CancelToken();
    _cancel = token;

    state = state.copyWith(
      op: OfflineOp.checking,
      error: () => null,
      receivedBytes: 0,
      totalBytes: 0,
    );
    try {
      // Manifest disegarkan: ia mungkin telah berubah sejak semakan terakhir.
      final manifest = await installer.fetchManifest(url);
      if (!ref.mounted) return;
      state = state.copyWith(latest: () => manifest);

      var lastReported = -1;
      final installed = await installer.install(
        manifestUrl: url,
        manifest: manifest,
        cancel: token,
        onProgress: (phase, received, total) {
          if (!ref.mounted) return;
          // Muat turun menghantar beribu-ribu bahagian; kemas kini UI hanya bila peratusan (0.5%) berubah.
          final bucket = total > 0 ? received * 200 ~/ total : 0;
          final op = switch (phase) {
            InstallPhase.downloading => OfflineOp.downloading,
            InstallPhase.verifying => OfflineOp.verifying,
            InstallPhase.installing => OfflineOp.installing,
          };
          if (op == state.op &&
              phase == InstallPhase.downloading &&
              bucket == lastReported) {
            return;
          }
          lastReported = bucket;
          state = state.copyWith(
            op: op,
            receivedBytes: received,
            totalBytes: total,
          );
        },
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        op: OfflineOp.idle,
        installed: () => installed,
        error: () => null,
      );
    } on OfflineMapException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        op: OfflineOp.idle,
        error: () => e.kind == OfflineMapFailure.cancelled ? null : e.kind,
      );
    } on Object catch (e, st) {
      // Apa-apa yang tidak dijangka tidak boleh membiarkan UI tersekat pada "sedang memuat turun".
      logDiag('Muat turun peta offline gagal tanpa dijangka: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(
        op: OfflineOp.idle,
        error: () => OfflineMapFailure.generic,
      );
    } finally {
      _cancel = null;
    }
  }

  void cancel() => _cancel?.cancel();

  /// Memadam pek yang dipasang (dan muat turun separa) untuk membebaskan ruang.
  Future<void> delete() async {
    if (state.busy) return;
    final store = ref.read(offlineMapStoreProvider);
    await ref.read(offlineEngineHostProvider).withEngineClosed(() async {
      await store.deleteInstalled();
      await store.discardPartial();
    });
    if (!ref.mounted) return;
    state = state.copyWith(installed: () => null, error: () => null);
  }
}

final offlineMapControllerProvider =
    NotifierProvider<OfflineMapController, OfflineMapState>(
      OfflineMapController.new,
    );
