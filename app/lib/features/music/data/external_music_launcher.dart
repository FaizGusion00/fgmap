import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/log.dart';

typedef ExternalLauncher = Future<bool> Function(Uri uri);

/// Membuka [uri] dalam app luar (Spotify, YouTube Music) atau pelayar; ditimpa dengan palsu dalam
/// ujian. Mengembalikan false jika tiada app/pelayar yang boleh membukanya; tidak melontar.
final externalMusicLauncherProvider = Provider<ExternalLauncher>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      logDiag('Buka pautan muzik gagal: $e');
      return false;
    }
  },
);
