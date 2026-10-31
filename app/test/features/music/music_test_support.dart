import 'dart:async';

import 'package:fgmap/features/music/domain/music_repository.dart';
import 'package:fgmap/features/music/domain/player_state.dart';
import 'package:fgmap/features/music/domain/track.dart';

Track track(String id, {TrackSource source = TrackSource.audius, String? title}) =>
    Track(
      id: id,
      source: source,
      title: title ?? 'Lagu $id',
      artist: 'Artis',
      streamUri: Uri.parse('https://example.test/$id.mp3'),
      duration: source == TrackSource.radio ? null : const Duration(minutes: 3),
      radioUuid: source == TrackSource.radio ? 'uuid-$id' : null,
    );

/// Enjin palsu: merekod panggilan dan membenarkan ujian menolak gambar keadaan.
class FakeMusicEngine implements MusicEngine {
  final calls = <String>[];
  final _snapshots = StreamController<EngineSnapshot>.broadcast();
  List<Track> queue = const [];
  int index = 0;
  double volume = 1;
  bool? eqEnabled;
  List<double>? eqGains;
  bool supportsEq = true;
  Object? failOnSetQueue;

  @override
  Stream<EngineSnapshot> get snapshots => _snapshots.stream;

  void emit(PlayerStatus status, {int? index, Duration? position, Duration? duration, String? error}) =>
      _snapshots.add(
        EngineSnapshot(
          status: status,
          index: index ?? this.index,
          position: position ?? Duration.zero,
          duration: duration,
          error: error,
        ),
      );

  @override
  Future<void> setQueue(List<Track> tracks, int startIndex) async {
    calls.add('setQueue:${tracks.length}:$startIndex');
    if (failOnSetQueue != null) throw failOnSetQueue!;
    queue = tracks;
    index = startIndex;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async => calls.add('seek:${position.inSeconds}');

  @override
  Future<void> seekToIndex(int i) async {
    index = i;
    calls.add('index:$i');
  }

  @override
  Future<void> setVolume(double v) async {
    volume = v;
    calls.add('volume:${v.toStringAsFixed(2)}');
  }

  @override
  Future<void> setEqualizer({required bool enabled, required List<double> gainsDb}) async {
    eqEnabled = enabled;
    eqGains = gainsDb;
  }

  @override
  bool get equalizerSupported => supportsEq;

  @override
  Future<void> dispose() async => _snapshots.close();
}

class FakeAudiusRepository implements AudiusRepository {
  FakeAudiusRepository({this.results = const [], this.trendingResults = const [], this.error});
  List<Track> results;
  List<Track> trendingResults;
  Object? error;
  final queries = <String>[];

  @override
  Future<List<Track>> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return results;
  }

  @override
  Future<List<Track>> trending() async {
    if (error != null) throw error!;
    return trendingResults;
  }
}

class FakeRadioRepository implements RadioRepository {
  FakeRadioRepository({this.results = const [], this.error});
  List<Track> results;
  Object? error;
  final clicks = <String>[];

  @override
  Future<List<Track>> stations({String query = ''}) async {
    if (error != null) throw error!;
    final q = query.toLowerCase();
    return [for (final t in results) if (t.title.toLowerCase().contains(q)) t];
  }

  @override
  Future<void> countClick(String stationUuid) async => clicks.add(stationUuid);
}

class FakeLocalLibrary implements LocalLibrary {
  FakeLocalLibrary({List<Track>? tracks, this.toImport = const []})
    : tracks = [...?tracks];
  final List<Track> tracks;
  List<Track> toImport;

  @override
  Future<List<Track>> list() async => List.of(tracks);

  @override
  Future<List<Track>> import() async {
    tracks.addAll(toImport);
    return toImport;
  }

  @override
  Future<void> remove(Track track) async => tracks.remove(track);

  @override
  Future<void> clear() async => tracks.clear();
}
