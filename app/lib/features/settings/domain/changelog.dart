import 'package:flutter/foundation.dart';

/// Satu perubahan dalam log perubahan: apa yang berlaku SEBELUM dan SELEPAS, dan cara menggunakannya.
@immutable
class ChangelogEntry {
  const ChangelogEntry({
    required this.title,
    required this.before,
    required this.after,
    this.tip,
  });

  final String title;
  final String before;
  final String after;

  /// "Cara guna" / had yang pengguna patut tahu; null jika tiada.
  final String? tip;
}

/// Satu versi keluaran FGMaps.
@immutable
class ChangelogRelease {
  const ChangelogRelease({
    required this.version,
    required this.entries,
    this.date,
    this.summary,
  });

  final String version;
  final DateTime? date;
  final String? summary;
  final List<ChangelogEntry> entries;
}

/// Label baris dalam fail log perubahan (BM dan English diterima dalam kedua-dua fail).
const _beforeLabels = ['Sebelum:', 'Before:'];
const _afterLabels = ['Selepas:', 'After:'];
const _tipLabels = ['Cara guna:', 'How to use:'];

/// Menghurai `assets/changelog/changelog.<bahasa>.md`.
///
/// ```text
/// # 1.8.0 | 2026-11-06
/// Ringkasan versi (pilihan, satu perenggan).
///
/// ## Tajuk perubahan
/// Sebelum: apa yang berlaku dahulu.
/// Selepas: apa yang berlaku sekarang.
/// Cara guna: pilihan.
/// ```
///
/// Baris yang menyambung (tanpa label) disambung kepada bahagian sebelumnya, jadi teks panjang boleh
/// dipecah kepada beberapa baris dalam fail. Perubahan tanpa "Sebelum" atau "Selepas" diabaikan.
List<ChangelogRelease> parseChangelog(String source) {
  final releases = <ChangelogRelease>[];
  String? version;
  DateTime? date;
  final summary = StringBuffer();
  var entries = <ChangelogEntry>[];
  String? title;
  final fields = <String, StringBuffer>{};
  String? field;

  void closeEntry() {
    final t = title;
    final before = fields['before']?.toString().trim() ?? '';
    final after = fields['after']?.toString().trim() ?? '';
    final tip = fields['tip']?.toString().trim() ?? '';
    if (t != null && before.isNotEmpty && after.isNotEmpty) {
      entries.add(
        ChangelogEntry(
          title: t,
          before: before,
          after: after,
          tip: tip.isEmpty ? null : tip,
        ),
      );
    }
    title = null;
    fields.clear();
    field = null;
  }

  void closeRelease() {
    closeEntry();
    final v = version;
    if (v != null && entries.isNotEmpty) {
      final s = summary.toString().trim();
      releases.add(
        ChangelogRelease(
          version: v,
          date: date,
          summary: s.isEmpty ? null : s,
          entries: List.unmodifiable(entries),
        ),
      );
    }
    version = null;
    date = null;
    summary.clear();
    entries = <ChangelogEntry>[];
  }

  void append(StringBuffer buffer, String text) {
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(text);
  }

  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('## ')) {
      closeEntry();
      title = line.substring(3).trim();
      continue;
    }
    if (line.startsWith('# ')) {
      closeRelease();
      final parts = line.substring(2).split('|');
      version = parts.first.trim();
      date = parts.length > 1 ? DateTime.tryParse(parts[1].trim()) : null;
      continue;
    }
    if (line.isEmpty) {
      field = null;
      continue;
    }
    String? labelled(List<String> labels) {
      for (final l in labels) {
        if (line.startsWith(l)) return line.substring(l.length).trim();
      }
      return null;
    }

    if (title != null) {
      final before = labelled(_beforeLabels);
      final after = labelled(_afterLabels);
      final tip = labelled(_tipLabels);
      if (before != null) {
        field = 'before';
        append(fields.putIfAbsent('before', StringBuffer.new), before);
      } else if (after != null) {
        field = 'after';
        append(fields.putIfAbsent('after', StringBuffer.new), after);
      } else if (tip != null) {
        field = 'tip';
        append(fields.putIfAbsent('tip', StringBuffer.new), tip);
      } else if (field != null) {
        append(fields[field]!, line);
      }
    } else if (version != null) {
      append(summary, line);
    }
  }
  closeRelease();
  return releases;
}
