import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mendaftarkan lesen aset yang dibundel supaya muncul dalam halaman lesen (LicensePage).
/// Pakej Dart/Flutter mendaftarkan lesen mereka sendiri; fon bukan pakej, jadi didaftar di sini.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/fonts/OFL-PlusJakartaSans.txt',
    );
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], text);
  });
  // Rakaman azan (CC BY-SA 4.0): atribusi wajib; lihat assets/audio/LICENSE-azan.txt.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/audio/LICENSE-azan.txt');
    yield LicenseEntryWithLineBreaks(['Azan (rakaman)'], text);
  });
}
