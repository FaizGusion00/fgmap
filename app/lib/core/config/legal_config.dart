/// Butiran undang-undang yang dipaparkan dalam Dasar Privasi dan Terma (assets/legal/*.md).
///
/// Nilai `[DIISI]` ialah pemegang tempat: pemilik MESTI mengisinya sebelum app diterbitkan (boleh
/// melalui `--dart-define=LEGAL_EMAIL=...` dan seterusnya, atau terus di sini). `make check-legal` dan
/// `make appbundle` gagal selagi masih ada pemegang tempat atau dokumen belum disemak peguam.
abstract final class LegalConfig {
  static const placeholder = '[DIISI]';

  static const entityName = String.fromEnvironment(
    'LEGAL_ENTITY',
    defaultValue: 'FG Universal Empire Company',
  );
  static const developerName = String.fromEnvironment(
    'LEGAL_DEVELOPER',
    defaultValue: 'Faiz Nasir',
  );
  static const registrationNo = String.fromEnvironment(
    'LEGAL_REG_NO',
    defaultValue: placeholder,
  );
  static const address = String.fromEnvironment(
    'LEGAL_ADDRESS',
    defaultValue: placeholder,
  );
  static const email = String.fromEnvironment(
    'LEGAL_EMAIL',
    defaultValue: placeholder,
  );

  /// Tarikh berkuat kuasa dan versi dokumen. Naikkan kedua-duanya apabila teks berubah.
  static const effectiveDate = '2026-10-26';
  static const version = '1.0';

  /// Benar HANYA selepas peguam menyemak dokumen. Selagi false, halaman memaparkan notis draf.
  static const reviewedByLawyer = bool.fromEnvironment('LEGAL_REVIEWED');

  /// Nilai pengganti untuk `{{nama}}` dalam dokumen.
  static Map<String, String> get values => const {
    'entity': entityName,
    'developer': developerName,
    'regNo': registrationNo,
    'address': address,
    'email': email,
    'effective': effectiveDate,
    'version': version,
  };

  /// Medan yang masih pemegang tempat.
  static List<String> missingFields() => [
    for (final e in {
      'LEGAL_REG_NO': registrationNo,
      'LEGAL_ADDRESS': address,
      'LEGAL_EMAIL': email,
    }.entries)
      if (e.value == placeholder || e.value.trim().isEmpty) e.key,
  ];

  /// Siap diterbitkan: semua medan diisi dan peguam telah menyemak.
  static bool get releaseReady => missingFields().isEmpty && reviewedByLawyer;
}

/// Mengganti `{{nama}}` dalam [template] dengan [values]. Nama yang tidak dikenali dibiarkan supaya
/// ralat penulisan mudah dilihat (dan diuji).
String fillLegalTemplate(String template, Map<String, String> values) {
  return template.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
    return values[m.group(1)] ?? m.group(0)!;
  });
}
