import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Perkongsian teks melalui lembaran kongsi sistem. Antara muka supaya ujian tidak membuka UI sistem.
abstract interface class ShareService {
  /// Berjaya jika lembaran kongsi dipaparkan (bukan jika penerima menerimanya: app tidak mengetahuinya).
  Future<void> shareText(String text, {String? subject, Rect? origin});
}

class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
  }
}

/// Membuka papan nombor telefon dengan nombor yang diisi. Tidak membuat panggilan sendiri: pengguna
/// menekan butang panggil pada papan nombor.
abstract interface class PhoneDialer {
  Future<bool> dial(String number);
}

class SystemPhoneDialer implements PhoneDialer {
  const SystemPhoneDialer();

  @override
  Future<bool> dial(String number) {
    // Hanya digit (dan +): nombor tidak pernah datang daripada input luar, tetapi tapis juga.
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return Future.value(false);
    return launchUrl(Uri(scheme: 'tel', path: clean));
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => const SystemShareService(),
);

final phoneDialerProvider = Provider<PhoneDialer>(
  (ref) => const SystemPhoneDialer(),
);
