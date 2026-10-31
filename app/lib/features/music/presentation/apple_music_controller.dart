import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/apple_music_channel.dart';
import '../domain/apple_music.dart';

/// MusicKit hanya wujud di iOS dan hanya apabila ciri dihidupkan ([AppConfig.appleMusicEnabled]).
bool get appleMusicPlatformSupported =>
    AppConfig.appleMusicEnabled && !kIsWeb && Platform.isIOS;

final appleMusicRepositoryProvider = Provider<AppleMusicRepository>(
  (ref) => appleMusicPlatformSupported
      ? ChannelAppleMusicRepository()
      : const UnavailableAppleMusicRepository(),
);

/// Status sambungan Apple Music. Tidak pernah meminta kebenaran sendiri: dialog sistem hanya muncul
/// apabila pengguna mengetik "Sambung Apple Music" ([connect]).
class AppleMusicController extends Notifier<AppleMusicStatus> {
  @override
  AppleMusicStatus build() {
    final repo = ref.watch(appleMusicRepositoryProvider);
    if (!repo.supported) return AppleMusicStatus.unsupported;
    unawaited(_load(repo.status));
    return const AppleMusicStatus();
  }

  Future<void> _load(Future<AppleMusicStatus> Function() fetch) async {
    final next = await fetch();
    if (ref.mounted) state = next;
  }

  Future<void> refresh() =>
      _load(ref.read(appleMusicRepositoryProvider).status);

  Future<void> connect() =>
      _load(ref.read(appleMusicRepositoryProvider).authorize);
}

final appleMusicStatusProvider =
    NotifierProvider<AppleMusicController, AppleMusicStatus>(
      AppleMusicController.new,
    );
