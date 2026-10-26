import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/network/response_text.dart';
import '../../../core/network/retry_interceptor.dart';
import '../domain/offline_models.dart';
import 'offline_engine_host.dart';
import 'offline_map_store.dart';

enum InstallPhase { downloading, verifying, installing }

typedef InstallProgress =
    void Function(InstallPhase phase, int receivedBytes, int totalBytes);

/// Memuat turun, mengesahkan dan memasang pek peta offline.
///
/// Urutan (setiap langkah menjaga: kegagalan di mana-mana titik tidak merosakkan pek yang sedang aktif):
///   1. muat turun pek termampat ke `download.part` (boleh disambung dengan HTTP Range)
///   2. sahkan sha256 pek termampat terhadap manifest
///   3. ekstrak ke `valhalla_tiles.tar.tmp` dan sahkan saiz + sha256 hasil ekstrak
///   4. tutup enjin, gantikan pek aktif, tulis metadata
class OfflineMapInstaller {
  OfflineMapInstaller({
    required Dio dio,
    required OfflineMapStore store,
    required OfflineEngineHost host,
  }) : _dio = dio,
       _store = store,
       _host = host;

  final Dio _dio;
  final OfflineMapStore _store;
  final OfflineEngineHost _host;

  Future<OfflineManifest> fetchManifest(String manifestUrl) async {
    if (manifestUrl.isEmpty) {
      throw const OfflineMapException(OfflineMapFailure.notConfigured);
    }
    try {
      final response = await _dio.get<Object>(
        manifestUrl,
        options: RetryInterceptor.options(
          Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 15),
          ),
        ),
      );
      return OfflineManifest.fromJson(
        jsonDecode(responseText(response.data) ?? ''),
      );
    } on ManifestException catch (e) {
      throw OfflineMapException(
        e.incompatible
            ? OfflineMapFailure.incompatible
            : OfflineMapFailure.manifestInvalid,
        e.message,
      );
    } on FormatException catch (e) {
      throw OfflineMapException(OfflineMapFailure.manifestInvalid, e.message);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  /// URL pek ialah fail bersebelahan manifest.
  Uri packUrl(String manifestUrl, OfflineManifest manifest) =>
      Uri.parse(manifestUrl).resolve(manifest.file);

  Future<InstalledMap> install({
    required String manifestUrl,
    required OfflineManifest manifest,
    required CancelToken cancel,
    required InstallProgress onProgress,
  }) async {
    await _store.ensureDir();
    try {
      await _download(
        packUrl(manifestUrl, manifest),
        manifest,
        cancel,
        onProgress,
      );

      onProgress(
        InstallPhase.verifying,
        manifest.sizeBytes,
        manifest.sizeBytes,
      );
      if (await _sha256Of(_store.partFile.path) != manifest.sha256) {
        await _store.discardPartial();
        throw const OfflineMapException(
          OfflineMapFailure.checksum,
          'pek termampat',
        );
      }

      onProgress(InstallPhase.installing, 0, manifest.extractedSizeBytes);
      await _gunzipInIsolate(_store.partFile.path, _store.tmpTar.path);
      if (await _store.tmpTar.length() != manifest.extractedSizeBytes ||
          await _sha256Of(_store.tmpTar.path) != manifest.extractedSha256) {
        await _store.discardPartial();
        throw const OfflineMapException(
          OfflineMapFailure.checksum,
          'hasil ekstrak',
        );
      }

      // Pek termampat tidak diperlukan lagi; bebaskan ruang sebelum penggantian.
      await _store.partFile.delete();

      return await _host.withEngineClosed(
        () => _store.install(
          _store.tmpTar,
          version: manifest.version,
          sizeBytes: manifest.extractedSizeBytes,
        ),
      );
    } on OfflineMapException {
      rethrow;
    } on DioException catch (e) {
      throw _fromDio(e);
    } on FileSystemException catch (e) {
      // Ruang penuh (ENOSPC = 28) dan ralat I/O fail lain. Fail separa dibuang supaya tidak memakan ruang.
      await _store.discardPartial();
      throw OfflineMapException(
        OfflineMapFailure.storage,
        '${e.message} ${e.osError?.message ?? ''}',
      );
    } on IOException catch (e) {
      // Sambungan terputus di tengah aliran (HttpException "Connection closed while receiving data",
      // SocketException, ralat TLS) dilempar mentah oleh dart:io, BUKAN sebagai DioException, apabila
      // aliran respons sudah bermula. Fail separa dikekalkan supaya boleh disambung.
      throw OfflineMapException(OfflineMapFailure.network, e.toString());
    } on TimeoutException catch (e) {
      throw OfflineMapException(OfflineMapFailure.network, e.toString());
    }
  }

  Future<void> _download(
    Uri url,
    OfflineManifest manifest,
    CancelToken cancel,
    InstallProgress onProgress,
  ) async {
    var existing = await _store.partialBytesFor(
      manifest.version,
      manifest.sha256,
    );
    if (existing > manifest.sizeBytes) {
      await _store.discardPartial();
      existing = 0;
    }
    await _store.markPartial(manifest.version, manifest.sha256);

    if (existing == manifest.sizeBytes) {
      onProgress(InstallPhase.downloading, existing, manifest.sizeBytes);
      return; // sudah lengkap; disahkan oleh pemanggil
    }

    final response = await _dio.getUri<ResponseBody>(
      url,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        // Muat turun besar: tiada had masa keseluruhan, hanya antara bahagian data.
        receiveTimeout: const Duration(seconds: 30),
        headers: {if (existing > 0) 'Range': 'bytes=$existing-'},
        validateStatus: (s) => s == 200 || s == 206,
      ),
    );

    // 206: pelayan menyambung. 200: pelayan mengabaikan Range dan menghantar semula dari awal.
    final resumed = response.statusCode == 206 && existing > 0;
    var received = resumed ? existing : 0;
    final sink = _store.partFile.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(InstallPhase.downloading, received, manifest.sizeBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (received != manifest.sizeBytes) {
      // Sambungan terputus senyap atau pelayan menghantar saiz lain. Fail separa dikekalkan jika
      // lebih kecil (boleh disambung); jika lebih besar, ia rosak.
      if (received > manifest.sizeBytes) await _store.discardPartial();
      throw OfflineMapException(
        received > manifest.sizeBytes
            ? OfflineMapFailure.checksum
            : OfflineMapFailure.network,
        'diterima $received daripada ${manifest.sizeBytes}',
      );
    }
  }

  OfflineMapException _fromDio(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return const OfflineMapException(OfflineMapFailure.cancelled);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return OfflineMapException(OfflineMapFailure.network, e.message);
      case DioExceptionType.badResponse:
        return OfflineMapException(
          OfflineMapFailure.network,
          'HTTP ${e.response?.statusCode}',
        );
      default:
        return OfflineMapException(OfflineMapFailure.generic, e.message);
    }
  }
}

/// SHA-256 fail dalam isolate (fail 680 MB; tidak boleh menyekat UI). Lihat catatan pada [_gunzipInIsolate].
Future<String> _sha256Of(String path) => Isolate.run(() => _hashFile(path));

Future<String> _hashFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

/// Mengekstrak dalam isolate. Closure `Isolate.run` mesti dicipta dalam fungsi peringkat atas ini:
/// closure dalam kaedah berkongsi konteks dengan closure lain yang menangkap `this` (pemasang memegang
/// Future/Dio yang tidak boleh melintasi isolate), lalu seluruh pemasang cuba dihantar dan gagal.
Future<void> _gunzipInIsolate(String src, String dst) =>
    Isolate.run(() => _gunzip(src, dst));

/// `pipe` menutup sink sama ada berjaya atau gagal.
Future<void> _gunzip(String src, String dst) =>
    File(src).openRead().transform(gzip.decoder).pipe(File(dst).openWrite());
