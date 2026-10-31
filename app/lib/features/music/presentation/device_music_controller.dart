import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_music_channel.dart';
import '../domain/device_music.dart';
import '../domain/music_repository.dart';

final deviceMusicRepositoryProvider = Provider<DeviceMusicRepository>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS)
      ? ChannelDeviceMusicRepository()
      : const UnavailableDeviceMusicRepository(),
);

/// Status kebenaran muzik peranti. Tidak pernah meminta kebenaran sendiri: dialog sistem hanya
/// muncul apabila pengguna mengetik "Benarkan akses muzik" ([connect]).
class DeviceMusicController extends Notifier<DeviceMusicAccess> {
  @override
  DeviceMusicAccess build() {
    final repo = ref.watch(deviceMusicRepositoryProvider);
    if (!repo.supported) return DeviceMusicAccess.unsupported;
    unawaited(_load(repo.access));
    return DeviceMusicAccess.notDetermined;
  }

  Future<void> _load(Future<DeviceMusicAccess> Function() fetch) async {
    final next = await fetch();
    if (ref.mounted) state = next;
  }

  Future<void> refresh() =>
      _load(ref.read(deviceMusicRepositoryProvider).access);

  Future<void> connect() =>
      _load(ref.read(deviceMusicRepositoryProvider).request);
}

final deviceMusicAccessProvider =
    NotifierProvider<DeviceMusicController, DeviceMusicAccess>(
      DeviceMusicController.new,
    );
