import 'dart:io';

import 'package:fgmap/core/config/legal_config.dart';
import 'package:fgmap/features/legal/presentation/legal_page.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Membaca dokumen undang-undang terus daripada fail (segerak) supaya `pumpAndSettle` tidak
/// menunggu I/O aset sebenar yang tidak bergerak bersama masa palsu ujian.
Override legalTextOverride() => legalTextProvider.overrideWith((ref, key) {
  final (doc, lang) = key;
  final name =
      '${doc == LegalDoc.privacy ? 'privacy' : 'terms'}.${lang == 'ms' ? 'ms' : 'en'}';
  return fillLegalTemplate(
    File('assets/legal/$name.md').readAsStringSync(),
    LegalConfig.values,
  );
});
