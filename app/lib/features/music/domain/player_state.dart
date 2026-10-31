import 'package:flutter/foundation.dart';

import 'track.dart';

enum PlayerStatus { idle, loading, buffering, playing, paused, error }

/// Gambar pemain untuk UI. Kedudukan dikemas kini kerap: widget mesti `select` medan yang perlu.
@immutable
class PlayerState {
  const PlayerState({
    this.status = PlayerStatus.idle,
    this.queue = const [],
    this.index = 0,
    this.position = Duration.zero,
    this.duration,
    this.volume = 1.0,
    this.ducked = false,
    this.error,
    this.nowPlaying,
  });

  final PlayerStatus status;
  final List<Track> queue;
  final int index;
  final Duration position;
  final Duration? duration;
  final double volume;

  /// Diperlahankan/dijeda kerana suara navigasi sedang bercakap.
  final bool ducked;
  final String? error;

  /// Lagu yang sedang bersiaran di stesen radio (tajuk ICY yang sudah dibersihkan); null jika
  /// stesen tidak menghantarnya atau bukan siaran langsung.
  final String? nowPlaying;

  Track? get current =>
      queue.isEmpty || index < 0 || index >= queue.length ? null : queue[index];
  bool get isPlaying => status == PlayerStatus.playing;
  bool get hasNext => index + 1 < queue.length;
  bool get hasPrevious => index > 0;
  bool get isActive => status != PlayerStatus.idle && current != null;

  PlayerState copyWith({
    PlayerStatus? status,
    List<Track>? queue,
    int? index,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    double? volume,
    bool? ducked,
    String? error,
    bool clearError = false,
    String? nowPlaying,
    bool clearNowPlaying = false,
  }) => PlayerState(
    status: status ?? this.status,
    queue: queue ?? this.queue,
    index: index ?? this.index,
    position: position ?? this.position,
    duration: clearDuration ? null : (duration ?? this.duration),
    volume: volume ?? this.volume,
    ducked: ducked ?? this.ducked,
    error: clearError ? null : (error ?? this.error),
    nowPlaying: clearNowPlaying ? null : (nowPlaying ?? this.nowPlaying),
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      other.status == status &&
      listEquals(other.queue, queue) &&
      other.index == index &&
      other.position == position &&
      other.duration == duration &&
      other.volume == volume &&
      other.ducked == ducked &&
      other.error == error &&
      other.nowPlaying == nowPlaying;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(queue),
    index,
    position,
    duration,
    volume,
    ducked,
    error,
    nowPlaying,
  );
}

/// Gambar daripada enjin audio (just_audio) kepada pengawal; bebas plugin supaya boleh dipalsukan.
@immutable
class EngineSnapshot {
  const EngineSnapshot({
    required this.status,
    this.index,
    this.position = Duration.zero,
    this.duration,
    this.error,
    this.nowPlaying,
  });

  final PlayerStatus status;
  final int? index;
  final Duration position;
  final Duration? duration;
  final String? error;

  /// Tajuk ICY mentah daripada strim langsung (belum dibersihkan); null jika tiada.
  final String? nowPlaying;
}
