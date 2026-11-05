import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';

/// Pilihan dalam kalkulator tol LLM (lebuh raya atau plaza).
@immutable
class LlmOption {
  const LlmOption(this.id, this.name);

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is LlmOption && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Kadar satu kelas kenderaan (LLM `transCode`: 1 kereta, 2 van/lori kecil, 3 lori besar, 4 teksi, 5 bas).
@immutable
class LlmTollRate {
  const LlmTollRate(this.vehicleClass, this.rm);

  final int vehicleClass;
  final double rm;
}

class LlmTollFailure implements Exception {
  const LlmTollFailure(this.detail);

  final String detail;

  @override
  String toString() => 'LlmTollFailure($detail)';
}

/// `[{id, name}]` -> pilihan; baris "Sila Pilih ..." (id kosong) dibuang.
List<LlmOption> parseLlmOptions(String? body) {
  final root = _decode(body);
  if (root is! List) throw const LlmTollFailure('bukan senarai');
  return [
    for (final e in root)
      if (e is Map<String, dynamic> &&
          e['name'] is String &&
          '${e['id'] ?? ''}'.trim().isNotEmpty)
        LlmOption('${e['id']}'.trim(), (e['name'] as String).trim()),
  ];
}

/// `[{transCode, rate}]` -> kadar sah, ikut kelas.
List<LlmTollRate> parseLlmRates(String? body) {
  final root = _decode(body);
  if (root is! List) throw const LlmTollFailure('bukan senarai');
  final out = <LlmTollRate>[
    for (final e in root)
      if (e is Map<String, dynamic> &&
          e['transCode'] is int &&
          e['rate'] is num &&
          (e['rate'] as num) >= 0 &&
          (e['rate'] as num).isFinite)
        LlmTollRate(e['transCode'] as int, (e['rate'] as num).toDouble()),
  ]..sort((a, b) => a.vehicleClass.compareTo(b.vehicleClass));
  return out;
}

Object? _decode(String? body) {
  if (body == null || body.trim().isEmpty) {
    throw const LlmTollFailure('kosong');
  }
  try {
    return jsonDecode(body.replaceFirst('﻿', ''));
  } on FormatException {
    throw const LlmTollFailure('bukan JSON');
  }
}

/// Kalkulator tol rasmi Lembaga Lebuhraya Malaysia (https://www.llm.gov.my, panel "Kalkulator Tol").
class LlmTollClient {
  LlmTollClient(this._dio);

  final Dio _dio;

  static const base = 'https://www.llm.gov.my/Calculator';

  Future<String?> _get(String path) async {
    try {
      final r = await _dio.get<Object>(
        '$base/$path',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return responseText(r.data);
    } on DioException catch (e) {
      throw LlmTollFailure('${e.type}');
    }
  }

  static String _seg(String id) => Uri.encodeComponent(id);

  Future<List<LlmOption>> highways() async =>
      parseLlmOptions(await _get('getHighway'));

  Future<List<LlmOption>> entries(String highway) async =>
      parseLlmOptions(await _get('getPlazaEnter/${_seg(highway)}'));

  /// Kosong = plaza harga tetap (tiada plaza keluar).
  Future<List<LlmOption>> exits(String highway, String entry) async =>
      parseLlmOptions(
        await _get('getPlazaExit/${_seg(highway)}/${_seg(entry)}'),
      );

  Future<List<LlmTollRate>> rates(
    String highway,
    String entry,
    String? exit,
  ) async => parseLlmRates(
    await _get(
      'getTollRate/${_seg(highway)}/${_seg(entry)}/${exit == null ? 'null' : _seg(exit)}',
    ),
  );
}

final llmTollClientProvider = Provider<LlmTollClient>(
  (ref) => LlmTollClient(ref.watch(dioProvider)),
);
