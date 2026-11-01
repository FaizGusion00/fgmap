import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Tahap model AI pada telefon: lebih tinggi = lebih pintar, tetapi muat turun lebih besar, perlu
/// lebih RAM dan menjawab lebih perlahan.
enum AiModelTier { basic, medium, high }

/// Satu model `.litertlm` awam (tanpa token Hugging Face) yang boleh dimuat turun dan digunakan oleh
/// FG AI. Hanya SATU digunakan pada satu masa; yang lain boleh kekal dimuat turun untuk ditukar.
class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.name,
    required this.tier,
    required this.sizeBytes,
    required this.minRamGb,
    required this.modelType,
    required this.url,
    this.contextTokens = 2048,
    this.maxOutputTokens = 400,
  });

  /// Nama fail model (juga pengenal model dalam flutter_edge_ai).
  final String id;
  final String name;
  final AiModelTier tier;

  /// Saiz fail sebenar (Hugging Face, 2026-11-01).
  final int sizeBytes;

  /// RAM telefon yang disyorkan. Di bawahnya model mungkin gagal dimuat atau app ditutup sistem.
  final int minRamGb;
  final ModelType modelType;
  final String url;
  final int contextTokens;
  final int maxOutputTokens;
}

const _hf = 'https://huggingface.co/litert-community';

/// Senarai tetap, disusun dari paling ringan ke paling pintar. Semua repo `litert-community` awam
/// (bukan "gated"), jadi pengguna tidak perlu akaun Hugging Face.
const aiModelOptions = <AiModelOption>[
  AiModelOption(
    id: 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    name: 'Qwen3 0.6B',
    tier: AiModelTier.basic,
    sizeBytes: 343_000_000,
    minRamGb: 3,
    modelType: ModelType.qwen3,
    url:
        '$_hf/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    contextTokens: 1536,
    maxOutputTokens: 320,
  ),
  AiModelOption(
    id: 'Qwen3.5-0.8B_int8.litertlm',
    name: 'Qwen3.5 0.8B',
    tier: AiModelTier.basic,
    sizeBytes: 965_000_000,
    minRamGb: 4,
    modelType: ModelType.qwen35,
    url: '$_hf/Qwen3.5-0.8B/resolve/main/Qwen3.5-0.8B_int8.litertlm',
  ),
  AiModelOption(
    id: 'gemma-4-E2B-it.litertlm',
    name: 'Gemma 4 E2B',
    tier: AiModelTier.medium,
    sizeBytes: 2_588_000_000,
    minRamGb: 6,
    modelType: ModelType.gemma4,
    url: '$_hf/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  ),
  AiModelOption(
    id: 'Qwen3.5-4B_mixed_int4.litertlm',
    name: 'Qwen3.5 4B',
    tier: AiModelTier.high,
    sizeBytes: 2_754_000_000,
    minRamGb: 8,
    modelType: ModelType.qwen35,
    url: '$_hf/Qwen3.5-4B/resolve/main/Qwen3.5-4B_mixed_int4.litertlm',
  ),
  AiModelOption(
    id: 'gemma-4-E4B-it.litertlm',
    name: 'Gemma 4 E4B',
    tier: AiModelTier.high,
    sizeBytes: 3_660_000_000,
    minRamGb: 8,
    modelType: ModelType.gemma4,
    url: '$_hf/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
  ),
];

/// Model lalai: paling ringan (sama dengan model tunggal versi lama, jadi fail sedia ada dikekalkan).
AiModelOption get defaultAiModel => aiModelOptions.first;

/// Kunci tetapan model yang dipilih (nama fail).
const aiModelPrefsKey = 'assistant.model.id';

AiModelOption aiModelById(String? id) =>
    aiModelOptions.where((m) => m.id == id).firstOrNull ?? defaultAiModel;
