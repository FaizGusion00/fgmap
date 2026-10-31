import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/log.dart';
import '../domain/music_repository.dart';
import '../domain/track.dart';

/// Direktori pustaka muzik tempatan (`<dokumen app>/music`); ditimpa dalam `main.dart` dan ujian.
final localLibraryDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('localLibraryDirProvider mesti ditimpa'),
);

/// Pustaka fail yang diimport: fail disalin ke [dir] (storan app, tiada kebenaran media
/// diperlukan) dan diindeks dalam `index.json`. Tajuk = nama fail tanpa sambungan.
class FileLocalLibrary implements LocalLibrary {
  FileLocalLibrary(this.dir, {Future<List<String>> Function()? pickPaths})
    : _pickPaths = pickPaths ?? _pickWithFilePicker;

  final Directory dir;
  final Future<List<String>> Function() _pickPaths;

  File get _index => File(p.join(dir.path, 'index.json'));

  static Future<List<String>> _pickWithFilePicker() async {
    // file_picker 13: pickFiles sentiasa berbilang pilihan dan mengembalikan senarai.
    final files = await FilePicker.pickFiles(type: FileType.audio);
    return [
      for (final f in files)
        if (f.path != null) f.path!,
    ];
  }

  @override
  Future<List<Track>> list() async {
    if (!await _index.exists()) return const [];
    try {
      final json = jsonDecode(await _index.readAsString());
      if (json is! List) return const [];
      final tracks = <Track>[];
      for (final item in json) {
        if (item is! Map<String, Object?>) continue;
        final t = Track.fromJson(item);
        if (t != null && await File(t.streamUri.toFilePath()).exists()) {
          tracks.add(t);
        }
      }
      return tracks;
    } on Object catch (e) {
      logDiag('Indeks muzik tempatan rosak: $e');
      return const [];
    }
  }

  @override
  Future<List<Track>> import() async {
    final paths = await _pickPaths();
    if (paths.isEmpty) return const [];
    await dir.create(recursive: true);
    final existing = await list();
    final added = <Track>[];
    for (final path in paths) {
      try {
        final name = p.basename(path);
        final target = File(p.join(dir.path, name));
        if (!await target.exists()) await File(path).copy(target.path);
        final track = Track(
          id: name,
          source: TrackSource.local,
          title: p.basenameWithoutExtension(name),
          streamUri: Uri.file(target.path),
        );
        if (!existing.contains(track)) added.add(track);
      } on Object catch (e) {
        logDiag('Import muzik gagal: $e');
      }
    }
    await _write([...existing, ...added]);
    return added;
  }

  @override
  Future<void> remove(Track track) async {
    final tracks = await list();
    tracks.remove(track);
    try {
      final f = File(track.streamUri.toFilePath());
      if (await f.exists()) await f.delete();
    } on Object catch (e) {
      logDiag('Padam fail muzik gagal: $e');
    }
    await _write(tracks);
  }

  @override
  Future<void> clear() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _write(List<Track> tracks) async {
    await dir.create(recursive: true);
    await _index.writeAsString(
      jsonEncode([for (final t in tracks) t.toJson()]),
    );
  }
}

final localLibraryProvider = Provider<LocalLibrary>(
  (ref) => FileLocalLibrary(ref.watch(localLibraryDirProvider)),
);
