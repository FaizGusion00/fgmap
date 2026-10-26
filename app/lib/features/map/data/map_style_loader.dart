import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/night_style.dart';
import '../../../core/utils/log.dart';

/// Gaya peta yang sedia dihantar kepada MapLibre: URL atau JSON gaya lengkap.
@immutable
class ResolvedMapStyle {
  const ResolvedMapStyle(this.style, this.key);

  /// URL (gaya hos jauh) atau JSON mentah (gaya malam yang telah diwarnakan semula).
  final String style;

  /// Pengenal stabil untuk perbandingan (JSON panjang tidak dibanding rentetan demi rentetan).
  final String key;

  bool get isJson => style.startsWith('{');

  @override
  bool operator ==(Object other) =>
      other is ResolvedMapStyle && other.key == key && other.style == style;

  @override
  int get hashCode => Object.hash(key, style);
}

/// Mengambil gaya peta dan menghasilkan gaya malam kontras tinggi.
///
/// Gaya cerah dihantar sebagai URL (tiada kerja tambahan). Gaya malam: ambil JSON gaya asas
/// (cache fail 7 hari; gaya lama dipakai jika rangkaian gagal), warnakan semula ([NightStyle]) dan
/// hantar sebagai JSON. Sebarang kegagalan jatuh ke URL gaya gelap asal, jadi peta sentiasa muncul.
class MapStyleLoader {
  MapStyleLoader(
    this._dio,
    this._cacheDir, {
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 4),
  }) : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final Directory? _cacheDir;
  final DateTime Function() _clock;

  /// Masa maksimum menunggu gaya malam sebelum jatuh ke URL (pengambilan diteruskan di latar untuk
  /// cache seterusnya).
  final Duration timeout;

  static const cacheTtl = Duration(days: 7);

  ResolvedMapStyle light() => const ResolvedMapStyle(
    AppConfig.mapStyleLight,
    'url:${AppConfig.mapStyleLight}',
  );

  ResolvedMapStyle _darkFallback() => const ResolvedMapStyle(
    AppConfig.mapStyleDark,
    'url:${AppConfig.mapStyleDark}',
  );

  Future<ResolvedMapStyle> resolve({required bool dark}) async {
    if (!dark) return light();
    final night = _loadNight();
    try {
      return await night.timeout(timeout);
    } on TimeoutException {
      return _darkFallback();
    }
  }

  Future<ResolvedMapStyle> _loadNight() async {
    try {
      final raw = await _rawBase(AppConfig.mapStyleNightBase);
      if (raw == null) return _darkFallback();
      final styled = NightStyle.apply(raw);
      if (styled == null) return _darkFallback();
      return ResolvedMapStyle(
        styled,
        'night:${styled.length}:${styled.hashCode}',
      );
    } on Object catch (e) {
      logDiag('Gaya malam gagal, guna URL: $e');
      return _darkFallback();
    }
  }

  File? _cacheFile(String url) {
    final dir = _cacheDir;
    if (dir == null) return null;
    return File('${dir.path}/map_style_${url.hashCode.toUnsigned(32)}.json');
  }

  /// JSON gaya asas: cache segar, jika tidak ambil; jika ambil gagal guna cache lama.
  Future<String?> _rawBase(String url) async {
    final file = _cacheFile(url);
    String? cached;
    DateTime? cachedAt;
    if (file != null) {
      try {
        if (await file.exists()) {
          cached = await file.readAsString();
          cachedAt = (await file.lastModified());
        }
      } on Object {
        cached = null;
      }
    }
    if (cached != null &&
        cachedAt != null &&
        _clock().difference(cachedAt) < cacheTtl) {
      return cached;
    }
    try {
      final response = await _dio.get<Object>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final body = response.data;
      final text = body is String
          ? body
          : (body == null ? null : jsonEncode(body));
      if (text == null || !text.trimLeft().startsWith('{')) return cached;
      if (file != null) {
        try {
          await file.writeAsString(text, flush: true);
        } on Object {
          // Cache hanya pengoptimuman.
        }
      }
      return text;
    } on DioException {
      return cached;
    }
  }
}

/// Folder cache gaya peta; null (lalai) = tiada cache fail. `main.dart` menyuntik folder sokongan app.
final mapStyleCacheDirProvider = Provider<Directory?>((ref) => null);

final mapStyleLoaderProvider = Provider<MapStyleLoader>(
  (ref) => MapStyleLoader(
    ref.watch(dioProvider),
    ref.watch(mapStyleCacheDirProvider),
  ),
);

/// Gaya peta untuk mod semasa. Sentiasa selesai dalam masa [MapStyleLoader.timeout].
final mapStyleProvider = FutureProvider.family<ResolvedMapStyle, bool>(
  (ref, dark) => ref.watch(mapStyleLoaderProvider).resolve(dark: dark),
);
