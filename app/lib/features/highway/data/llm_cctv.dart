import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/utils/geo.dart';

/// Satu kamera CCTV lebuh raya (imej pegun, dikemas kini oleh LLM kira-kira setiap minit).
@immutable
class CctvCamera {
  const CctvCamera({
    required this.name,
    required this.imageUrl,
    required this.fileName,
    this.point,
  });

  /// Nama lokasi daripada LLM (cth. "PLS CAM S4 SKUDAI KM13.5 MD").
  final String name;

  /// URL imej bertandatangan dan bertarikh luput: dapatkan senarai semula untuk imej baharu.
  final String imageUrl;
  final String fileName;

  /// Kedudukan daripada lapisan GIS LLM, jika nama fail sepadan. Null = tidak diketahui.
  final GeoPoint? point;

  /// Arah daripada nama (NB/SB/EB/WB): 'N', 'S', 'E', 'W' atau null.
  String? get direction {
    final m = RegExp(r'(?:^|[\s_])(NB|SB|EB|WB)(?:$|[\s_\d])').firstMatch(name);
    return m?.group(1)?.substring(0, 1);
  }

  /// Nama mudah dibaca: tanpa awalan kod/"CAM"/nombor kamera dan tanpa arah.
  String get label {
    var s = name.replaceAll('_', ' ').trim();
    s = s.replaceFirst(
      RegExp(r'^[A-Z0-9]+\s+(?:CAM|CCTV)\s*(?:[A-Z]?\d+[A-Z]?\s+)?'),
      '',
    );
    s = s.replaceAll(RegExp(r'\s+(NB|SB|EB|WB)\b.*$'), '');
    return s.trim().isEmpty ? name : s.trim();
  }
}

class CctvFailure implements Exception {
  const CctvFailure(this.detail);

  final String detail;

  @override
  String toString() => 'CctvFailure($detail)';
}

/// Kunci padanan nama fail kamera (sama seperti tools/cctv/build_cctv_positions.py).
String cctvKey(String fileName) => fileName
    .trim()
    .toLowerCase()
    .replaceFirst(RegExp(r'\.web\.jpg$'), '')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Menghurai respons `get_data_ajax`. Badan rosak atau `status` bukan success -> [CctvFailure].
List<CctvCamera> parseLlmCctv(
  String? body, {
  Map<String, GeoPoint> positions = const {},
}) {
  if (body == null || body.trim().isEmpty) throw const CctvFailure('kosong');
  final Object? root;
  try {
    root = jsonDecode(body.replaceFirst('﻿', ''));
  } on FormatException {
    throw const CctvFailure('bukan JSON');
  }
  if (root is! Map<String, dynamic> || root['status'] != 'success') {
    throw const CctvFailure('status');
  }
  final data = root['data'];
  if (data is! List) return const [];
  final out = <CctvCamera>[];
  for (final e in data) {
    if (e is! Map<String, dynamic>) continue;
    final url = e['url'] ?? e['image_url'] ?? e['snapshot_url'];
    if (url is! String) continue;
    final uri = Uri.tryParse(url);
    // Hanya imej HTTPS daripada LLM.
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'llm.gov.my' || uri.host.endsWith('.llm.gov.my'))) {
      continue;
    }
    final file = e['file_name'] is String ? e['file_name'] as String : '';
    final name = e['location_name'] is String
        ? (e['location_name'] as String).trim()
        : file;
    out.add(
      CctvCamera(
        name: name.isEmpty ? file : name,
        imageUrl: url,
        fileName: file,
        point: file.isEmpty ? null : positions[cctvKey(file)],
      ),
    );
  }
  return out;
}

/// Paparan CCTV awam laman Lembaga Lebuhraya Malaysia (llm.gov.my, "Paparan CCTV Lebuh Raya").
class LlmCctvClient {
  LlmCctvClient(this._dio);

  final Dio _dio;

  static const endpoint = 'https://www.llm.gov.my/index.php/awam/get_data_ajax';

  Future<List<CctvCamera>> fetch(
    String code, {
    Map<String, GeoPoint> positions = const {},
  }) async {
    try {
      final r = await _dio.get<Object>(
        endpoint,
        queryParameters: {'highway': code},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return parseLlmCctv(responseText(r.data), positions: positions);
    } on DioException catch (e) {
      throw CctvFailure('${e.type}');
    }
  }
}

/// Nama fail kamera -> kedudukan (lapisan GIS LLM, dibundel). Gagal dimuat -> kosong.
final cctvPositionsProvider = FutureProvider<Map<String, GeoPoint>>((
  ref,
) async {
  try {
    final root = jsonDecode(
      await rootBundle.loadString('assets/cctv/llm_cctv_positions.json'),
    );
    final cams = root is Map<String, dynamic> ? root['cameras'] : null;
    if (cams is! Map<String, dynamic>) return const {};
    return {
      for (final e in cams.entries)
        if (e.value is List &&
            (e.value as List).length >= 2 &&
            (e.value as List)[0] is num &&
            (e.value as List)[1] is num)
          e.key: GeoPoint(
            ((e.value as List)[0] as num).toDouble(),
            ((e.value as List)[1] as num).toDouble(),
          ),
    };
  } on Object {
    return const {};
  }
});

final llmCctvClientProvider = Provider<LlmCctvClient>(
  (ref) => LlmCctvClient(ref.watch(dioProvider)),
);

/// Kamera satu lebuh raya. Dibatalkan bila tidak dipaparkan; muat semula = URL imej baharu.
final cctvCamerasProvider = FutureProvider.autoDispose
    .family<List<CctvCamera>, String>((ref, code) async {
      final positions = await ref.watch(cctvPositionsProvider.future);
      return ref.watch(llmCctvClientProvider).fetch(code, positions: positions);
    });
