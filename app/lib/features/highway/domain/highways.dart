import 'package:flutter/foundation.dart';

/// Lebuh raya dalam paparan CCTV Lembaga Lebuhraya Malaysia (kod pilihan laman llm.gov.my).
@immutable
class LlmHighway {
  const LlmHighway(this.code, this.ref, this.name);

  /// Kod LLM untuk `get_data_ajax?highway=` (cth. `SPL`).
  final String code;

  /// Nombor laluan (cth. `E2`). Beberapa lebuh raya berkongsi nombor (E1: NKVE dan PLUS Utara).
  final String ref;
  final String name;

  /// Nama pendek untuk cip: teks dalam kurungan terakhir (cth. "PLUS Selatan"), atau kod.
  String get short {
    final m = RegExp(r'\(([^()]+)\)\s*$').firstMatch(name);
    return m?.group(1)?.trim() ?? code;
  }
}

/// Senarai daripada laman LLM (disemak 2026-11-06).
const llmHighways = <LlmHighway>[
  LlmHighway('NKV', 'E1', 'Lebuhraya Baru Lembah Klang (NKVE)'),
  LlmHighway('PLS', 'E1', 'Lebuhraya Utara Selatan (PLUS Utara)'),
  LlmHighway('SPL', 'E2', 'Lebuhraya Utara Selatan (PLUS Selatan)'),
  LlmHighway('LINK2', 'E3', "Lebuhraya Hubungan Kedua M'sia-Singapura (LINK2)"),
  LlmHighway('ELT', 'E6', 'Lebuhraya Utara Selatan Hubungan Tengah (ELITE)'),
  LlmHighway('KSS', 'E5', 'Lebuhraya Shah Alam (KESAS)'),
  LlmHighway('CKH', 'E7', 'Lebuhraya Cheras-Kajang (GRANDSAGA)'),
  LlmHighway('KLK', 'E8', 'Lebuhraya KL-Karak (KLK)'),
  LlmHighway('LPT', 'E8', 'Lebuhraya Pantai Timur Fasa 1 (LPT1)'),
  LlmHighway('ECE2', 'E8', 'Lebuhraya Pantai Timur Fasa 2 (LPT2)'),
  LlmHighway('BES', 'E9', 'Lebuhraya BESRAYA (BES)'),
  LlmHighway('NPE', 'E10', 'Lebuhraya Pantai Baharu (NPE)'),
  LlmHighway('LDP', 'E11', 'Lebuhraya Damansara-Puchong (LDP)'),
  LlmHighway('AKL', 'E12', 'Lebuhraya Bertingkat Ampang-KL (AKLEH)'),
  LlmHighway('KSA', 'E13', 'Lebuhraya Kemuning-Shah Alam (LKSA)'),
  LlmHighway('LLB', 'E17', 'Lebuhraya Lingkaran Luar Butterworth (LLB)'),
  LlmHighway('SLK', 'E18', 'Lebuhraya Lingkaran Luar Kajang (SILK)'),
  LlmHighway('SUKE', 'E19', 'Lebuhraya Sungai Besi-Ulu Kelang (SUKE)'),
  LlmHighway('KLP', 'E20', 'Lebuhraya KL-Putrajaya (MEX)'),
  LlmHighway('LKS', 'E21', 'Lebuhraya Kajang-Seremban (LEKAS)'),
  LlmHighway('SDE', 'E22', 'Lebuhraya Senai-Desaru (SDE)'),
  LlmHighway('SRT', 'E23', 'Lebuhraya Penyuraian Trafik KL Barat (SPRINT)'),
  LlmHighway('LTR', 'E25', 'Lebuhraya KL-Kuala Selangor (LATAR)'),
  LlmHighway('SKV', 'E26', 'Lebuhraya Lembah Klang Selatan (SKVE)'),
  LlmHighway('EKVE', 'E27', 'Lebuhraya Lembah Klang Timur (EKVE)'),
  LlmHighway(
    'JKSB',
    'E28',
    'Jambatan Sultan Abdul Halim Muadzam Shah (JSAHMS)',
  ),
  LlmHighway('NNKSB', 'E30', 'Lebuhraya Pintas Selat Klang Utara Baru (NNKSB)'),
  LlmHighway('DASH', 'E31', 'Lebuhraya Bertingkat Damansara-Shah Alam (DASH)'),
  LlmHighway('WCE', 'E32', 'Lebuhraya Pesisiran Pantai Barat (WCE)'),
  LlmHighway('DUKE', 'E33', 'Lebuhraya Duta-Ulu Kelang (DUKE)'),
  LlmHighway('GCE', 'E35', 'Lebuhraya Koridor Guthrie (GCE)'),
  LlmHighway('PNB', 'E36', 'Jambatan Pulau Pinang (PNB)'),
  LlmHighway('SMT', 'E38', 'Terowong SMART (SMT)'),
  LlmHighway('SPE', 'E39', 'Lebuhraya Setiawangsa Pantai (SPE)'),
];

LlmHighway? llmHighwayByCode(String code) {
  for (final h in llmHighways) {
    if (h.code == code) return h;
  }
  return null;
}

/// Kod lebuh raya yang dilalui laluan, daripada nama jalan manuver (`E1`, `E2`, ...), ikut susunan
/// pertama kali ditemui. Nombor yang dikongsi (E1, E8) memberi semua lebuh raya berkenaan.
List<String> highwayCodesForStreetNames(Iterable<String> streetNames) {
  final out = <String>[];
  for (final raw in streetNames) {
    final ref = raw.trim().toUpperCase();
    if (!RegExp(r'^E\d+$').hasMatch(ref)) continue;
    for (final h in llmHighways) {
      if (h.ref == ref && !out.contains(h.code)) out.add(h.code);
    }
  }
  return out;
}

/// Kod lebuh raya yang disebut dalam teks bebas (cth. "cctv plus selatan", "nkve", "e2"). Nama paling
/// khusus menang: "plus selatan" -> SPL sahaja, "plus" -> PLUS Utara dan Selatan.
List<String> highwayCodesInText(String text) {
  final t = ' ${text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
  bool has(String w) => t.contains(' $w ');
  const specific = {
    'plus selatan': 'SPL',
    'plus utara': 'PLS',
    'utara selatan': 'PLS',
    'pantai timur': 'LPT',
    'second link': 'LINK2',
    'linkedua': 'LINK2',
    'jambatan pulau pinang': 'PNB',
    'jambatan kedua': 'JKSB',
    'penang bridge': 'PNB',
    'smart': 'SMT',
    'mex': 'KLP',
    'lpt2': 'ECE2',
    'lpt1': 'LPT',
    'lpt': 'LPT',
    'grandsaga': 'CKH',
    'cheras kajang': 'CKH',
    'karak': 'KLK',
    'besraya': 'BES',
    'lekas': 'LKS',
    'kesas': 'KSS',
    'lksa': 'KSA',
    'silk': 'SLK',
    'sprint': 'SRT',
    'latar': 'LTR',
    'skve': 'SKV',
    'elite': 'ELT',
    'nkve': 'NKV',
    'akleh': 'AKL',
    'guthrie': 'GCE',
  };
  final out = <String>[];
  for (final e in specific.entries) {
    if (has(e.key) && !out.contains(e.value)) out.add(e.value);
  }
  if (out.isNotEmpty) return out;
  for (final h in llmHighways) {
    final short = h.short.toLowerCase();
    if (has(h.code.toLowerCase()) || has(short) || has(h.ref.toLowerCase())) {
      if (!out.contains(h.code)) out.add(h.code);
    }
  }
  if (out.isEmpty && has('plus')) out.addAll(const ['PLS', 'SPL']);
  return out;
}
