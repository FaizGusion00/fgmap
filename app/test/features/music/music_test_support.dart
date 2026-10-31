import 'dart:async';

import 'package:fgmap/features/music/data/apple_music_channel.dart';
import 'package:fgmap/features/music/domain/apple_music.dart';
import 'package:fgmap/features/music/domain/device_music.dart';
import 'package:fgmap/features/music/domain/music_repository.dart';
import 'package:fgmap/features/music/domain/player_state.dart';
import 'package:fgmap/features/music/domain/track.dart';

Track track(
  String id, {
  TrackSource source = TrackSource.audius,
  String? title,
}) => Track(
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

  void emit(
    PlayerStatus status, {
    int? index,
    Duration? position,
    Duration? duration,
    String? error,
    String? nowPlaying,
  }) => _snapshots.add(
    EngineSnapshot(
      status: status,
      index: index ?? this.index,
      position: position ?? Duration.zero,
      duration: duration,
      error: error,
      nowPlaying: nowPlaying,
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
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inSeconds}');

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
  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gainsDb,
  }) async {
    eqEnabled = enabled;
    eqGains = gainsDb;
  }

  @override
  bool get equalizerSupported => supportsEq;

  @override
  Future<void> dispose() async => _snapshots.close();
}

class FakeAudiusRepository implements AudiusRepository {
  FakeAudiusRepository({
    this.results = const [],
    this.trendingResults = const [],
    this.error,
  });
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
  final regions = <RadioRegion>[];

  @override
  Future<List<Track>> stations({
    String query = '',
    RadioRegion region = RadioRegion.malaysia,
  }) async {
    regions.add(region);
    if (error != null) throw error!;
    final q = query.toLowerCase();
    return [
      for (final t in results)
        if (t.title.toLowerCase().contains(q)) t,
    ];
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

Track appleTrack(String id, {String? title}) => Track(
  id: id,
  source: TrackSource.appleMusic,
  title: title ?? 'Apple $id',
  artist: 'Siti Nurhaliza',
  streamUri: appleMusicMarker(id),
  duration: const Duration(minutes: 4),
);

class FakeAppleMusicRepository implements AppleMusicRepository {
  FakeAppleMusicRepository({
    this.current = const AppleMusicStatus(),
    this.afterAuthorize = const AppleMusicStatus(
      access: AppleMusicAccess.authorized,
      canPlay: true,
    ),
    this.results = const [],
    this.error,
    this.isSupported = true,
  });
  AppleMusicStatus current;
  AppleMusicStatus afterAuthorize;
  List<Track> results;
  Object? error;
  bool isSupported;
  final queries = <String>[];
  int authorizeCalls = 0;

  @override
  bool get supported => isSupported;

  @override
  Future<AppleMusicStatus> status() async => current;

  @override
  Future<AppleMusicStatus> authorize() async {
    authorizeCalls++;
    return current = afterAuthorize;
  }

  @override
  Future<List<Track>> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return results;
  }
}

Track deviceTrack(String id, {String? title}) => Track(
  id: id,
  source: TrackSource.device,
  title: title ?? 'Telefon $id',
  artist: 'Penyanyi',
  streamUri: Uri.parse('content://media/external/audio/media/$id'),
  duration: const Duration(minutes: 3),
);

class FakeDeviceMusicRepository implements DeviceMusicRepository {
  FakeDeviceMusicRepository({
    this.current = DeviceMusicAccess.notDetermined,
    this.afterRequest = DeviceMusicAccess.authorized,
    this.tracks = const [],
    this.error,
    this.isSupported = true,
  });
  DeviceMusicAccess current;
  DeviceMusicAccess afterRequest;
  List<Track> tracks;
  Object? error;
  bool isSupported;
  int requestCalls = 0;
  final refreshFlags = <bool>[];

  @override
  bool get supported => isSupported;

  @override
  Future<DeviceMusicAccess> access() async => current;

  @override
  Future<DeviceMusicAccess> request() async {
    requestCalls++;
    return current = afterRequest;
  }

  @override
  Future<List<Track>> songs({bool refresh = false}) async {
    refreshFlags.add(refresh);
    if (error != null) throw error!;
    return tracks;
  }
}
