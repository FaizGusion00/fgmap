import 'package:flutter/foundation.dart';

/// Dari mana lagu datang. Menentukan atribusi, sama ada boleh dicari (seek) dan ikon sumber.
enum TrackSource {
  /// Audius: katalog awam yang dimuat naik pengguna; strim melalui API tanpa kunci.
  audius,

  /// Radio Browser: siaran langsung (tiada seek, tiada tempoh).
  radio,

  /// Fail yang diimport pengguna ke storan app.
  local,

  /// Apple Music (iOS, MusicKit): lagu penuh untuk pelanggan. Tiada URL strim yang boleh dimain
  /// oleh app; MusicKit memainkannya sendiri (DRM), jadi [Track.streamUri] hanya penanda.
  appleMusic;

  static TrackSource? fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Satu item boleh main: lagu Audius, stesen radio atau fail tempatan.
@immutable
class Track {
  const Track({
    required this.id,
    required this.source,
    required this.title,
    required this.streamUri,
    this.artist,
    this.artworkUri,
    this.duration,
    this.permalink,
    this.radioUuid,
  });

  /// Unik dalam [source] (ID Audius, stationuuid, atau nama fail).
  final String id;
  final TrackSource source;
  final String title;
  final String? artist;
  final Uri streamUri;
  final Uri? artworkUri;

  /// Null untuk siaran langsung.
  final Duration? duration;

  /// Halaman sumber (atribusi: "via Audius" / laman stesen).
  final Uri? permalink;

  /// Radio Browser: untuk kiraan klik (`/json/url/{uuid}`).
  final String? radioUuid;

  bool get isLive => source == TrackSource.radio;

  /// Kunci global untuk baris gilir.
  String get key => '${source.name}:$id';

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.name,
    'title': title,
    'artist': artist,
    'streamUri': streamUri.toString(),
    'artworkUri': artworkUri?.toString(),
    'durationMs': duration?.inMilliseconds,
    'permalink': permalink?.toString(),
    'radioUuid': radioUuid,
  };

  static Track? fromJson(Map<String, Object?> json) {
    final source = TrackSource.fromName(json['source'] as String?);
    final id = json['id'] as String?;
    final title = json['title'] as String?;
    final stream = Uri.tryParse(json['streamUri'] as String? ?? '');
    if (source == null || id == null || title == null || stream == null) {
      return null;
    }
    final art = json['artworkUri'] as String?;
    final link = json['permalink'] as String?;
    final ms = json['durationMs'] as int?;
    return Track(
      id: id,
      source: source,
      title: title,
      streamUri: stream,
      artist: json['artist'] as String?,
      artworkUri: art == null ? null : Uri.tryParse(art),
      duration: ms == null ? null : Duration(milliseconds: ms),
      permalink: link == null ? null : Uri.tryParse(link),
      radioUuid: json['radioUuid'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Track && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);

  @override
  String toString() => 'Track($key "$title")';
}
