/// Waktu solat yang dipaparkan. Syuruk ditunjuk (penting untuk mengetahui tamat Subuh) tetapi tidak
/// pernah diberi notifikasi azan.
enum Prayer {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha;

  /// Boleh diberi notifikasi/azan (semua kecuali syuruk).
  bool get notifiable => this != Prayer.sunrise;

  static Prayer? fromName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// Lima waktu fardu, dalam susunan hari.
  static const fardu = [fajr, dhuhr, asr, maghrib, isha];
}

/// Kaedah pengiraan. `jakim` ialah lalai Malaysia: sudut Subuh 20° dan Isyak 18°, sama dengan
/// kaedah MUIS Singapura yang digunakan JAKIM (e-Solat). Jadual rasmi e-Solat mengikut zon dan
/// mungkin berbeza 1-2 minit; UI menyatakan "anggaran".
enum AzanMethod {
  jakim,
  mwl,
  egyptian,
  karachi,
  ummAlQura;

  static AzanMethod fromName(String? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return AzanMethod.jakim;
  }
}

/// Mazhab untuk waktu Asar: Syafie (bayang = 1x) lalai di Malaysia; Hanafi (2x).
enum AzanMadhab {
  shafi,
  hanafi;

  static AzanMadhab fromName(String? name) =>
      name == AzanMadhab.hanafi.name ? AzanMadhab.hanafi : AzanMadhab.shafi;
}

/// Bunyi notifikasi azan. Lalai: azan penuh.
enum AzanSound {
  full,
  short,
  silent;

  static AzanSound fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return AzanSound.full;
  }
}
