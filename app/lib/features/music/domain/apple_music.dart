import 'package:flutter/foundation.dart';

import 'track.dart';

/// Kebenaran MusicKit pada peranti; `unsupported` di Android dan apabila ciri ditutup.
enum AppleMusicAccess {
  unsupported,
  notDetermined,
  denied,
  restricted,
  authorized;

  static AppleMusicAccess fromName(Object? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return AppleMusicAccess.notDetermined;
  }
}

@immutable
class AppleMusicStatus {
  const AppleMusicStatus({
    this.access = AppleMusicAccess.notDetermined,
    this.canPlay = false,
    this.canBecomeSubscriber = false,
  });

  static const unsupported = AppleMusicStatus(
    access: AppleMusicAccess.unsupported,
  );

  final AppleMusicAccess access;

  /// Pengguna mempunyai langganan Apple Music yang boleh memainkan katalog.
  final bool canPlay;
  final bool canBecomeSubscriber;

  bool get supported => access != AppleMusicAccess.unsupported;

  /// Boleh cari dan main lagu penuh sekarang.
  bool get ready => access == AppleMusicAccess.authorized && canPlay;

  @override
  bool operator ==(Object other) =>
      other is AppleMusicStatus &&
      other.access == access &&
      other.canPlay == canPlay &&
      other.canBecomeSubscriber == canBecomeSubscriber;

  @override
  int get hashCode => Object.hash(access, canPlay, canBecomeSubscriber);
}

/// Katalog Apple Music melalui MusicKit (iOS). Lagu penuh hanya untuk pelanggan; app tidak
/// menerima akaun, token atau sejarah pengguna.
abstract interface class AppleMusicRepository {
  /// Platform ini ada jambatan MusicKit dan ciri dihidupkan.
  bool get supported;

  Future<AppleMusicStatus> status();

  /// Minta kebenaran (dialog sistem) dan pulangkan status terkini.
  Future<AppleMusicStatus> authorize();

  Future<List<Track>> search(String query);
}
